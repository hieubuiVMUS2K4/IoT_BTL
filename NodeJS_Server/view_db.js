// View PostgreSQL Database Contents
const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.NODE_ENV === 'production' ? {
    rejectUnauthorized: false
  } : false
});

async function viewDatabase() {
  console.log('\n╔════════════════════════════════════════════╗');
  console.log('║     PostgreSQL Database Viewer             ║');
  console.log('╚════════════════════════════════════════════╝\n');
  
  try {
    const client = await pool.connect();
    console.log('✅ Connected to database\n');
    
    // 1. Show all tables
    console.log('📋 TABLES:');
    console.log('─'.repeat(50));
    const tables = await client.query(`
      SELECT table_name, 
             (SELECT COUNT(*) FROM information_schema.columns 
              WHERE table_name = t.table_name) as column_count
      FROM information_schema.tables t
      WHERE table_schema = 'public' 
        AND table_type = 'BASE TABLE'
      ORDER BY table_name
    `);
    
    tables.rows.forEach(row => {
      console.log(`  📊 ${row.table_name.padEnd(30)} (${row.column_count} columns)`);
    });
    
    // 2. Show sensor data
    console.log('\n🌡️  SENSOR DATA (Latest 10):');
    console.log('─'.repeat(50));
    const sensors = await client.query(`
      SELECT id, temperature, humidity, distance, pir, intruder, 
             TO_CHAR(created_at, 'YYYY-MM-DD HH24:MI:SS') as time
      FROM sensor_data 
      ORDER BY created_at DESC 
      LIMIT 10
    `);
    
    if (sensors.rows.length > 0) {
      console.table(sensors.rows);
    } else {
      console.log('  ℹ️  No sensor data yet\n');
    }
    
    // 3. Show device status
    console.log('\n🔌 DEVICE STATUS:');
    console.log('─'.repeat(50));
    const devices = await client.query(`
      SELECT device_name, status, auto_mode,
             TO_CHAR(updated_at, 'YYYY-MM-DD HH24:MI:SS') as last_update
      FROM device_status 
      ORDER BY device_name
    `);
    
    if (devices.rows.length > 0) {
      console.table(devices.rows);
    } else {
      console.log('  ℹ️  No device data yet\n');
    }
    
    // 4. Show event logs
    console.log('\n📝 EVENT LOGS (Latest 15):');
    console.log('─'.repeat(50));
    const events = await client.query(`
      SELECT id, event_type, description, severity,
             TO_CHAR(created_at, 'YYYY-MM-DD HH24:MI:SS') as time
      FROM event_logs 
      ORDER BY created_at DESC 
      LIMIT 15
    `);
    
    if (events.rows.length > 0) {
      console.table(events.rows);
    } else {
      console.log('  ℹ️  No events yet\n');
    }
    
    // 5. Show statistics
    console.log('\n📊 STATISTICS (24 hours):');
    console.log('─'.repeat(50));
    const stats = await client.query(`
      SELECT 
        COUNT(*) as total_records,
        AVG(temperature)::NUMERIC(5,2) as avg_temp,
        MAX(temperature) as max_temp,
        MIN(temperature) as min_temp,
        AVG(humidity)::NUMERIC(5,2) as avg_humidity,
        COUNT(CASE WHEN intruder = TRUE THEN 1 END) as intrusion_count,
        COUNT(CASE WHEN pir = TRUE THEN 1 END) as motion_count
      FROM sensor_data
      WHERE created_at > NOW() - INTERVAL '24 hours'
    `);
    
    if (stats.rows.length > 0 && stats.rows[0].total_records > 0) {
      const s = stats.rows[0];
      console.log(`  📈 Total Records:    ${s.total_records}`);
      console.log(`  🌡️  Avg Temperature:  ${s.avg_temp}°C (min: ${s.min_temp}, max: ${s.max_temp})`);
      console.log(`  💧 Avg Humidity:     ${s.avg_humidity}%`);
      console.log(`  🚨 Intrusions:       ${s.intrusion_count}`);
      console.log(`  👁️  Motion Detected:  ${s.motion_count}`);
    } else {
      console.log('  ℹ️  No data in last 24 hours\n');
    }
    
    // 6. Database size info
    console.log('\n💾 DATABASE INFO:');
    console.log('─'.repeat(50));
    const dbInfo = await client.query(`
      SELECT 
        pg_database.datname as database_name,
        pg_size_pretty(pg_database_size(pg_database.datname)) as size,
        (SELECT COUNT(*) FROM sensor_data) as sensor_records,
        (SELECT COUNT(*) FROM event_logs) as event_records
      FROM pg_database
      WHERE datname = current_database()
    `);
    
    if (dbInfo.rows.length > 0) {
      const info = dbInfo.rows[0];
      console.log(`  📛 Database:         ${info.database_name}`);
      console.log(`  💾 Size:             ${info.size}`);
      console.log(`  📊 Sensor Records:   ${info.sensor_records}`);
      console.log(`  📝 Event Records:    ${info.event_records}`);
    }
    
    client.release();
    
    console.log('\n' + '─'.repeat(50));
    console.log('✅ Database view completed!\n');
    
  } catch (err) {
    console.error('❌ Error viewing database:', err.message);
  } finally {
    await pool.end();
  }
}

// Check command line arguments for specific queries
const args = process.argv.slice(2);
if (args.includes('--help') || args.includes('-h')) {
  console.log(`
Usage: node view_db.js [options]

Options:
  --help, -h     Show this help message
  
Examples:
  node view_db.js              View all database contents
  
After running, you can:
  1. Use pgAdmin, DBeaver, or TablePlus for GUI access
  2. Connect with: ${process.env.DATABASE_URL?.substring(0, 40)}...
  `);
  process.exit(0);
}

viewDatabase();
