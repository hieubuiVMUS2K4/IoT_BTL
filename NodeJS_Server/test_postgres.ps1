# Test PostgreSQL Connection and Queries
# Run this script to verify database connection and test basic queries

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "PostgreSQL Connection Test" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# Check if .env file exists
if (-Not (Test-Path ".env")) {
    Write-Host "❌ .env file not found!" -ForegroundColor Red
    Write-Host "Please create .env file from .env.example and configure DATABASE_URL" -ForegroundColor Yellow
    exit 1
}

# Load environment variables
Get-Content .env | ForEach-Object {
    if ($_ -match '^([^#][^=]+)=(.*)$') {
        $key = $matches[1].Trim()
        $value = $matches[2].Trim()
        [Environment]::SetEnvironmentVariable($key, $value, "Process")
    }
}

$DATABASE_URL = $env:DATABASE_URL

if (-Not $DATABASE_URL) {
    Write-Host "❌ DATABASE_URL not configured in .env file!" -ForegroundColor Red
    exit 1
}

Write-Host "Database URL: $($DATABASE_URL.Substring(0, 20))..." -ForegroundColor Gray
Write-Host ""

# Create test script
$testScript = @"
const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.NODE_ENV === 'production' ? {
    rejectUnauthorized: false
  } : false
});

async function testConnection() {
  console.log('🔍 Testing PostgreSQL connection...\n');
  
  try {
    // Test connection
    const client = await pool.connect();
    console.log('✅ Connected to PostgreSQL successfully!\n');
    
    // Get database info
    const versionResult = await client.query('SELECT version()');
    console.log('📊 Database version:');
    console.log(versionResult.rows[0].version);
    console.log('');
    
    // Check if tables exist
    const tablesResult = await client.query(\`
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public'
      ORDER BY table_name
    \`);
    
    console.log('📋 Tables in database:');
    if (tablesResult.rows.length === 0) {
      console.log('  ⚠️  No tables found. Run schema.sql to initialize database.');
    } else {
      tablesResult.rows.forEach(row => {
        console.log('  - ' + row.table_name);
      });
    }
    console.log('');
    
    // Test query if sensor_data table exists
    const tableExists = tablesResult.rows.some(row => row.table_name === 'sensor_data');
    if (tableExists) {
      const countResult = await client.query('SELECT COUNT(*) FROM sensor_data');
      console.log(\`📈 Sensor data records: \${countResult.rows[0].count}\`);
      
      const latestResult = await client.query(\`
        SELECT * FROM sensor_data 
        ORDER BY created_at DESC 
        LIMIT 1
      \`);
      
      if (latestResult.rows.length > 0) {
        console.log('📡 Latest sensor data:');
        console.log(JSON.stringify(latestResult.rows[0], null, 2));
      } else {
        console.log('  ℹ️  No sensor data yet');
      }
    }
    
    client.release();
    console.log('\n✅ All tests passed!');
    
  } catch (err) {
    console.error('❌ Database connection error:', err.message);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

testConnection();
"@

# Save test script
$testScript | Out-File -FilePath "test_db_connection.js" -Encoding UTF8

# Install dependencies if needed
Write-Host "📦 Checking dependencies..." -ForegroundColor Yellow
if (-Not (Test-Path "node_modules\pg")) {
    Write-Host "Installing pg module..." -ForegroundColor Yellow
    npm install pg dotenv
}

Write-Host ""
Write-Host "🧪 Running connection test..." -ForegroundColor Yellow
Write-Host ""

# Run the test
node test_db_connection.js

# Cleanup
Remove-Item "test_db_connection.js" -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "Test completed!" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
