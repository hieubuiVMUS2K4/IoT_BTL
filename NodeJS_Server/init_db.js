// Initialize PostgreSQL Database Schema
const { Pool } = require('pg');
const fs = require('fs');
require('dotenv').config();

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: {
    rejectUnauthorized: false
  }
});

async function initializeDatabase() {
  console.log('🔧 Initializing PostgreSQL database...\n');
  
  try {
    // Read schema file
    const schema = fs.readFileSync('./schema.sql', 'utf8');
    
    // Connect to database
    const client = await pool.connect();
    console.log('✅ Connected to PostgreSQL\n');
    
    // Execute schema
    console.log('📝 Creating tables and indexes...');
    await client.query(schema);
    console.log('✅ Schema executed successfully!\n');
    
    // Verify tables
    const result = await client.query(`
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public'
      ORDER BY table_name
    `);
    
    console.log('📋 Tables created:');
    result.rows.forEach(row => {
      console.log(`  ✓ ${row.table_name}`);
    });
    
    client.release();
    console.log('\n🎉 Database initialization complete!');
    
  } catch (err) {
    console.error('❌ Error initializing database:', err);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

initializeDatabase();
