/*
 * Node.js MQTT Bridge Server
 * Nhiệm vụ: Bridge giữa ESP8266 (MQTT) và Flutter App (WebSocket)
 * 
 * Luồng dữ liệu:
 * ESP8266 → MQTT → Server → WebSocket → Flutter
 * Flutter → WebSocket → Server → MQTT → ESP8266
 */

const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
const WebSocket = require('ws');
const mqtt = require('mqtt');
const config = require('./config');

const app = express();
const PORT = config.PORT;
const WS_PORT = config.WS_PORT;

// ===== MIDDLEWARE =====
app.use(cors());
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

// ===== DỮ LIỆU HỆ THỐNG =====
let systemData = {
  pir: false,
  led1: false,
  led2: false,
  temperature: 0,
  humidity: 0,
  fan: false,
  fanAuto: true,
  door: false,
  autoOpen: false,
  rfid: false,
  distance: 0,
  securityMode: false,
  intruder: false,
  timestamp: Date.now(),
  online: false
};

// ===== MQTT CLIENT =====
const mqttBroker = config.getMqttUrl();
const mqttClient = mqtt.connect(mqttBroker, {
  clientId: 'NodeJS_Server_' + Math.random().toString(16).substring(2, 8),
  clean: true,
  reconnectPeriod: 1000,
  username: config.MQTT_USERNAME,
  password: config.MQTT_PASSWORD
});

// MQTT Topics
const TOPIC_DATA = 'iot/sensors/data';
const TOPIC_CONTROL_LED2 = 'iot/control/led2';
const TOPIC_CONTROL_FAN = 'iot/control/fan';
const TOPIC_CONTROL_DOOR = 'iot/control/door';
const TOPIC_CONTROL_SECURITY = 'iot/control/security';

mqttClient.on('connect', () => {
  console.log('✓ Connected to MQTT Broker');
  
  // Subscribe to sensor data
  mqttClient.subscribe(TOPIC_DATA, (err) => {
    if (!err) {
      console.log(`✓ Subscribed to ${TOPIC_DATA}`);
    } else {
      console.error('✗ MQTT subscribe error:', err);
    }
  });
});

mqttClient.on('message', (topic, message) => {
  console.log(`📥 MQTT Message received: topic=${topic}, length=${message.length}`);
  
  if (topic === TOPIC_DATA) {
    try {
      const data = JSON.parse(message.toString());
      console.log('✓ Parsed data:', data);
      systemData = {
        ...data,
        timestamp: Date.now(),
        online: true
      };
      
      console.log('📥 Data from ESP8266:', systemData);
      
      // Broadcast to all WebSocket clients
      broadcastToClients({
        type: 'update',
        data: systemData
      });
    } catch (error) {
      console.error('Error parsing MQTT message:', error);
    }
  }
});

mqttClient.on('error', (error) => {
  console.error('MQTT Error:', error);
  systemData.online = false;
});

mqttClient.on('close', () => {
  console.log('✗ MQTT connection closed');
  systemData.online = false;
});

// ===== WEBSOCKET SERVER =====
const wss = new WebSocket.Server({ port: WS_PORT });

wss.on('connection', (ws) => {
  console.log('✓ WebSocket client connected');
  
  // Send current data
  ws.send(JSON.stringify({
    type: 'init',
    data: systemData
  }));
  
  ws.on('close', () => {
    console.log('✗ WebSocket client disconnected');
  });
  
  ws.on('error', (error) => {
    console.error('WebSocket error:', error);
  });
});

function broadcastToClients(message) {
  wss.clients.forEach((client) => {
    if (client.readyState === WebSocket.OPEN) {
      client.send(JSON.stringify(message));
    }
  });
}

// ===== HTTP API ENDPOINTS =====

// Health check
app.get('/', (req, res) => {
  res.json({
    status: 'running',
    service: 'IoT MQTT Bridge Server',
    mqtt: mqttClient.connected ? 'connected' : 'disconnected',
    uptime: process.uptime()
  });
});

// Get current data
app.get('/api/data', (req, res) => {
  res.json(systemData);
});

// Control devices (từ Flutter)
app.post('/api/control', (req, res) => {
  const { device, action } = req.body;
  
  console.log(`📤 Control: ${device} = ${action}`);
  
  let topic = '';
  let payload = action;
  
  switch(device) {
    case 'led2':
      topic = TOPIC_CONTROL_LED2;
      break;
    case 'fan':
      topic = TOPIC_CONTROL_FAN;
      break;
    case 'door':
      topic = TOPIC_CONTROL_DOOR;
      break;
    case 'security':
      topic = TOPIC_CONTROL_SECURITY;
      break;
    default:
      return res.status(400).json({ 
        status: 'error', 
        message: 'Invalid device' 
      });
  }
  
  mqttClient.publish(topic, payload, (err) => {
    if (err) {
      console.error('MQTT publish error:', err);
      return res.status(500).json({ 
        status: 'error', 
        message: 'Failed to send command' 
      });
    }
    
    res.json({ 
      status: 'success', 
      message: `Command sent: ${device} ${action}` 
    });
  });
});

// Legacy endpoint (backward compatibility)
app.post('/api/data', (req, res) => {
  res.json({ 
    status: 'success', 
    message: 'Data received (legacy endpoint)' 
  });
});

app.get('/api/commands', (req, res) => {
  res.json({});
});

// ===== START SERVER =====
app.listen(PORT, () => {
  console.log(`\n=== IoT MQTT Bridge Server ===`);
  console.log(`HTTP Server: http://localhost:${PORT}`);
  console.log(`WebSocket Server: ws://localhost:${WS_PORT}`);
  console.log(`MQTT Broker: ${mqttBroker}`);
  console.log(`==============================\n`);
});

// Graceful shutdown
process.on('SIGINT', () => {
  console.log('\nShutting down...');
  mqttClient.end();
  wss.close();
  process.exit();
});
