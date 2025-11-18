const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const WebSocket = require('ws');
const path = require('path');
const aedes = require('aedes')();
const mqtt = require('mqtt');
const net = require('net');

const app = express();
const PORT = 3000;

// Middleware
app.use(cors());
app.use(bodyParser.json());
app.use(express.static(path.join(__dirname, 'public')));

// ===== DỮ LIỆU HỆ THỐNG =====
let systemData = {
  pir: false,
  led1: false,
  led2: false,
  temperature: 0,
  humidity: 0,
  door: false,
  autoOpen: false,
  rfid: false,
  distance: 0,
  lastUpdate: new Date().toISOString()
};

// ===== LỆNH ĐIỀU KHIỂN =====
let pendingCommands = {};

// ===== MQTT BROKER SETUP =====
const MQTT_PORT = 1883;
const MQTT_BROKER_URL = `mqtt://localhost:${MQTT_PORT}`;

// Create MQTT broker server
const mqttServer = net.createServer(aedes.handle);
mqttServer.listen(MQTT_PORT, () => {
  console.log(`MQTT Broker listening on port ${MQTT_PORT}`);
});

// MQTT Client for server operations
let mqttClient;

// ===== WEBSOCKET SERVER =====
const wss = new WebSocket.Server({ port: 3001 });

// Broadcast to all connected WebSocket clients
function broadcast(data) {
  wss.clients.forEach(client => {
    if (client.readyState === WebSocket.OPEN) {
      client.send(JSON.stringify(data));
    }
  });
}

wss.on('connection', (ws) => {
  console.log('WebSocket client connected');

  // Gửi dữ liệu hiện tại cho client mới
  ws.send(JSON.stringify({
    type: 'init',
    data: systemData
  }));

  ws.on('close', () => {
    console.log('WebSocket client disconnected');
  });
});

// ===== MQTT CLIENT SETUP =====
function setupMQTTClient() {
  mqttClient = mqtt.connect(MQTT_BROKER_URL, {
    clientId: 'iot-server-' + Math.random().toString(16).substr(2, 8),
    clean: false,
    reconnectPeriod: 1000,
  });

  mqttClient.on('connect', () => {
    console.log('Connected to MQTT broker');

    // Subscribe to sensor topics
    mqttClient.subscribe('/iot/smarthome/sensors/#', { qos: 1 }, (err) => {
      if (!err) {
        console.log('Subscribed to sensor topics');
      }
    });

    // Subscribe to status topics
    mqttClient.subscribe('/iot/smarthome/status/#', { qos: 1 }, (err) => {
      if (!err) {
        console.log('Subscribed to status topics');
      }
    });
  });

  mqttClient.on('message', (topic, message) => {
    try {
      const payload = JSON.parse(message.toString());
      console.log(`MQTT received [${topic}]:`, payload);

      if (topic.startsWith('/iot/smarthome/sensors/')) {
        // Update system data from sensors
        const sensorType = topic.split('/').pop();

        switch (sensorType) {
          case 'temperature':
            systemData.temperature = payload.temperature || 0;
            systemData.humidity = payload.humidity || 0;
            break;
          case 'motion':
            systemData.pir = payload.motion || false;
            break;
          case 'door':
            systemData.door = payload.door || false;
            systemData.autoOpen = payload.autoOpen || false;
            systemData.rfid = payload.rfid || false;
            break;
          case 'distance':
            systemData.distance = payload.distance || 0;
            break;
        }

        systemData.lastUpdate = new Date().toISOString();

        // Broadcast to WebSocket clients
        broadcast({
          type: 'update',
          data: systemData
        });

      } else if (topic.startsWith('/iot/smarthome/status/')) {
        const device = topic.split('/').pop();
        console.log(`Device ${device} status:`, payload);
      }

    } catch (error) {
      console.error('Error parsing MQTT message:', error);
    }
  });

  mqttClient.on('error', (error) => {
    console.error('MQTT client error:', error);
  });

  mqttClient.on('offline', () => {
    console.log('MQTT client offline');
  });

  mqttClient.on('reconnect', () => {
    console.log('MQTT client reconnecting...');
  });
}

// ===== API ENDPOINTS =====

// Trang chủ
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// Legacy HTTP endpoints for ESP8266 (deprecated - using MQTT now)
// These can be removed once ESP8266 is updated to MQTT
app.post('/api/data', (req, res) => {
  console.log('WARNING: ESP8266 still using HTTP POST - should migrate to MQTT');
  console.log('Received data from ESP8266:', req.body);

  // Cập nhật dữ liệu hệ thống
  systemData = {
    ...req.body,
    lastUpdate: new Date().toISOString()
  };

  // Broadcast qua WebSocket
  broadcast({
    type: 'update',
    data: systemData
  });

  res.json({
    status: 'success',
    message: 'Data received (HTTP - migrate to MQTT)'
  });
});

app.get('/api/commands', (req, res) => {
  console.log('WARNING: ESP8266 still polling for commands - should use MQTT subscription');
  res.json({});
});

// Web client gửi lệnh điều khiển
app.post('/api/control', (req, res) => {
  const { device, action } = req.body;
  console.log(`Control command: ${device} -> ${action}`);

  // Publish command via MQTT
  if (mqttClient && mqttClient.connected) {
    const topic = `/iot/smarthome/commands/${device}`;
    const payload = JSON.stringify({ action, timestamp: Date.now() });

    mqttClient.publish(topic, payload, { qos: 1, retain: false }, (err) => {
      if (err) {
        console.error('Error publishing MQTT command:', err);
        res.status(500).json({
          status: 'error',
          message: 'Failed to send command'
        });
      } else {
        console.log(`Published command to ${topic}: ${payload}`);
        res.json({
          status: 'success',
          message: `Command ${action} for ${device} sent via MQTT`
        });
      }
    });
  } else {
    res.status(503).json({
      status: 'error',
      message: 'MQTT broker not connected'
    });
  }
});

// Lấy dữ liệu hiện tại (cho web)
app.get('/api/status', (req, res) => {
  res.json(systemData);
});

// ===== KHỞI ĐỘNG SERVER =====
app.listen(PORT, '0.0.0.0', () => {
  console.log('==============================================');
  console.log('IoT Smart Home Server Started (MQTT + HTTP)');
  console.log('==============================================');
  console.log(`HTTP Server: http://localhost:${PORT}`);
  console.log(`WebSocket Server: ws://localhost:3001`);
  console.log(`MQTT Broker: ${MQTT_BROKER_URL}`);
  console.log('==============================================');
  console.log('Waiting for connections...');

  // Initialize MQTT client after server starts
  setTimeout(() => {
    setupMQTTClient();
  }, 1000);

  console.log('');
});

// Xử lý tắt server
process.on('SIGINT', () => {
  console.log('\nShutting down server...');
  wss.close();
  process.exit(0);
});
