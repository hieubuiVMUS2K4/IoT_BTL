# Fix Lỗi ECONNREFUSED khi Deploy Render

## ❌ Lỗi gặp phải:
```
Error: connect ECONNREFUSED 127.0.0.1:5432
```

Server đang cố kết nối PostgreSQL ở localhost thay vì database trên Render.

## ✅ Giải pháp:

### Bước 1: Thêm DATABASE_URL vào Render Environment

1. Vào **Render Dashboard**: https://dashboard.render.com/
2. Click vào PostgreSQL service: **iot-database** (hoặc `iot_db_13qh`)
3. Tab **Info** → Copy **Internal Database URL**
   ```
   postgresql://iot_db_13qh_user:yoVnRBB4CG5sIiyuI0WRQRuIvBZ6DPm5@dpg-d50fdim3jp1c73a3if80-a.singapore-postgres.render.com/iot_db_13qh
   ```

4. Vào **Web Service**: **iot-mqtt-server**
5. Tab **Environment**
6. Click **Add Environment Variable**:
   - **Key**: `DATABASE_URL`
   - **Value**: Paste Internal Database URL từ bước 3
7. Click **Save Changes**

### Bước 2: Redeploy Service

Sau khi thêm environment variable:
- Render sẽ tự động trigger deploy lại
- Hoặc click **Manual Deploy** → **Deploy latest commit**

### Bước 3: Kiểm tra Logs

1. Tab **Logs** trong Web Service
2. Chờ deploy xong
3. Tìm dòng:
   ```
   ✅ Connected to PostgreSQL database
   ✅ Database initialized successfully
   🚀 HTTP Server running on port 3000
   ```

## 📋 Checklist:

- [ ] PostgreSQL service đã tạo và status = "Available"
- [ ] Copy Internal Database URL từ PostgreSQL service
- [ ] Thêm `DATABASE_URL` vào Web Service Environment
- [ ] Redeploy Web Service
- [ ] Kiểm tra logs thấy "Connected to PostgreSQL"
- [ ] Test API: `https://iot-btl-9tr7.onrender.com/health`

## 🔍 Kiểm tra sau khi deploy:

### Test Health Check:
```bash
curl https://iot-btl-9tr7.onrender.com/health
```

Kết quả mong đợi:
```json
{"status":"ok","timestamp":"2025-12-16T..."}
```

### Test Sensor API:
```bash
curl https://iot-btl-9tr7.onrender.com/api/sensor/latest
```

### Xem Database có data:
```bash
curl https://iot-btl-9tr7.onrender.com/api/sensor/history?limit=5
```

## ⚠️ Lưu ý:

### Sự khác biệt giữa Internal và External URL:

**Internal Database URL** (cho Render services cùng region):
```
postgresql://user:pass@dpg-xxx.singapore-postgres.render.com/database
```

**External Database URL** (cho local development):
```
postgresql://user:pass@dpg-xxx-a.singapore-postgres.render.com/database
```

Khi set `DATABASE_URL` trong Render Environment, **dùng Internal URL** để tránh phí bandwidth.

### Nếu vẫn lỗi:

1. **Kiểm tra DATABASE_URL format:**
   - Phải có dạng: `postgresql://username:password@host/database`
   - Không có khoảng trắng
   - Password đúng (có thể có ký tự đặc biệt)

2. **Kiểm tra Region:**
   - PostgreSQL và Web Service **phải cùng region** (Singapore)
   - Nếu khác region, phải dùng External URL

3. **Kiểm tra Firewall:**
   - Render tự động cấu hình, không cần thêm gì

4. **Reset Environment:**
   ```bash
   # Xóa DATABASE_URL cũ
   # Thêm lại DATABASE_URL mới
   # Redeploy
   ```

## 🚀 Alternative: Dùng render.yaml (Tự động)

Nếu muốn Render tự động link database, dùng file này:

```yaml
databases:
  - name: iot-database
    databaseName: iot_db_13qh  # Tên database đã tạo
    plan: free

services:
  - type: web
    name: iot-mqtt-server
    env: node
    buildCommand: npm install
    startCommand: node server_postgres.js
    envVars:
      - key: DATABASE_URL
        fromDatabase:
          name: iot-database
          property: connectionString
      - key: NODE_ENV
        value: production
```

**Nhưng** cách này chỉ hoạt động nếu:
- Chưa tạo database thủ công
- Hoặc database name trong YAML khớp với database đã tạo

## 📊 Kiểm tra kết nối trong Logs:

### ✅ Logs thành công:
```
[dotenv] injecting env (8) from .env
✅ Connected to PostgreSQL database
✅ Database initialized successfully
✅ Server initialized with PostgreSQL
🚀 HTTP Server running on port 3000
🔌 WebSocket Server running on port 3001
📊 Database: PostgreSQL connected
```

### ❌ Logs lỗi:
```
Error: connect ECONNREFUSED 127.0.0.1:5432
❌ Error initializing database
❌ Failed to initialize server
```

→ DATABASE_URL chưa được set hoặc sai format

## 🛠️ Debug Commands:

Nếu cần debug trên Render Shell:

```bash
# Kiểm tra environment variables
echo $DATABASE_URL

# Test kết nối PostgreSQL
node -e "const {Pool}=require('pg');const p=new Pool({connectionString:process.env.DATABASE_URL,ssl:{rejectUnauthorized:false}});p.query('SELECT NOW()').then(r=>console.log(r.rows)).catch(e=>console.error(e)).finally(()=>p.end())"
```

## 📞 Cần thêm hỗ trợ?

1. Xem Render Docs: https://render.com/docs/databases
2. Xem logs chi tiết trong Dashboard
3. Kiểm tra PostgreSQL service status
