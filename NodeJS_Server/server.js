const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const WebSocket = require('ws');
const path = require('path');

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
  intruder: false,
  rfid: false,
  distance: 0,
  lastUpdate: new Date().toISOString()
};

// ===== LỆNH ĐIỀU KHIỂN =====
let pendingCommands = {};

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

// ===== API ENDPOINTS =====

// Trang chủ
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// Nhận dữ liệu từ ESP8266
app.post('/api/data', (req, res) => {
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
    message: 'Data received'
  });
});

// ESP8266 lấy lệnh điều khiển
app.get('/api/commands', (req, res) => {
  if (Object.keys(pendingCommands).length > 0) {
    console.log('Sending commands to ESP8266:', pendingCommands);
    const commands = { ...pendingCommands };
    pendingCommands = {};  // Clear commands
    res.json(commands);
  } else {
    res.json({});
  }
});

// Web client gửi lệnh điều khiển
app.post('/api/control', (req, res) => {
  const { device, action } = req.body;
  console.log(`Control command: ${device} -> ${action}`);
  
  // Lưu lệnh để ESP8266 lấy
  pendingCommands[device] = action;
  
  res.json({ 
    status: 'success',
    message: `Command ${action} for ${device} queued`
  });
});

// Lấy dữ liệu hiện tại (cho web)
app.get('/api/status', (req, res) => {
  res.json(systemData);
});

// ===== KHỞI ĐỘNG SERVER =====
app.listen(PORT, '0.0.0.0', () => {
  console.log('==============================================');
  console.log('IoT Dashboard Server Started');
  console.log('==============================================');
  console.log(`HTTP Server: http://localhost:${PORT}`);
  console.log(`WebSocket Server: ws://localhost:3001`);
  console.log('==============================================');
  console.log('Waiting for ESP8266 connection...');
  console.log('');
});

// Xử lý tắt server
process.on('SIGINT', () => {
  console.log('\nShutting down server...');
  wss.close();
  process.exit(0);
});
