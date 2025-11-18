const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
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

// ===== MQTT PUBLISH FOR CLIENT UPDATES =====
function publishSystemUpdate() {
  if (mqttClient && mqttClient.connected) {
    const topic = '/iot/smarthome/updates';
    const payload = JSON.stringify({
      type: 'update',
      data: systemData
    });

    mqttClient.publish(topic, payload, { qos: 1, retain: true }, (err) => {
      if (!err) {
        console.log('Published system update to MQTT');
      }
    });
  }
}

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

        // Publish update to MQTT for clients to subscribe
        publishSystemUpdate();

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

// ===== MINIMAL HTTP ENDPOINTS =====
// Only keep essential endpoints for pure MQTT operation

// Trang chủ (serve static files)
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    mqtt: mqttClient && mqttClient.connected ? 'connected' : 'disconnected',
    timestamp: new Date().toISOString()
  });
});

// ===== KHỞI ĐỘNG SERVER =====
app.listen(PORT, '0.0.0.0', () => {
  console.log('==============================================');
  console.log('IoT Smart Home Server Started (PURE MQTT)');
  console.log('==============================================');
  console.log(`HTTP Server: http://localhost:${PORT} (legacy)`);
  console.log(`MQTT Broker: ${MQTT_BROKER_URL}`);
  console.log('==============================================');
  console.log('Waiting for MQTT connections...');

  // Initialize MQTT client after server starts
  setTimeout(() => {
    setupMQTTClient();
  }, 1000);

  console.log('');
});

// Xử lý tắt server
process.on('SIGINT', () => {
  console.log('\nShutting down server...');
  if (mqttClient) {
    mqttClient.end();
  }
  process.exit(0);
});
