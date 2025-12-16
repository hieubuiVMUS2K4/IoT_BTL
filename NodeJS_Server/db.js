const { Pool } = require('pg');
require('dotenv').config();

// PostgreSQL connection pool
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.NODE_ENV === 'production' ? {
    rejectUnauthorized: false
  } : false,
  // Connection pool settings
  max: 20, // Maximum number of clients
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 10000,
});

// Test connection
pool.on('connect', () => {
  console.log('✅ Connected to PostgreSQL database');
});

pool.on('error', (err) => {
  console.error('❌ Unexpected error on idle client', err);
  process.exit(-1);
});

// ===== DATABASE FUNCTIONS =====

/**
 * Insert sensor data
 */
async function insertSensorData(data) {
  const query = `
    INSERT INTO sensor_data (temperature, humidity, distance, pir, rfid, intruder)
    VALUES ($1, $2, $3, $4, $5, $6)
    RETURNING id, created_at
  `;
  
  try {
    const result = await pool.query(query, [
      data.temperature || 0,
      data.humidity || 0,
      data.distance || 0,
      data.pir || false,
      data.rfid || false,
      data.intruder || false
    ]);
    return result.rows[0];
  } catch (err) {
    console.error('Error inserting sensor data:', err);
    throw err;
  }
}

/**
 * Get latest sensor data
 */
async function getLatestSensorData() {
  const query = `
    SELECT * FROM sensor_data
    ORDER BY created_at DESC
    LIMIT 1
  `;
  
  try {
    const result = await pool.query(query);
    return result.rows[0] || null;
  } catch (err) {
    console.error('Error getting latest sensor data:', err);
    throw err;
  }
}

/**
 * Get sensor data history with pagination
 */
async function getSensorHistory(limit = 100, offset = 0) {
  const query = `
    SELECT * FROM sensor_data
    ORDER BY created_at DESC
    LIMIT $1 OFFSET $2
  `;
  
  try {
    const result = await pool.query(query, [limit, offset]);
    return result.rows;
  } catch (err) {
    console.error('Error getting sensor history:', err);
    throw err;
  }
}

/**
 * Get sensor data by time range
 */
async function getSensorDataByTimeRange(startTime, endTime) {
  const query = `
    SELECT * FROM sensor_data
    WHERE created_at BETWEEN $1 AND $2
    ORDER BY created_at DESC
  `;
  
  try {
    const result = await pool.query(query, [startTime, endTime]);
    return result.rows;
  } catch (err) {
    console.error('Error getting sensor data by time range:', err);
    throw err;
  }
}

/**
 * Update device status
 */
async function updateDeviceStatus(deviceName, status, autoMode = null) {
  let query, params;
  
  if (autoMode !== null) {
    query = `
      INSERT INTO device_status (device_name, status, auto_mode, updated_at)
      VALUES ($1, $2, $3, CURRENT_TIMESTAMP)
      ON CONFLICT (device_name) 
      DO UPDATE SET status = $2, auto_mode = $3, updated_at = CURRENT_TIMESTAMP
      RETURNING *
    `;
    params = [deviceName, status, autoMode];
  } else {
    query = `
      INSERT INTO device_status (device_name, status, updated_at)
      VALUES ($1, $2, CURRENT_TIMESTAMP)
      ON CONFLICT (device_name) 
      DO UPDATE SET status = $2, updated_at = CURRENT_TIMESTAMP
      RETURNING *
    `;
    params = [deviceName, status];
  }
  
  try {
    const result = await pool.query(query, params);
    return result.rows[0];
  } catch (err) {
    console.error('Error updating device status:', err);
    throw err;
  }
}

/**
 * Get all device statuses
 */
async function getAllDeviceStatus() {
  const query = `
    SELECT * FROM device_status
    ORDER BY device_name
  `;
  
  try {
    const result = await pool.query(query);
    return result.rows;
  } catch (err) {
    console.error('Error getting device statuses:', err);
    throw err;
  }
}

/**
 * Insert event log
 */
async function insertEventLog(eventType, description, severity = 'INFO') {
  const query = `
    INSERT INTO event_logs (event_type, description, severity)
    VALUES ($1, $2, $3)
    RETURNING id, created_at
  `;
  
  try {
    const result = await pool.query(query, [eventType, description, severity]);
    return result.rows[0];
  } catch (err) {
    console.error('Error inserting event log:', err);
    throw err;
  }
}

/**
 * Get event logs with filters
 */
async function getEventLogs(limit = 50, eventType = null, severity = null) {
  let query = `SELECT * FROM event_logs WHERE 1=1`;
  const params = [];
  let paramIndex = 1;
  
  if (eventType) {
    query += ` AND event_type = $${paramIndex}`;
    params.push(eventType);
    paramIndex++;
  }
  
  if (severity) {
    query += ` AND severity = $${paramIndex}`;
    params.push(severity);
    paramIndex++;
  }
  
  query += ` ORDER BY created_at DESC LIMIT $${paramIndex}`;
  params.push(limit);
  
  try {
    const result = await pool.query(query, params);
    return result.rows;
  } catch (err) {
    console.error('Error getting event logs:', err);
    throw err;
  }
}

/**
 * Get statistics
 */
async function getStatistics(hours = 24) {
  const query = `
    SELECT 
      AVG(temperature) as avg_temperature,
      MAX(temperature) as max_temperature,
      MIN(temperature) as min_temperature,
      AVG(humidity) as avg_humidity,
      MAX(humidity) as max_humidity,
      MIN(humidity) as min_humidity,
      COUNT(CASE WHEN intruder = TRUE THEN 1 END) as intrusion_count,
      COUNT(CASE WHEN pir = TRUE THEN 1 END) as motion_count,
      COUNT(*) as total_records
    FROM sensor_data
    WHERE created_at > NOW() - INTERVAL '${hours} hours'
  `;
  
  try {
    const result = await pool.query(query);
    return result.rows[0];
  } catch (err) {
    console.error('Error getting statistics:', err);
    throw err;
  }
}

/**
 * Clean old data (keep only last N days)
 */
async function cleanOldData(daysToKeep = 30) {
  const query = `
    DELETE FROM sensor_data
    WHERE created_at < NOW() - INTERVAL '${daysToKeep} days'
    RETURNING id
  `;
  
  try {
    const result = await pool.query(query);
    console.log(`🗑️ Deleted ${result.rowCount} old records`);
    return result.rowCount;
  } catch (err) {
    console.error('Error cleaning old data:', err);
    throw err;
  }
}

/**
 * Initialize database tables (create if not exist)
 */
async function initializeDatabase() {
  const queries = [
    // Sensor data table
    `CREATE TABLE IF NOT EXISTS sensor_data (
      id SERIAL PRIMARY KEY,
      temperature DECIMAL(5,2),
      humidity DECIMAL(5,2),
      distance INTEGER,
      pir BOOLEAN DEFAULT FALSE,
      rfid BOOLEAN DEFAULT FALSE,
      intruder BOOLEAN DEFAULT FALSE,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )`,
    
    // Device status table
    `CREATE TABLE IF NOT EXISTS device_status (
      id SERIAL PRIMARY KEY,
      device_name VARCHAR(50) UNIQUE NOT NULL,
      status BOOLEAN DEFAULT FALSE,
      auto_mode BOOLEAN DEFAULT FALSE,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )`,
    
    // Event logs table
    `CREATE TABLE IF NOT EXISTS event_logs (
      id SERIAL PRIMARY KEY,
      event_type VARCHAR(50) NOT NULL,
      description TEXT,
      severity VARCHAR(20) DEFAULT 'INFO',
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )`,
    
    // Users table
    `CREATE TABLE IF NOT EXISTS users (
      id SERIAL PRIMARY KEY,
      email VARCHAR(255) UNIQUE NOT NULL,
      password_hash VARCHAR(255) NOT NULL,
      role VARCHAR(20) DEFAULT 'user',
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )`,
    
    // Create indexes
    `CREATE INDEX IF NOT EXISTS idx_sensor_created_at ON sensor_data(created_at DESC)`,
    `CREATE INDEX IF NOT EXISTS idx_event_created_at ON event_logs(created_at DESC)`,
    `CREATE INDEX IF NOT EXISTS idx_event_type ON event_logs(event_type)`,
    
    // Insert initial device statuses
    `INSERT INTO device_status (device_name, status, auto_mode)
     VALUES 
       ('led1', FALSE, FALSE),
       ('led2', FALSE, FALSE),
       ('fan', FALSE, TRUE),
       ('door', FALSE, FALSE)
     ON CONFLICT (device_name) DO NOTHING`
  ];
  
  try {
    for (const query of queries) {
      await pool.query(query);
    }
    console.log('✅ Database initialized successfully');
    
    // Log initialization event
    await insertEventLog('SYSTEM', 'Database initialized', 'INFO');
  } catch (err) {
    console.error('❌ Error initializing database:', err);
    throw err;
  }
}

module.exports = {
  pool,
  insertSensorData,
  getLatestSensorData,
  getSensorHistory,
  getSensorDataByTimeRange,
  updateDeviceStatus,
  getAllDeviceStatus,
  insertEventLog,
  getEventLogs,
  getStatistics,
  cleanOldData,
  initializeDatabase
};
