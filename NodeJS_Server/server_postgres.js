const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const WebSocket = require('ws');
const path = require('path');
const db = require('./db');

const app = express();
const PORT = process.env.PORT || 3000;
const WS_PORT = process.env.WS_PORT || 3001;

// Middleware
app.use(cors());
app.use(bodyParser.json());
app.use(express.static(path.join(__dirname, 'public')));

// ===== DỮ LIỆU HỆ THỐNG (Cache) =====
let systemData = {
  pir: false,
  led1: false,
  led2: false,
  temperature: 0,
  humidity: 0,
  fan: false,
  fanAuto: true,
  door: false,
  intruder: false,
  rfid: false,
  distance: 0,
  lastUpdate: new Date().toISOString()
};

// ===== LỆNH ĐIỀU KHIỂN =====
let pendingCommands = {};

// ===== WEBSOCKET SERVER =====
const wss = new WebSocket.Server({ port: WS_PORT });

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

// ===== INITIALIZE DATABASE =====
async function initServer() {
  try {
    await db.initializeDatabase();
    console.log('✅ Server initialized with PostgreSQL');
    
    // Load latest device statuses from database
    const deviceStatuses = await db.getAllDeviceStatus();
    deviceStatuses.forEach(device => {
      systemData[device.device_name] = device.status;
      if (device.device_name === 'fan') {
        systemData.fanAuto = device.auto_mode;
      }
    });
    
    // Load latest sensor data
    const latestData = await db.getLatestSensorData();
    if (latestData) {
      systemData.temperature = parseFloat(latestData.temperature) || 0;
      systemData.humidity = parseFloat(latestData.humidity) || 0;
      systemData.distance = latestData.distance || 0;
      systemData.pir = latestData.pir || false;
      systemData.rfid = latestData.rfid || false;
      systemData.intruder = latestData.intruder || false;
    }
  } catch (err) {
    console.error('❌ Failed to initialize server:', err);
    process.exit(1);
  }
}

// ===== API ENDPOINTS =====

// Trang chủ
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// ===== SENSOR DATA APIs =====

// Nhận dữ liệu từ ESP8266
app.post('/api/data', async (req, res) => {
  console.log('Received data from ESP8266:', req.body);
  
  try {
    // Cập nhật dữ liệu hệ thống (cache)
    systemData = {
      ...systemData,
      ...req.body,
      lastUpdate: new Date().toISOString()
    };
    
    // Lưu vào database
    await db.insertSensorData(req.body);
    
    // Check for intrusion alert
    if (req.body.intruder && !systemData.intruder) {
      await db.insertEventLog('INTRUSION', 'Intruder detected!', 'CRITICAL');
    }
    
    // Check for motion
    if (req.body.pir && !systemData.pir) {
      await db.insertEventLog('MOTION', 'Motion detected', 'WARNING');
    }
    
    // Broadcast qua WebSocket
    broadcast({
      type: 'update',
      data: systemData
    });
    
    res.json({ 
      status: 'success',
      message: 'Data received and saved'
    });
  } catch (err) {
    console.error('Error processing sensor data:', err);
    res.status(500).json({
      status: 'error',
      message: 'Failed to save sensor data'
    });
  }
});

// Lấy dữ liệu sensor mới nhất
app.get('/api/sensor/latest', async (req, res) => {
  try {
    const data = await db.getLatestSensorData();
    res.json(data || systemData);
  } catch (err) {
    console.error('Error getting latest sensor data:', err);
    res.status(500).json({ error: 'Failed to get sensor data' });
  }
});

// Lấy lịch sử dữ liệu sensor
app.get('/api/sensor/history', async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 100;
    const offset = parseInt(req.query.offset) || 0;
    const history = await db.getSensorHistory(limit, offset);
    res.json(history);
  } catch (err) {
    console.error('Error getting sensor history:', err);
    res.status(500).json({ error: 'Failed to get sensor history' });
  }
});

// Lấy dữ liệu sensor theo khoảng thời gian
app.get('/api/sensor/range', async (req, res) => {
  try {
    const { start, end } = req.query;
    if (!start || !end) {
      return res.status(400).json({ error: 'Start and end time required' });
    }
    const data = await db.getSensorDataByTimeRange(new Date(start), new Date(end));
    res.json(data);
  } catch (err) {
    console.error('Error getting sensor data by range:', err);
    res.status(500).json({ error: 'Failed to get sensor data' });
  }
});

// Lấy thống kê
app.get('/api/sensor/statistics', async (req, res) => {
  try {
    const hours = parseInt(req.query.hours) || 24;
    const stats = await db.getStatistics(hours);
    res.json(stats);
  } catch (err) {
    console.error('Error getting statistics:', err);
    res.status(500).json({ error: 'Failed to get statistics' });
  }
});

// ===== DEVICE CONTROL APIs =====

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

// API điều khiển LED1
app.post('/api/control/led1', async (req, res) => {
  const { state } = req.body;
  systemData.led1 = state;
  pendingCommands.led1 = state;
  
  try {
    await db.updateDeviceStatus('led1', state);
    await db.insertEventLog('CONTROL', `LED1 turned ${state ? 'ON' : 'OFF'}`, 'INFO');
    
    broadcast({
      type: 'update',
      data: systemData
    });
    
    res.json({ status: 'success', led1: state });
  } catch (err) {
    console.error('Error controlling LED1:', err);
    res.status(500).json({ error: 'Failed to control LED1' });
  }
});

// API điều khiển LED2
app.post('/api/control/led2', async (req, res) => {
  const { state } = req.body;
  systemData.led2 = state;
  pendingCommands.led2 = state;
  
  try {
    await db.updateDeviceStatus('led2', state);
    await db.insertEventLog('CONTROL', `LED2 turned ${state ? 'ON' : 'OFF'}`, 'INFO');
    
    broadcast({
      type: 'update',
      data: systemData
    });
    
    res.json({ status: 'success', led2: state });
  } catch (err) {
    console.error('Error controlling LED2:', err);
    res.status(500).json({ error: 'Failed to control LED2' });
  }
});

// API điều khiển FAN
app.post('/api/control/fan', async (req, res) => {
  const { state, auto } = req.body;
  
  if (auto !== undefined) {
    systemData.fanAuto = auto;
  }
  if (state !== undefined) {
    systemData.fan = state;
    pendingCommands.fan = state;
  }
  
  try {
    await db.updateDeviceStatus('fan', systemData.fan, systemData.fanAuto);
    await db.insertEventLog('CONTROL', 
      `Fan ${state ? 'ON' : 'OFF'}, Auto: ${systemData.fanAuto}`, 'INFO');
    
    broadcast({
      type: 'update',
      data: systemData
    });
    
    res.json({ 
      status: 'success', 
      fan: systemData.fan, 
      fanAuto: systemData.fanAuto 
    });
  } catch (err) {
    console.error('Error controlling fan:', err);
    res.status(500).json({ error: 'Failed to control fan' });
  }
});

// API điều khiển DOOR
app.post('/api/control/door', async (req, res) => {
  const { state } = req.body;
  systemData.door = state;
  pendingCommands.door = state;
  
  try {
    await db.updateDeviceStatus('door', state);
    await db.insertEventLog('CONTROL', `Door ${state ? 'OPENED' : 'CLOSED'}`, 'WARNING');
    
    broadcast({
      type: 'update',
      data: systemData
    });
    
    res.json({ status: 'success', door: state });
  } catch (err) {
    console.error('Error controlling door:', err);
    res.status(500).json({ error: 'Failed to control door' });
  }
});

// Lấy trạng thái tất cả thiết bị
app.get('/api/devices/status', async (req, res) => {
  try {
    const statuses = await db.getAllDeviceStatus();
    res.json(statuses);
  } catch (err) {
    console.error('Error getting device statuses:', err);
    res.status(500).json({ error: 'Failed to get device statuses' });
  }
});

// ===== EVENT LOGS APIs =====

// Lấy event logs
app.get('/api/events', async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 50;
    const eventType = req.query.type || null;
    const severity = req.query.severity || null;
    
    const events = await db.getEventLogs(limit, eventType, severity);
    res.json(events);
  } catch (err) {
    console.error('Error getting events:', err);
    res.status(500).json({ error: 'Failed to get events' });
  }
});

// ===== MAINTENANCE APIs =====

// Clean old data (admin only)
app.post('/api/admin/clean-data', async (req, res) => {
  try {
    const days = parseInt(req.query.days) || 30;
    const deletedCount = await db.cleanOldData(days);
    res.json({ 
      status: 'success', 
      message: `Deleted ${deletedCount} old records` 
    });
  } catch (err) {
    console.error('Error cleaning data:', err);
    res.status(500).json({ error: 'Failed to clean data' });
  }
});

// ===== START SERVER =====
initServer().then(() => {
  app.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 HTTP Server running on port ${PORT}`);
    console.log(`🔌 WebSocket Server running on port ${WS_PORT}`);
    console.log(`📊 Database: PostgreSQL connected`);
  });
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('SIGTERM received, closing server...');
  await db.pool.end();
  process.exit(0);
});
