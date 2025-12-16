# Hướng dẫn xem Database PostgreSQL

## Cách 1: Dùng Script Node.js (Nhanh nhất) ⚡

```powershell
cd NodeJS_Server
node view_db.js
```

Script sẽ hiển thị:
- ✅ Danh sách bảng
- ✅ Dữ liệu sensor mới nhất
- ✅ Trạng thái thiết bị
- ✅ Event logs
- ✅ Thống kê 24h
- ✅ Thông tin database

---

## Cách 2: Dùng pgAdmin (GUI - Recommended) 🖥️

### Bước 1: Download pgAdmin
- Tải tại: https://www.pgadmin.org/download/
- Chọn phiên bản Windows

### Bước 2: Kết nối
1. Mở pgAdmin
2. Click chuột phải **Servers** → **Register** → **Server**
3. Tab **General**:
   - Name: `Render IoT Database`
4. Tab **Connection**:
   - Host: `dpg-d50fdim3jp1c73a3if80-a.singapore-postgres.render.com`
   - Port: `5432`
   - Database: `iot_db_13qh`
   - Username: `iot_db_13qh_user`
   - Password: `yoVnRBB4CG5sIiyuI0WRQRuIvBZ6DPm5`
5. Tab **SSL**: Mode = `Require`
6. Click **Save**

### Bước 3: Xem dữ liệu
- Servers → Render IoT Database → Databases → iot_db_13qh → Schemas → public → Tables
- Click chuột phải vào bảng → **View/Edit Data** → **All Rows**

---

## Cách 3: Dùng DBeaver (Free & Powerful) 🔥

### Bước 1: Download DBeaver
- Tải tại: https://dbeaver.io/download/
- Chọn Community Edition (miễn phí)

### Bước 2: Kết nối
1. Mở DBeaver
2. Click **Database** → **New Database Connection**
3. Chọn **PostgreSQL**
4. Điền thông tin:
   - **Host**: `dpg-d50fdim3jp1c73a3if80-a.singapore-postgres.render.com`
   - **Port**: `5432`
   - **Database**: `iot_db_13qh`
   - **Username**: `iot_db_13qh_user`
   - **Password**: `yoVnRBB4CG5sIiyuI0WRQRuIvBZ6DPm5`
5. Tab **SSL**: Check "Use SSL"
6. Click **Test Connection** → **Finish**

### Bước 3: Xem dữ liệu
- Mở database → public → Tables
- Double-click vào bảng để xem data
- Tab **Data** để xem, **Properties** để xem cấu trúc

---

## Cách 4: Dùng TablePlus (Đẹp & Dễ dùng) ✨

### Bước 1: Download TablePlus
- Tải tại: https://tableplus.com/
- Free trial, sau đó $59 (lifetime)

### Bước 2: Kết nối
1. Mở TablePlus
2. Click **Create a new connection** → **PostgreSQL**
3. Điền:
   - **Name**: `Render IoT`
   - **Host**: `dpg-d50fdim3jp1c73a3if80-a.singapore-postgres.render.com`
   - **Port**: `5432`
   - **User**: `iot_db_13qh_user`
   - **Password**: `yoVnRBB4CG5sIiyuI0WRQRuIvBZ6DPm5`
   - **Database**: `iot_db_13qh`
   - **SSL Mode**: Require
4. Click **Test** → **Connect**

---

## Cách 5: Dùng psql (Command Line) 💻

### Cài đặt PostgreSQL Client
Download từ: https://www.postgresql.org/download/windows/

### Kết nối
```powershell
psql "postgresql://iot_db_13qh_user:yoVnRBB4CG5sIiyuI0WRQRuIvBZ6DPm5@dpg-d50fdim3jp1c73a3if80-a.singapore-postgres.render.com/iot_db_13qh?sslmode=require"
```

### Lệnh psql hữu ích
```sql
-- Xem danh sách bảng
\dt

-- Xem cấu trúc bảng
\d sensor_data

-- Query dữ liệu
SELECT * FROM sensor_data LIMIT 10;
SELECT * FROM device_status;
SELECT * FROM event_logs ORDER BY created_at DESC LIMIT 20;

-- Thống kê
SELECT COUNT(*) FROM sensor_data;

-- Thoát
\q
```

---

## Cách 6: Xem trên Render Dashboard 🌐

1. Vào https://dashboard.render.com/
2. Click vào **iot-database** (PostgreSQL service)
3. Tab **Info** → Click **Connect**
4. Chọn **External** hoặc **PSQL Command**

Tuy nhiên, Render không có GUI tích hợp để xem data, chỉ có psql CLI.

---

## So sánh các cách

| Cách | Ưu điểm | Nhược điểm |
|------|---------|------------|
| **Script Node.js** | Nhanh, không cần cài đặt | Chỉ xem được, không sửa |
| **pgAdmin** | Official, đầy đủ tính năng | Giao diện hơi phức tạp |
| **DBeaver** | Miễn phí, mạnh mẽ | Hơi nặng |
| **TablePlus** | Đẹp, dễ dùng | Có phí (sau trial) |
| **psql** | Nhanh, nhẹ | Command line, khó dùng |

---

## Queries hữu ích

### Xem dữ liệu mới nhất
```sql
SELECT * FROM sensor_data 
ORDER BY created_at DESC 
LIMIT 10;
```

### Thống kê nhiệt độ
```sql
SELECT 
  AVG(temperature) as avg_temp,
  MAX(temperature) as max_temp,
  MIN(temperature) as min_temp
FROM sensor_data
WHERE created_at > NOW() - INTERVAL '24 hours';
```

### Xem cảnh báo xâm nhập
```sql
SELECT * FROM event_logs
WHERE event_type = 'INTRUSION'
ORDER BY created_at DESC;
```

### Đếm số bản ghi theo giờ
```sql
SELECT 
  DATE_TRUNC('hour', created_at) as hour,
  COUNT(*) as count
FROM sensor_data
WHERE created_at > NOW() - INTERVAL '24 hours'
GROUP BY hour
ORDER BY hour DESC;
```

---

## Khuyến nghị 🌟

**Cho người mới:** TablePlus hoặc DBeaver (GUI đẹp, dễ dùng)

**Cho developer:** pgAdmin (đầy đủ tính năng)

**Xem nhanh:** Script Node.js (`node view_db.js`)
