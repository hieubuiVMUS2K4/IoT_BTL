# 🚀 HƯỚNG DẪN CHUYỂN ĐỔI SANG MQTT - ĐẦY ĐỦ

## 📝 TÓM TẮT KIẾN TRÚC MỚI

```
Arduino Uno 1/2 
    ↓ (I2C)
ESP8266 (MQTT Client)
    ↓ (MQTT)
Mosquitto Broker (192.168.0.110:1883)
    ↓ (MQTT)
Node.js Server (MQTT Bridge)
    ↓ (WebSocket)
Flutter App (KHÔNG ĐỔI)
```

## 🔧 BƯỚC 1: CÀI ĐẶT MOSQUITTO BROKER

### Windows:
1. Download: https://mosquitto.org/download/
2. Chọn: `mosquitto-2.x.x-install-windows-x64.exe`
3. Cài vào: `C:\Program Files\mosquitto`

### Chạy Mosquitto:
```powershell
cd "C:\Program Files\mosquitto"
.\mosquitto.exe -v
```

Hoặc cài service:
```powershell
# Run as Administrator
sc create mosquitto binPath= "C:\Program Files\mosquitto\mosquitto.exe" start= auto
net start mosquitto
```

### Kiểm tra:
```powershell
netstat -an | findstr 1883
# Phải thấy: 0.0.0.0:1883
```

---

## 🔧 BƯỚC 2: CÀI ĐẶT THƯ VIỆN ESP8266

### Arduino IDE:
1. Mở **Tools > Manage Libraries**
2. Tìm **PubSubClient** by Nick O'Leary
3. Click **Install**

### Hoặc dùng lệnh:
```bash
arduino-cli lib install PubSubClient
```

---

## 🔧 BƯỚC 3: UPLOAD CODE MỚI

### ESP8266:
1. Mở file: `ESP8266_Master_MQTT.ino`
2. Sửa IP: `const char* mqtt_server = "192.168.0.110";`
3. Upload lên ESP8266
4. Mở Serial Monitor (115200 baud)
5. Xem log:
```
✓ WiFi connected!
✓ Connected to MQTT Broker
✓ Subscribed to control topics
```

### Arduino Uno 1 & 2:
- **KHÔNG CẦN** thay đổi code
- Giữ nguyên code hiện tại

---

## 🔧 BƯỚC 4: CÀI ĐẶT SERVER MỚI

### Cài thư viện MQTT:
```powershell
cd C:\Users\hieuu\OneDrive\Desktop\btlIOT\NodeJS_Server
npm install mqtt@5.3.0
```

### Chạy server mới:
```powershell
node server_mqtt.js
```

### Kiểm tra log:
```
=== IoT MQTT Bridge Server ===
HTTP Server: http://localhost:3000
WebSocket Server: ws://localhost:3001
MQTT Broker: mqtt://192.168.0.110:1883
✓ Connected to MQTT Broker
✓ Subscribed to iot/sensors/data
```

---

## 🔧 BƯỚC 5: FLUTTER APP

**KHÔNG CẦN THAY ĐỔI!** 

Flutter app vẫn dùng WebSocket kết nối đến server. Server làm bridge giữa MQTT và WebSocket.

Chỉ cần đảm bảo `iot_service.dart` vẫn dùng đúng IP:
```dart
static const String baseUrl = 'http://192.168.0.110:3000';
static const String wsUrl = 'ws://192.168.0.110:3001';
```

---

## ✅ BƯỚC 6: KIỂM TRA HỆ THỐNG

### 1. Kiểm tra Mosquitto:
```powershell
# Terminal 1
mosquitto -v
```

### 2. Test MQTT với mosquitto_sub:
```powershell
# Terminal 2 - Subscribe để xem data từ ESP8266
cd "C:\Program Files\mosquitto"
.\mosquitto_sub.exe -h localhost -t "iot/sensors/#" -v
```

### 3. Chạy Node.js Server:
```powershell
# Terminal 3
cd C:\Users\hieuu\OneDrive\Desktop\btlIOT\NodeJS_Server
node server_mqtt.js
```

### 4. ESP8266 Serial Monitor:
Phải thấy:
```
📤 Published: {"pir":false,"led1":false,...}
```

### 5. Server Log:
Phải thấy:
```
📥 Data from ESP8266: { pir: false, led1: false, ... }
```

### 6. Flutter App:
- Chạy app như bình thường
- Dữ liệu phải cập nhật real-time
- Các nút điều khiển phải hoạt động

---

## 🔍 DEBUG MQTT

### Test publish từ command line:
```powershell
cd "C:\Program Files\mosquitto"

# Bật quạt
.\mosquitto_pub.exe -h localhost -t "iot/control/fan" -m "on"

# Tắt LED2
.\mosquitto_pub.exe -h localhost -t "iot/control/led2" -m "off"

# Mở cửa
.\mosquitto_pub.exe -h localhost -t "iot/control/door" -m "open"
```

### ESP8266 phải nhận được lệnh:
```
📥 MQTT Received [iot/control/fan]: on
→ Slave1 cmd: 0x07
```

---

## 📊 MQTT TOPICS

### ESP8266 Publish (mỗi 2 giây):
- `iot/sensors/data` - JSON với tất cả sensor data

### ESP8266 Subscribe (nhận lệnh):
- `iot/control/led2` - Payload: `on`, `off`, `toggle`
- `iot/control/fan` - Payload: `on`, `off`, `toggle`
- `iot/control/door` - Payload: `open`, `close`, `toggle`

---

## ⚠️ TROUBLESHOOTING

### ESP8266 không kết nối MQTT:
- Kiểm tra Mosquitto đã chạy: `netstat -an | findstr 1883`
- Kiểm tra IP đúng: `mqtt_server = "192.168.0.110"`
- Kiểm tra firewall Windows cho phép port 1883

### Server không nhận data từ MQTT:
- Kiểm tra server log: `✓ Subscribed to iot/sensors/data`
- Test bằng `mosquitto_pub` xem server nhận được không

### Flutter không cập nhật:
- Kiểm tra WebSocket vẫn kết nối
- Server phải broadcast qua WebSocket khi nhận MQTT

### Quạt vẫn không hoạt động:
- Vấn đề **KHÔNG LIÊN QUAN** đến MQTT
- Vấn đề là **I2C giữa ESP8266 và Arduino**
- Kiểm tra lại dây SDA/SCL/GND

---

## 🎯 LỢI ÍCH CỦA MQTT

✅ **Reliable**: QoS levels đảm bảo message đến đích
✅ **Scalable**: Dễ thêm nhiều client
✅ **Decoupled**: ESP8266 và Server không phụ thuộc nhau
✅ **Standard**: Giao thức chuẩn IoT
✅ **Lightweight**: Tiết kiệm băng thông hơn HTTP

---

## 📦 FILE MỚI ĐÃ TẠO

1. `ESP8266_Master_MQTT.ino` - ESP8266 code mới với MQTT
2. `server_mqtt.js` - Node.js server với MQTT bridge
3. `MQTT_SETUP.md` - Hướng dẫn cài đặt
4. `DEPLOY_GUIDE.md` - File này

**Arduino Uno 1/2**: GIỮ NGUYÊN code cũ
**Flutter App**: GIỮ NGUYÊN, không cần sửa

---

## 🚀 TRIỂN KHAI NHANH

```powershell
# 1. Start Mosquitto
net start mosquitto

# 2. Start Server
cd C:\Users\hieuu\OneDrive\Desktop\btlIOT\NodeJS_Server
npm install
node server_mqtt.js

# 3. Upload ESP8266
# Arduino IDE > Upload ESP8266_Master_MQTT.ino

# 4. Run Flutter
cd C:\Users\hieuu\OneDrive\Desktop\btlIOT\FlutterApp
flutter run -d windows
```

Hệ thống sẵn sàng! 🎉
