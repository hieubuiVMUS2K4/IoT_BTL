# Hướng dẫn thiết lập PostgreSQL trên Render

## Bước 1: Tạo PostgreSQL Database trên Render

1. Đăng nhập vào [Render Dashboard](https://dashboard.render.com/)
2. Click **"New +"** → Chọn **"PostgreSQL"**
3. Cấu hình database:
   - **Name**: `iot-database` (hoặc tên bạn muốn)
   - **Database**: `iot_db`
   - **User**: `iot_user` (tự động tạo)
   - **Region**: Chọn region gần nhất (Singapore cho Việt Nam)
   - **PostgreSQL Version**: 16 (hoặc mới nhất)
   - **Plan**: Free (hoặc chọn plan phù hợp)
4. Click **"Create Database"**

⏳ **Chờ 2-3 phút** để Render khởi tạo database

## Bước 2: Lấy thông tin kết nối

Sau khi database được tạo, vào tab **"Info"** và copy các thông tin sau:

- **Internal Database URL**: Dùng để kết nối từ Render service (cùng region)
- **External Database URL**: Dùng để kết nối từ local hoặc server khác

Format URL:
```
postgresql://iot_user:password@dpg-xxxxx.singapore-postgres.render.com/iot_db
```

## Bước 3: Thiết lập Schema Database

### 3.1 Kết nối với Database

**Option 1: Dùng psql CLI (Local)**
```bash
psql "postgresql://iot_user:password@dpg-xxxxx.singapore-postgres.render.com/iot_db"
```

**Option 2: Dùng pgAdmin hoặc DBeaver**
- Host: `dpg-xxxxx.singapore-postgres.render.com`
- Port: `5432`
- Database: `iot_db`
- Username: `iot_user`
- Password: [từ Render dashboard]

### 3.2 Tạo Tables

Chạy các SQL scripts sau:

```sql
-- Bảng lưu dữ liệu cảm biến
CREATE TABLE sensor_data (
    id SERIAL PRIMARY KEY,
    temperature DECIMAL(5,2),
    humidity DECIMAL(5,2),
    distance INTEGER,
    pir BOOLEAN DEFAULT FALSE,
    rfid BOOLEAN DEFAULT FALSE,
    intruder BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Bảng lưu trạng thái thiết bị
CREATE TABLE device_status (
    id SERIAL PRIMARY KEY,
    device_name VARCHAR(50) UNIQUE NOT NULL,
    status BOOLEAN DEFAULT FALSE,
    auto_mode BOOLEAN DEFAULT FALSE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Bảng lưu lịch sử sự kiện
CREATE TABLE event_logs (
    id SERIAL PRIMARY KEY,
    event_type VARCHAR(50) NOT NULL,
    description TEXT,
    severity VARCHAR(20) DEFAULT 'INFO', -- INFO, WARNING, CRITICAL
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Bảng users (nếu cần authentication)
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(20) DEFAULT 'user', -- admin, user
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Index cho tìm kiếm nhanh
CREATE INDEX idx_sensor_created_at ON sensor_data(created_at DESC);
CREATE INDEX idx_event_created_at ON event_logs(created_at DESC);
CREATE INDEX idx_event_type ON event_logs(event_type);

-- Insert initial device status
INSERT INTO device_status (device_name, status, auto_mode) VALUES
    ('led1', FALSE, FALSE),
    ('led2', FALSE, FALSE),
    ('fan', FALSE, TRUE),
    ('door', FALSE, FALSE);
```

## Bước 4: Cài đặt thư viện Node.js

Cập nhật `package.json`:

```bash
npm install pg dotenv
```

## Bước 5: Cấu hình Environment Variables

### 5.1 Tạo file `.env` (Local)

```env
# Server
PORT=3000
WS_PORT=3001

# MQTT
MQTT_BROKER=mqtt://10.137.147.176:1883
MQTT_PORT=1883
MQTT_USERNAME=
MQTT_PASSWORD=

# PostgreSQL
DATABASE_URL=postgresql://iot_user:password@dpg-xxxxx.singapore-postgres.render.com/iot_db
```

### 5.2 Cấu hình trên Render

1. Vào Web Service của bạn trên Render
2. Tab **"Environment"**
3. Thêm Environment Variable:
   - **Key**: `DATABASE_URL`
   - **Value**: Internal Database URL (copy từ PostgreSQL service)
4. Save Changes

## Bước 6: Cập nhật Code

Xem file `db.js` và `server_postgres.js` đã được tạo.

## Bước 7: Deploy lên Render

### 7.1 Cập nhật `render.yaml`

```yaml
services:
  - type: web
    name: iot-mqtt-server
    env: node
    buildCommand: npm install
    startCommand: node server_postgres.js
    envVars:
      - key: PORT
        value: 3000
      - key: WS_PORT
        value: 3001
      - key: MQTT_BROKER
        sync: false
      - key: DATABASE_URL
        fromDatabase:
          name: iot-database
          property: connectionString
```

### 7.2 Push code lên GitHub

```bash
git add .
git commit -m "Add PostgreSQL integration"
git push origin main
```

Render sẽ tự động deploy.

## Bước 8: Kiểm tra

### 8.1 Test API

```bash
# Lấy dữ liệu sensor mới nhất
curl https://your-app.onrender.com/api/sensor/latest

# Lấy lịch sử (10 bản ghi gần nhất)
curl https://your-app.onrender.com/api/sensor/history?limit=10

# Lấy event logs
curl https://your-app.onrender.com/api/events?limit=20
```

### 8.2 Xem logs trên Render

1. Vào Web Service
2. Tab **"Logs"**
3. Kiểm tra xem có lỗi kết nối database không

## Troubleshooting

### Lỗi kết nối database
- Kiểm tra `DATABASE_URL` có đúng không
- Đảm bảo database đã khởi tạo xong (status = Available)
- Kiểm tra firewall/network settings

### Lỗi SSL
Thêm `?sslmode=require` vào cuối DATABASE_URL:
```
postgresql://...iot_db?sslmode=require
```

### Performance issues trên Free plan
- Free plan có giới hạn 90 ngày, sau đó database bị xóa
- Giới hạn 256MB storage
- Giới hạn 97 hours uptime/tháng
- Cân nhắc nâng cấp lên Paid plan

## Query hữu ích

```sql
-- Xem dữ liệu sensor 24h qua
SELECT * FROM sensor_data 
WHERE created_at > NOW() - INTERVAL '24 hours'
ORDER BY created_at DESC;

-- Xem nhiệt độ trung bình theo giờ
SELECT 
    DATE_TRUNC('hour', created_at) as hour,
    AVG(temperature) as avg_temp,
    AVG(humidity) as avg_humidity
FROM sensor_data
WHERE created_at > NOW() - INTERVAL '24 hours'
GROUP BY hour
ORDER BY hour DESC;

-- Đếm số lần phát hiện xâm nhập
SELECT COUNT(*) as intrusion_count
FROM sensor_data
WHERE intruder = TRUE
AND created_at > NOW() - INTERVAL '7 days';

-- Dọn dẹp dữ liệu cũ (giữ lại 30 ngày)
DELETE FROM sensor_data 
WHERE created_at < NOW() - INTERVAL '30 days';
```

## Backup & Maintenance

### Tự động backup (Render Paid plan)
- Render tự động backup hàng ngày
- Restore từ backup trong dashboard

### Manual backup
```bash
pg_dump "postgresql://..." > backup.sql
```

### Restore
```bash
psql "postgresql://..." < backup.sql
```
