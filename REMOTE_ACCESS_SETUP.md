# 🌐 Remote Access Setup - Điều khiển từ xa

## 🎯 Mục tiêu
Điều khiển thiết bị IoT từ bất kì đâu qua Internet (4G/5G/WiFi khác)

## 📦 Các dịch vụ cần dùng (100% MIỄN PHÍ)

| Dịch vụ | Mục đích | Free Tier | Link |
|---------|----------|-----------|------|
| **HiveMQ Cloud** | MQTT Broker | 100 connections | https://www.hivemq.com/mqtt-cloud-broker/ |
| **Render.com** | Host Node.js Server | 750h/month | https://render.com |
| **GitHub** | Source code hosting | Unlimited | https://github.com |

---

## ⚡ Quick Start (30 phút)

### 1️⃣ Setup HiveMQ Cloud
```
1. Đăng ký tại: https://console.hivemq.cloud/
2. Create new cluster (chọn region Singapore)
3. Lưu credentials:
   - Host: abc123.s1.eu.hivemq.cloud
   - Port: 8883
   - Username: your-username
   - Password: your-password
```

### 2️⃣ Deploy Node.js lên Render
```
1. Push code lên GitHub
2. Đăng ký Render.com với GitHub
3. New Web Service → Connect IoT_BTL repo
4. Root: NodeJS_Server
5. Start: node server_mqtt.js
6. Add env vars (xem DEPLOY_STEPS.md)
```

### 3️⃣ Update ESP8266
```cpp
// ESP8266_Master.ino
#include <WiFiClientSecure.h>

WiFiClientSecure espClient;  // Thay WiFiClient
PubSubClient client(espClient);

const char* mqtt_server = "your-cluster.hivemq.cloud";
const int mqtt_port = 8883;
const char* mqtt_user = "your-username";
const char* mqtt_pass = "your-password";

void setup() {
  // ... existing code ...
  espClient.setInsecure();  // Add this line
  client.setServer(mqtt_server, mqtt_port);
}

void reconnectMQTT() {
  // Update connect() call
  client.connect("ESP8266", mqtt_user, mqtt_pass);
}
```

### 4️⃣ Update Flutter App
```dart
// lib/services/iot_service.dart
IoTService({
  this.baseUrl = 'https://your-app.onrender.com',
  this.wsUrl = 'wss://your-app.onrender.com',
});
```

### 5️⃣ Test
```
✅ Upload ESP8266
✅ Chạy Flutter app trên 4G (không dùng WiFi nhà)
✅ Thử bật/tắt LED, quạt, cửa
✅ Kiểm tra real-time updates
```

---

## 📁 Files quan trọng

```
IoT_BTL/
├── DEPLOY_CLOUD_GUIDE.md       ← Hướng dẫn chi tiết
├── NodeJS_Server/
│   ├── server_mqtt.js          ← Server đã sửa (support env vars)
│   ├── config.js               ← Config helper (NEW)
│   ├── .env.example            ← Template env variables
│   ├── DEPLOY_STEPS.md         ← Các bước deploy
│   └── render.yaml             ← Render config
└── ESP8266_Master/
    └── CLOUD_CONFIG.ino        ← Template config cho ESP8266
```

---

## 🔧 Troubleshooting

### ESP8266 không kết nối được HiveMQ
```
❌ Error: failed, rc=-2
✅ Fix: Kiểm tra username/password, đảm bảo cluster đang active
```

### Render server "ngủ" sau 15 phút
```
⚠️  Free tier của Render tắt server khi không dùng
✅ Giải pháp: Setup cron job ping server mỗi 10 phút
   Hoặc upgrade lên $7/month
```

### Flutter app không kết nối WebSocket
```
❌ Error: Connection refused
✅ Fix: 
   1. Kiểm tra URL (phải là wss:// không phải ws://)
   2. Đợi server "thức dậy" (~30s lần đầu)
   3. Check Render logs xem có lỗi gì
```

### ESP8266 mất kết nối liên tục
```
⚠️  Nguyên nhân: Mạng không ổn định
✅ Fix: Thêm reconnect logic trong loop():
   if (!client.connected()) {
     reconnectMQTT();
   }
```

---

## 💡 Tips

### Tiết kiệm chi phí
- ✅ Dùng Free tier của HiveMQ + Render
- ✅ Server chỉ chạy khi cần (Render auto-sleep)
- ⚠️ Nếu cần 24/7 không ngủ → Upgrade Render ($7/month)

### Bảo mật
- 🔒 HiveMQ dùng TLS encryption (port 8883)
- 🔒 Thêm authentication cho Flutter app
- 🔒 Đổi MQTT username/password định kỳ

### Performance
- ⚡ Chọn HiveMQ region gần VN (Singapore)
- ⚡ Render region: Singapore hoặc US West
- ⚡ Giảm polling frequency nếu lag

---

## 📊 So sánh Local vs Cloud

| Tính năng | Local (hiện tại) | Cloud (sau khi deploy) |
|-----------|------------------|------------------------|
| Điều khiển từ xa | ❌ Chỉ trong nhà | ✅ Mọi nơi |
| Chi phí | $0 | $0 (free tier) |
| Setup | Dễ | Hơi phức tạp |
| Độ tin cậy | Phụ thuộc WiFi nhà | Phụ thuộc Internet |
| Latency | <50ms | 100-300ms |
| Bảo mật | ⚠️ Local network | ✅ TLS encryption |

---

## ✅ Checklist Deploy

- [ ] Tạo HiveMQ Cloud cluster
- [ ] Lấy credentials (host, username, password)
- [ ] Push code lên GitHub
- [ ] Deploy Render.com
- [ ] Thêm env variables trên Render
- [ ] Đợi build xong (~5 phút)
- [ ] Copy Render URL
- [ ] Update ESP8266 với HiveMQ credentials
- [ ] Upload ESP8266 firmware
- [ ] Update Flutter app với Render URL
- [ ] Build Flutter app
- [ ] Test trên 4G/5G
- [ ] Kiểm tra real-time updates
- [ ] Test các chức năng: LED, Fan, Door, Security

---

## 🆘 Cần trợ giúp?

1. Check server logs trên Render Dashboard
2. Xem ESP8266 Serial Monitor
3. Dùng MQTT Explorer để test HiveMQ
4. Xem Flutter console logs

---

**Bạn đã sẵn sàng deploy chưa? Hãy làm theo DEPLOY_STEPS.md! 🚀**
