-- PostgreSQL Schema for IoT Project
-- Run this script to initialize the database

-- Drop existing tables if needed (be careful in production!)
-- DROP TABLE IF EXISTS sensor_data CASCADE;
-- DROP TABLE IF EXISTS device_status CASCADE;
-- DROP TABLE IF EXISTS event_logs CASCADE;
-- DROP TABLE IF EXISTS users CASCADE;

-- ===== SENSOR DATA TABLE =====
CREATE TABLE IF NOT EXISTS sensor_data (
    id SERIAL PRIMARY KEY,
    temperature DECIMAL(5,2),
    humidity DECIMAL(5,2),
    distance INTEGER,
    pir BOOLEAN DEFAULT FALSE,
    rfid BOOLEAN DEFAULT FALSE,
    intruder BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ===== DEVICE STATUS TABLE =====
CREATE TABLE IF NOT EXISTS device_status (
    id SERIAL PRIMARY KEY,
    device_name VARCHAR(50) UNIQUE NOT NULL,
    status BOOLEAN DEFAULT FALSE,
    auto_mode BOOLEAN DEFAULT FALSE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ===== EVENT LOGS TABLE =====
CREATE TABLE IF NOT EXISTS event_logs (
    id SERIAL PRIMARY KEY,
    event_type VARCHAR(50) NOT NULL,
    description TEXT,
    severity VARCHAR(20) DEFAULT 'INFO', -- INFO, WARNING, CRITICAL
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ===== USERS TABLE =====
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(20) DEFAULT 'user', -- admin, user
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP
);

-- ===== INDEXES FOR PERFORMANCE =====
CREATE INDEX IF NOT EXISTS idx_sensor_created_at ON sensor_data(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_event_created_at ON event_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_event_type ON event_logs(event_type);
CREATE INDEX IF NOT EXISTS idx_event_severity ON event_logs(severity);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

-- ===== INITIAL DATA =====
-- Insert default device statuses
INSERT INTO device_status (device_name, status, auto_mode) VALUES
    ('led1', FALSE, FALSE),
    ('led2', FALSE, FALSE),
    ('fan', FALSE, TRUE),
    ('door', FALSE, FALSE)
ON CONFLICT (device_name) DO NOTHING;

-- Insert system initialization event
INSERT INTO event_logs (event_type, description, severity) VALUES
    ('SYSTEM', 'Database schema initialized', 'INFO');

-- ===== FUNCTIONS & TRIGGERS =====

-- Function to update updated_at timestamp automatically
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger for device_status table
DROP TRIGGER IF EXISTS update_device_status_updated_at ON device_status;
CREATE TRIGGER update_device_status_updated_at
    BEFORE UPDATE ON device_status
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ===== VIEWS FOR COMMON QUERIES =====

-- View: Latest sensor readings
CREATE OR REPLACE VIEW latest_sensor_data AS
SELECT * FROM sensor_data
ORDER BY created_at DESC
LIMIT 1;

-- View: Recent events (last 100)
CREATE OR REPLACE VIEW recent_events AS
SELECT * FROM event_logs
ORDER BY created_at DESC
LIMIT 100;

-- View: Critical events (last 24 hours)
CREATE OR REPLACE VIEW critical_events AS
SELECT * FROM event_logs
WHERE severity = 'CRITICAL'
AND created_at > NOW() - INTERVAL '24 hours'
ORDER BY created_at DESC;

-- View: Hourly statistics (last 24 hours)
CREATE OR REPLACE VIEW hourly_stats AS
SELECT 
    DATE_TRUNC('hour', created_at) as hour,
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
WHERE created_at > NOW() - INTERVAL '24 hours'
GROUP BY hour
ORDER BY hour DESC;

-- ===== MAINTENANCE FUNCTIONS =====

-- Function to clean old sensor data (keep last N days)
CREATE OR REPLACE FUNCTION clean_old_sensor_data(days_to_keep INTEGER DEFAULT 30)
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM sensor_data
    WHERE created_at < NOW() - (days_to_keep || ' days')::INTERVAL;
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    
    INSERT INTO event_logs (event_type, description, severity) VALUES
        ('MAINTENANCE', 'Cleaned ' || deleted_count || ' old sensor records', 'INFO');
    
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Function to clean old event logs (keep last N days)
CREATE OR REPLACE FUNCTION clean_old_event_logs(days_to_keep INTEGER DEFAULT 90)
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM event_logs
    WHERE created_at < NOW() - (days_to_keep || ' days')::INTERVAL
    AND severity != 'CRITICAL'; -- Keep all critical events
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- ===== PERMISSIONS (if needed) =====
-- GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO iot_user;
-- GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO iot_user;

-- ===== COMPLETION MESSAGE =====
DO $$
BEGIN
    RAISE NOTICE 'Database schema initialized successfully!';
    RAISE NOTICE 'Tables created: sensor_data, device_status, event_logs, users';
    RAISE NOTICE 'Views created: latest_sensor_data, recent_events, critical_events, hourly_stats';
    RAISE NOTICE 'Maintenance functions available: clean_old_sensor_data(), clean_old_event_logs()';
END $$;
