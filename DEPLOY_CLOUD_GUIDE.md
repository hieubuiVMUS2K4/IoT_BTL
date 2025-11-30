# Hướng dẫn Deploy lên Cloud - Điều khiển từ xa

## 🌐 Kiến trúc Cloud (Truy cập từ mọi nơi)

```
ESP8266 (Nhà) ──→ HiveMQ Cloud MQTT Broker (Free)
                          ↓
                  Node.js Server (Render.com - Free)
                          ↓
                  Flutter App (Điện thoại/máy tính ở bất kì đâu)
```

---

## Bước 1: Setup HiveMQ Cloud (MQTT Broker miễn phí)

### 1.1 Đăng ký HiveMQ Cloud
1. Truy cập: https://www.hivemq.com/mqtt-cloud-broker/
2. Click **"Get Started Free"**
3. Tạo tài khoản (email + password)
4. Tạo **Free Cluster**:
   - Name: `iot-smart-home`
   - Region: **Singapore** (gần VN nhất)
   - Plan: **Free** (100 connections, đủ dùng)

### 1.2 Lấy thông tin kết nối
Sau khi tạo xong, bạn sẽ có:
```
Host: abc123xyz.s1.eu.hivemq.cloud
Port: 8883 (MQTT over TLS)
Username: <your-username>
Password: <your-password>
```

**Lưu lại thông tin này!**

---

## Bước 2: Deploy Node.js Server lên Render.com (Miễn phí)

### 2.1 Đăng ký Render
1. Truy cập: https://render.com
2. Sign up bằng GitHub
3. Liên kết GitHub repository của bạn

### 2.2 Tạo Web Service
1. Click **"New +"** → **"Web Service"**
2. Connect repository: `IoT_BTL`
3. Cấu hình:
   - **Name**: `iot-mqtt-bridge`
   - **Root Directory**: `NodeJS_Server`
   - **Environment**: `Node`
   - **Build Command**: `npm install`
   - **Start Command**: `node server_mqtt.js`
   - **Instance Type**: `Free`

4. Environment Variables (thêm sau):
   ```
   MQTT_BROKER=<HiveMQ host>
   MQTT_PORT=8883
   MQTT_USERNAME=<HiveMQ username>
   MQTT_PASSWORD=<HiveMQ password>
   PORT=10000
   WS_PORT=10001
   ```

5. Click **"Create Web Service"**

Sau vài phút, bạn sẽ có:
- Server URL: `https://iot-mqtt-bridge.onrender.com`
- WebSocket: `wss://iot-mqtt-bridge.onrender.com:10001`

---

## Bước 3: Cập nhật Code

### 3.1 Sửa ESP8266 (kết nối HiveMQ Cloud)

```cpp
// Thay đổi trong ESP8266_Master.ino
const char* mqtt_server = "abc123xyz.s1.eu.hivemq.cloud";
const int mqtt_port = 8883;  // TLS port
const char* mqtt_user = "your-username";
const char* mqtt_pass = "your-password";

// Thêm TLS support
WiFiClientSecure espClient;
PubSubClient client(espClient);

void setup() {
  // ...existing code...
  espClient.setInsecure();  // Tạm thời bỏ qua cert validation
  client.setServer(mqtt_server, mqtt_port);
}
```

### 3.2 Sửa Node.js Server (hỗ trợ env variables)

File đã được chuẩn bị sẵn! Chỉ cần commit code lên GitHub.

### 3.3 Sửa Flutter App (kết nối server cloud)

```dart
// lib/services/iot_service.dart
IoTService({
  this.baseUrl = 'https://iot-mqtt-bridge.onrender.com',
  this.wsUrl = 'wss://iot-mqtt-bridge.onrender.com:10001',
});
```

---

## Bước 4: Test từ xa

1. Upload code ESP8266 mới
2. Mở Serial Monitor → Kiểm tra kết nối HiveMQ
3. Chạy Flutter app
4. **Tắt WiFi điện thoại → Bật 4G/5G**
5. Thử điều khiển LED, quạt, cửa

✅ **Nếu hoạt động → Thành công!**

---

## ⚠️ Lưu ý quan trọng

### Render.com Free Tier:
- ✅ 750 giờ/tháng (đủ chạy 24/7)
- ⚠️ Server "ngủ" sau 15 phút không hoạt động
- ⚠️ Lần đầu gửi request mất ~30s để "đánh thức"
- **Giải pháp**: Dùng cron job ping mỗi 10 phút

### HiveMQ Free Tier:
- ✅ 100 kết nối đồng thời
- ✅ Không giới hạn messages
- ⚠️ Cluster ngủ sau 30 ngày không dùng

---

## 🚀 Nhanh hơn: Dùng Ngrok (Test tạm thời)

Nếu chỉ cần test nhanh, không cần deploy:

1. Tải Ngrok: https://ngrok.com/download
2. Chạy local server như bình thường
3. Mở terminal:
```bash
ngrok http 3000
```
4. Copy URL: `https://abc123.ngrok.io`
5. Sửa Flutter app dùng URL này

**Nhược điểm**: URL thay đổi mỗi lần restart, chỉ dùng để test.

---

## 📋 Checklist Deploy

- [ ] Đăng ký HiveMQ Cloud
- [ ] Tạo cluster và lấy credentials
- [ ] Đăng ký Render.com
- [ ] Push code lên GitHub
- [ ] Deploy Node.js server trên Render
- [ ] Cập nhật ESP8266 với HiveMQ credentials
- [ ] Cập nhật Flutter app với Render URL
- [ ] Test từ xa (4G/5G)

---

Bạn muốn tôi tạo file config và script tự động hóa quá trình này không?
