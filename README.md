# 🏠 HỆ THỐNG IOT SMART HOME - MQTT VERSION
## ESP8266 + 2 Arduino Uno + Flutter Mobile App

**Đồ án IoT - Hệ thống nhà thông minh đa nền tảng với MQTT Protocol**

---

## 📋 TỔNG QUAN DỰ ÁN

### **Mô tả hệ thống**
Hệ thống IoT Smart Home là một giải pháp nhà thông minh hoàn chỉnh, tích hợp phần cứng (Arduino, ESP8266) và phần mềm đa nền tảng (Web Dashboard, Mobile App), cho phép:
- **Giám sát** nhiệt độ, độ ẩm, chuyển động, khoảng cách theo thời gian thực
- **Điều khiển từ xa** đèn LED, cửa servo qua WiFi
- **Tự động hóa** mở cửa bằng RFID và cảm biến khoảng cách
- **Quản lý người dùng** với xác thực và phân quyền
- **Đa nền tảng** hỗ trợ Web, Windows, Android

### **Kiến trúc tổng thể - PURE MQTT**
```
┌──────────────────────────────────────────────────────────────────┐
│                        PRESENTATION LAYER                        │
├──────────────────────┬───────────────────────┬───────────────────┤
│   Web Dashboard      │   Flutter Mobile App  │  Windows Desktop  │
│   (HTML/CSS/JS)      │   (Dart/Flutter)      │  (Flutter)        │
└──────────┬───────────┴───────────┬───────────┴───────────────────┘
             │ MQTT Subscribe        │ MQTT Subscribe
             ▼                       ▼
┌──────────────────────────────────────────────────────────────────┐
│                        APPLICATION LAYER                         │
│                Node.js MQTT Broker + REST API Server             │
│  - Aedes MQTT Broker (port 1883)                                 │
│  - Express.js (minimal HTTP endpoints)                           │
│  - MQTT Client (sensor/command handling)                         │
│  - JSON Database (User authentication)                           │
│  - Real-time MQTT broadcasting                                    │
└──────────────────────┬──────────────────────────────────────────┘
                         │ MQTT Publish/Subscribe (WiFi)
                         ▼
┌──────────────────────────────────────────────────────────────────┐
│                      COMMUNICATION LAYER                         │
│                    ESP8266 WiFi Master (I2C+MQTT)                │
│  - WiFi STA mode (2.4GHz)                                        │
│  - I2C Master coordinator                                        │
│  - MQTT Publisher (sensor data)                                  │
│  - MQTT Subscriber (commands)                                    │
│  - Event-driven command processing                               │
└────────┬──────────────────────────────┬─────────────────────────┘
          │ I2C Protocol                 │ I2C Protocol
          ▼                              ▼
┌────────────────────────┐    ┌────────────────────────┐
│    HARDWARE LAYER      │    │    HARDWARE LAYER      │
│   Arduino Uno 1        │    │   Arduino Uno 2        │
│   (I2C Slave 0x08)     │    │   (I2C Slave 0x09)     │
├────────────────────────┤    ├────────────────────────┤
│ • PIR Motion Sensor    │    │ • RFID RC522           │
│ • DHT11/22 Temp/Hum    │    │ • HC-SR04 Ultrasonic   │
│ • LED 1 (PIR Auto)     │    │ • Servo Motor (Door)   │
│ • LED 2 (Manual)       │    │ • Button Open/Close    │
│ • Button Control       │    │                        │
└────────────────────────┘    └────────────────────────┘
```

---

## 🎯 TÍNH NĂNG CHÍNH

### **1. Giám sát môi trường**
- ✅ **Nhiệt độ & độ ẩm**: DHT11/DHT22 cập nhật mỗi 2 giây
- ✅ **Phát hiện chuyển động**: PIR sensor với timeout 7 giây
- ✅ **Khoảng cách**: HC-SR04 (0-400cm, độ chính xác ±1cm)
- ✅ **Trạng thái thiết bị**: LED, cửa, RFID realtime

### **2. Điều khiển thông minh**
- ✅ **LED 1 (Auto)**: Tự động bật khi phát hiện chuyển động (PIR)
- ✅ **LED 2 (Manual)**: Điều khiển từ xa (On/Off/Toggle)
- ✅ **Cửa servo**: Mở/đóng từ xa hoặc tự động
- ✅ **Chế độ ưu tiên**: Manual > Auto-close > RFID/HC-SR04

### **3. Tự động hóa**
- 🔐 **RFID Access**: Tự động mở cửa khi quẹt thẻ hợp lệ
- 🚶 **Auto-open**: Mở cửa khi phát hiện người < 10cm
- ⏱️ **Auto-close**: Đóng cửa sau 5 giây (tất cả phương thức)
- 💡 **PIR Auto-light**: LED bật tự động khi có người

### **4. Flutter Mobile App**
- 📱 **Đa nền tảng**: Android, iOS, Windows Desktop
- 🔐 **Xác thực người dùng**: Login/Register với JSON database
- 🎨 **Material Design 3**: Giao diện hiện đại, mượt mà
- ⚡ **Real-time MQTT**: Tự động cập nhật sensor qua MQTT
- 📊 **Dashboard**: Hiển thị trực quan tất cả sensor
- 🎮 **Control Panel**: Điều khiển LED, cửa qua MQTT publish

### **5. Web Dashboard**
- 🌐 **Responsive design**: Tương thích mọi thiết bị
- 📊 **Biểu đồ realtime**: Chart.js visualization
- 🔌 **MQTT Updates**: Cập nhật real-time qua MQTT subscriptions
- 🎨 **UI/UX**: Clean, professional design

---

## 🔌 SƠ ĐỒ KẾT NỐI CHI TIẾT

### **I2C Bus Architecture**
```
                     ┌─────────────────┐
                     │   ESP8266       │
                     │   (Master I2C)  │
                     │   3.3V Logic    │
                     └────┬───────┬────┘
                          │       │
                    SDA   │       │   SCL
                  (GPIO4) │       │ (GPIO5)
                          │       │
            ┌─────────────┴───────┴─────────────┐
            │                                   │
      4.7kΩ pull-up to 3.3V            4.7kΩ pull-up to 3.3V
            │                                   │
      ──────┴──────────────────────────────────┴──────
      │                                               │
      │                                               │
   ┌──▼───────────────┐                   ┌──────────▼──┐
   │  Arduino Uno 1   │                   │ Arduino Uno 2│
   │  I2C Address 8   │                   │ I2C Address 9│
   │  5V Logic        │                   │ 5V Logic     │
   │  A4 (SDA)        │                   │ A4 (SDA)     │
   │  A5 (SCL)        │                   │ A5 (SCL)     │
   └──────────────────┘                   └──────────────┘
   
   ⚠️ Chú ý: Cần Level Shifter hoặc Pull-up về 3.3V
```

### **Arduino Uno 1 - Sơ đồ kết nối**
```
┌─────────────────────────────────────────────┐
│           Arduino Uno 1 (Slave 8)           │
├─────────────────────────────────────────────┤
│  Chân      │  Linh kiện         │  Mô tả    │
├────────────┼────────────────────┼───────────┤
│  D2        │  PIR OUT           │  Digital  │
│  D3        │  DHT DATA          │  Digital  │
│  D10       │  LED 2 (-)         │  PWM      │
│  D11       │  LED 1 (-)         │  PWM      │
│  D12       │  Button 1          │  Pull-up  │
│  A4        │  I2C SDA           │  I2C      │
│  A5        │  I2C SCL           │  I2C      │
│  5V        │  VCC sensors       │  Power    │
│  GND       │  GND common        │  Ground   │
└────────────┴────────────────────┴───────────┘

Lưu ý PIR:
- VCC → 5V
- GND → GND
- OUT → D2
- Logic: LOW = có người (đã đảo ngược)
        HIGH = không có người

Lưu ý DHT11/22:
- VCC → 5V
- GND → GND
- DATA → D3
- Pull-up 10kΩ từ DATA lên VCC (tùy chọn)
```

### **Arduino Uno 2 - Sơ đồ kết nối**
```
┌──────────────────────────────────────────────────┐
│            Arduino Uno 2 (Slave 9)               │
├──────────────────────────────────────────────────┤
│  Chân      │  Linh kiện           │  Mô tả       │
├────────────┼──────────────────────┼──────────────┤
│  D4        │  HC-SR04 TRIG        │  Digital     │
│  D5        │  HC-SR04 ECHO        │  Digital     │
│  D9        │  RFID RST            │  SPI         │
│  D10       │  RFID SDA (SS)       │  SPI         │
│  D11       │  RFID MOSI           │  SPI         │
│  D12       │  RFID MISO           │  SPI         │
│  D13       │  RFID SCK            │  SPI         │
│  A0        │  Button Open         │  Pull-up     │
│  A1        │  Button Close        │  Pull-up     │
│  A2        │  Servo Signal        │  PWM         │
│  A4        │  I2C SDA             │  I2C         │
│  A5        │  I2C SCL             │  I2C         │
│  5V        │  VCC sensors         │  Power       │
│  GND       │  GND common          │  Ground      │
└────────────┴──────────────────────┴──────────────┘

⚠️ QUAN TRỌNG - Nguồn Servo:
- Servo cần nguồn riêng 5V/1A (không dùng từ Arduino)
- Nối GND servo với GND Arduino (common ground)
- Signal servo → A2

⚠️ RFID RC522:
- VCC → 3.3V (KHÔNG DÙNG 5V!)
- RST → D9
- GND → GND
- IRQ → không kết nối
- MISO → D12
- MOSI → D11
- SCK → D13
- SDA (SS) → D10
```

### **ESP8266 NodeMCU - Sơ đồ kết nối**
```
┌─────────────────────────────────────────────┐
│         ESP8266 NodeMCU (Master I2C)        │
├─────────────────────────────────────────────┤
│  Chân      │  Kết nối          │  Mô tả     │
├────────────┼───────────────────┼────────────┤
│  D1 (GPIO5)│  I2C SCL          │  I2C Clock │
│  D2 (GPIO4)│  I2C SDA          │  I2C Data  │
│  GND       │  GND Arduino 1&2  │  Ground    │
│  3V3       │  Pull-up I2C      │  Reference │
└────────────┴───────────────────┴────────────┘

WiFi Configuration:
- Mode: Station (STA)
- Frequency: 2.4GHz only
- IP: DHCP (auto)
```

---

## 📚 DANH SÁCH LINH KIỆN

### **Phần cứng chính**
| STT | Linh kiện | Số lượng | Ghi chú |
|-----|-----------|----------|---------|
| 1 | ESP8266 NodeMCU | 1 | WiFi Master |
| 2 | Arduino Uno R3 | 2 | I2C Slaves |
| 3 | PIR HC-SR501 | 1 | Motion sensor |
| 4 | DHT11/DHT22 | 1 | Temp & Humidity |
| 5 | RFID RC522 | 1 | Card reader |
| 6 | HC-SR04 | 1 | Ultrasonic sensor |
| 7 | SG90 Servo Motor | 1 | Door control |
| 8 | LED 5mm | 2 | Status indicators |
| 9 | Push Button | 3 | Manual control |
| 10 | Điện trở 220Ω | 2 | LED current limit |
| 11 | Điện trở 4.7kΩ | 2 | I2C pull-up |
| 12 | Breadboard | 2-3 | Prototyping |
| 13 | Dây jumper | 30+ | Connections |
| 14 | Nguồn 5V/2A | 1 | Power supply |

### **Linh kiện bổ sung (khuyên dùng)**
- Level Shifter 3.3V-5V (cho I2C)
- Tụ điện 100µF (lọc nguồn servo)
- Thẻ RFID Mifare 13.56MHz (ít nhất 1 thẻ)

---

## 💻 CÀI ĐẶT PHẦN MỀM

### **1. Arduino IDE**
```bash
# Tải Arduino IDE 2.x từ:
https://www.arduino.cc/en/software

# Hoặc dùng Arduino IDE 1.8.x (legacy)
```

**Cài đặt Board ESP8266:**
1. File → Preferences
2. Additional Board Manager URLs:
   ```
   http://arduino.esp8266.com/stable/package_esp8266com_index.json
   ```
3. Tools → Board → Boards Manager
4. Tìm "ESP8266" → Install

**Thư viện cần thiết:**
```
Arduino Uno 1:
├── DHT sensor library (Adafruit) v1.4.x
├── Adafruit Unified Sensor v1.1.x
└── Wire (built-in)

Arduino Uno 2:
├── MFRC522 (GithubCommunity) v1.4.x
├── Servo (built-in)
├── SPI (built-in)
└── Wire (built-in)

ESP8266:
├── ESP8266WiFi (built-in)
├── ESP8266HTTPClient (built-in)
├── ArduinoJson v6.21.x (Benoit Blanchon)
└── Wire (built-in)
```

### **2. Node.js & NPM**
```bash
# Tải Node.js LTS từ:
https://nodejs.org/

# Kiểm tra cài đặt:
node --version  # v18.x hoặc mới hơn
npm --version   # v9.x hoặc mới hơn
```

### **3. Flutter SDK**
```bash
# Tải Flutter từ:
https://flutter.dev/docs/get-started/install

# Giải nén và thêm vào PATH

# Kiểm tra:
flutter doctor

# Cài đặt dependencies:
flutter pub get
```

---

## ⚙️ HƯỚNG DẪN CÀI ĐẶT & CHẠY

### **BƯỚC 1: Chuẩn bị phần cứng**

1. **Kết nối I2C Bus:**
   - Kết nối SDA/SCL giữa ESP8266 và 2 Arduino
   - Thêm pull-up resistor 4.7kΩ từ SDA/SCL lên 3.3V
   - Nối GND chung cho cả 3 board

2. **Arduino Uno 1:**
   - Kết nối PIR, DHT, LED, Button theo sơ đồ
   - Kiểm tra nguồn 5V cho sensors

3. **Arduino Uno 2:**
   - Kết nối RFID (3.3V!), HC-SR04, Servo, Button
   - Chuẩn bị nguồn riêng cho Servo (5V/1A)
   - Nối GND chung

### **BƯỚC 2: Upload code Arduino**

**Arduino Uno 1:**
```cpp
1. Mở Arduino_Uno_1_Slave/Arduino_Uno_1_Slave.ino
2. Kiểm tra loại DHT:
   #define DHTTYPE DHT11  // hoặc DHT22
3. Tools → Board: "Arduino Uno"
4. Tools → Port: COMx (Windows) hoặc /dev/ttyUSBx (Linux)
5. Upload
6. Mở Serial Monitor (115200 baud) để kiểm tra
```

**Arduino Uno 2:**
```cpp
1. Mở Arduino_Uno_2_Slave/Arduino_Uno_2_Slave.ino

2. Tìm UID thẻ RFID:
   - Upload code mẫu (không cần sửa UID trước)
   - Mở Serial Monitor
   - Quẹt thẻ RFID
   - Copy UID (ví dụ: 96 97 03 5F)

3. Cấu hình UID hợp lệ (dòng 47):
   byte validCard[4] = {0x96, 0x97, 0x03, 0x5F};
   // Thay bằng UID của bạn

4. Upload lại
5. Kiểm tra Serial Monitor (115200 baud)
```

**ESP8266:**
```cpp
1. Mở ESP8266_Master/ESP8266_Master.ino

2. Cấu hình WiFi (dòng 17-18):
   const char* ssid = "TEN_WIFI";
   const char* password = "MAT_KHAU";

3. Tìm IP máy tính:
   Windows: ipconfig
   Linux: ifconfig
   macOS: ifconfig

4. Cấu hình MQTT Broker IP (dòng 22):
   const char* mqttServer = "192.168.1.100";  // IP của PC chạy MQTT broker

5. Tools → Board: "NodeMCU 1.0 (ESP-12E Module)"
6. Tools → Port: COMx
7. Upload
8. Serial Monitor (115200 baud):
   - Kiểm tra kết nối WiFi
   - Kiểm tra kết nối MQTT broker
   - Xem data publish lên MQTT topics
```

### **BƯỚC 3: Chạy Node.js Server**

```bash
# 1. Di chuyển vào thư mục server
cd NodeJS_Server

# 2. Cài đặt dependencies (chỉ lần đầu)
npm install

# 3. Cấu hình (tùy chọn)
# Chỉnh sửa server.js nếu muốn đổi port

# 4. Chạy server
npm start

# Hoặc chế độ development (auto-reload):
npm run dev

# 5. Mở browser
# Web Dashboard: http://localhost:3000
# WebSocket: ws://localhost:3001
```

**Output mong đợi:**
```
==============================================
IoT Smart Home Server Started (MQTT + HTTP)
==============================================
HTTP Server: http://localhost:3000
WebSocket Server: ws://localhost:3001
MQTT Broker: mqtt://localhost:1883
==============================================
Waiting for connections...

MQTT Broker listening on port 1883
Connected to MQTT broker
Subscribed to sensor topics
Subscribed to status topics

WebSocket client connected
MQTT received [/iot/smarthome/sensors/temperature]: {"temperature":28.5,"humidity":65.2,"timestamp":1640995200000}
MQTT received [/iot/smarthome/sensors/motion]: {"motion":false,"timestamp":1640995200000}
```

### **BƯỚC 4: Chạy Flutter App**

```bash
# 1. Di chuyển vào thư mục app
cd FlutterApp

# 2. Cài đặt dependencies
flutter pub get

# 3. Kiểm tra devices
flutter devices

# 4a. Chạy trên Chrome (web)
flutter run -d chrome

# 4b. Chạy trên Windows (desktop)
flutter run -d windows

# 4c. Chạy trên Android (cần device/emulator)
flutter run -d <device_id>

# 5. Build release (production):
flutter build windows --release
flutter build apk --release
```

**Đăng nhập mặc định:**
- Username: `admin`
- Password: `admin123`

**Cấu hình Server IP trong Flutter:**
```dart
// File: lib/services/iot_service.dart
IoTService({
  this.baseUrl = 'http://192.168.1.100:3000',  // Đổi IP cho HTTP API
  this.mqttUrl = '192.168.1.100', // Đổi IP cho MQTT broker
  this.mqttPort = 1883,
});
```

---

## 📡 GIAO THỨC TRUYỀN THÔNG

### **1. MQTT Protocol**

**ESP8266 → Node.js Server (Sensor Data):**
```json
// Topic: /iot/smarthome/sensors/temperature
{
  "temperature": 28.5,
  "humidity": 65.2,
  "timestamp": 1640995200000
}

// Topic: /iot/smarthome/sensors/motion
{
  "motion": true,
  "timestamp": 1640995200000
}

// Topic: /iot/smarthome/sensors/door
{
  "door": false,
  "autoOpen": true,
  "rfid": false,
  "timestamp": 1640995200000
}

// Topic: /iot/smarthome/sensors/distance
{
  "distance": 8.3,
  "timestamp": 1640995200000
}
```

**Node.js Server → ESP8266 (Commands):**
```json
// Topic: /iot/smarthome/commands/led2
{
  "action": "on",
  "timestamp": 1640995200000
}

// Topic: /iot/smarthome/commands/door
{
  "action": "open",
  "timestamp": 1640995200000
}
```

**MQTT Broker Configuration:**
- **Port**: 1883 (default MQTT port)
- **QoS**: 1 (at least once delivery)
- **Retained Messages**: Enabled for sensor data
- **Clean Session**: false (persistent connection)

### **2. I2C Protocol**

**Request từ ESP8266 → Arduino Uno 1 (Address 0x08):**
```
Wire.requestFrom(8, 7);  // Đọc 7 bytes

Frame cấu trúc:
┌────┬────┬────┬─────┬─────┬─────┬─────┐
│ B0 │ B1 │ B2 │ B3  │ B4  │ B5  │ B6  │
├────┼────┼────┼─────┼─────┼─────┼─────┤
│PIR │LED1│LED2│Temp │Temp │Hum  │Hum  │
│    │    │    │ Hi  │ Lo  │ Hi  │ Lo  │
└────┴────┴────┴─────┴─────┴─────┴─────┘

- B0: PIR state (0=no motion, 1=motion detected)
- B1: LED 1 state (0=OFF, 1=ON)
- B2: LED 2 state (0=OFF, 1=ON)
- B3-B4: Temperature × 10 (int16, big-endian)
          Ví dụ: 28.5°C → 285 → 0x011D → B3=0x01, B4=0x1D
- B5-B6: Humidity × 10 (int16, big-endian)
          Ví dụ: 65.2% → 652 → 0x028C → B5=0x02, B6=0x8C
```

**Request từ ESP8266 → Arduino Uno 2 (Address 0x09):**
```
Wire.requestFrom(9, 5);  // Đọc 5 bytes

Frame cấu trúc:
┌─────┬──────┬──────┬──────┬──────┐
│ B0  │ B1   │ B2   │ B3   │ B4   │
├─────┼──────┼──────┼──────┼──────┤
│Door │Auto  │RFID  │Dist  │Dist  │
│     │Open  │      │ Hi   │ Lo   │
└─────┴──────┴──────┴──────┴──────┘

- B0: Door state (0=closed, 1=open)
- B1: Auto-open active (0=no, 1=yes)
- B2: RFID access (0=no, 1=valid card detected)
- B3-B4: Distance × 10 (int16, big-endian)
          Ví dụ: 12.5cm → 125 → 0x007D → B3=0x00, B4=0x7D
```

**Command từ ESP8266 → Arduino:**
```
// Gửi đến Arduino Uno 1 (Address 8):
Wire.beginTransmission(8);
Wire.write(command);
Wire.endTransmission();

Commands:
- 0x01: Bật LED 2
- 0x02: Tắt LED 2
- 0x03: Toggle LED 2

// Gửi đến Arduino Uno 2 (Address 9):
Wire.beginTransmission(9);
Wire.write(command);
Wire.endTransmission();

Commands:
- 0x10: Mở cửa
- 0x11: Đóng cửa  
- 0x12: Toggle cửa
```

### **2. HTTP REST API**

**ESP8266 → Node.js Server:**
```http
POST /api/data HTTP/1.1
Host: 192.168.1.100:3000
Content-Type: application/json

{
  "pir": false,
  "led1": false,
  "led2": false,
  "temperature": 28.5,
  "humidity": 65.2,
  "door": false,
  "autoOpen": false,
  "rfid": false,
  "distance": 125.4,
  "timestamp": 1234567890
}

Response:
{
  "status": "success",
  "message": "Data received"
}
```

**Client (Web/App) → Node.js Server:**
```http
# Lấy trạng thái hiện tại
GET /api/status HTTP/1.1

Response:
{
  "pir": false,
  "led1": false,
  "led2": true,
  "temperature": 28.5,
  "humidity": 65.2,
  "door": true,
  "autoOpen": false,
  "rfid": true,
  "distance": 8.3,
  "lastUpdate": "2025-11-17T10:30:00.000Z"
}

# Gửi lệnh điều khiển
POST /api/control HTTP/1.1
Content-Type: application/json

{
  "device": "led2",     // hoặc "door"
  "action": "on"        // on/off/toggle, open/close/toggle
}

Response:
{
  "status": "success",
  "message": "Command on for led2 queued"
}
```

**ESP8266 lấy lệnh:**
```http
GET /api/commands HTTP/1.1

Response (nếu có lệnh):
{
  "led2": "on",
  "door": "open"
}

Response (không có lệnh):
{}
```

### **3. WebSocket Protocol**

**Connection:**
```javascript
ws://192.168.1.100:3001

// Client connect
const ws = new WebSocket('ws://192.168.1.100:3001');

// Server gửi init data khi client kết nối
{
  "type": "init",
  "data": {
    "pir": false,
    "led1": false,
    // ... tất cả sensor data
  }
}

// Server broadcast update khi nhận data từ ESP8266
{
  "type": "update",
  "data": {
    "pir": true,
    "temperature": 29.0,
    // ... data thay đổi
  }
}
```

---

## 🎮 CHỨC NĂNG CHI TIẾT

### **Arduino Uno 1 - Sensor & LED Control**

**PIR Motion Sensor (Đảo ngược logic):**
```cpp
✅ Logic: LOW = có người → Bật LED 1
         HIGH = không có người → Tắt LED 1 sau 7s
✅ Debounce: 100ms chống nhiễu
✅ Timeout: 7 giây không chuyển động → OFF
✅ Auto-reset: Timer reset khi còn chuyển động
✅ LED control: Hoàn toàn tự động, không manual
```

**DHT Temperature & Humidity:**
```cpp
✅ Đọc mỗi 2 giây (tránh lỗi sensor)
✅ Validate: Kiểm tra NaN trước khi gửi
✅ Precision: ±0.5°C (DHT11), ±0.2°C (DHT22)
✅ Range: 0-50°C, 20-90% RH
```

**LED 2 Manual Control:**
```cpp
✅ Button toggle: Debounce 200ms
✅ Remote control: On/Off/Toggle từ server
✅ Manual mode: Timeout 30s (tự động về Auto)
✅ Status: Gửi về ESP8266 mỗi chu kỳ
```

### **Arduino Uno 2 - Access Control & Door**

**RFID Access (Cải tiến):**
```cpp
✅ Card validation: UID 4 bytes (Mifare Classic)
✅ Valid card: Tự động mở cửa
✅ Status display: Giữ 5 giây sau khi quẹt
✅ Manual mode: Không hoạt động khi đang manual
✅ Security: Halt card sau đọc (chống đọc lại)
```

**HC-SR04 Auto-open (Thay đổi từ intruder):**
```cpp
✅ Threshold: < 10cm (thay vì 50cm)
✅ Purpose: Mở cửa tự động (thay vì báo động)
✅ Debounce: 3 lần đọc liên tiếp
✅ Range: 2-400cm, ±1cm accuracy
✅ Trigger time: 10μs pulse
```

**Door Control with Priority System:**
```cpp
enum DoorSource { NONE, AUTO_SENSOR, MANUAL_BUTTON, WEB_COMMAND };

Priority:
1. Manual Mode (Button) → Cao nhất
2. Auto-close (Timer) → Trung bình
3. RFID/HC-SR04 (Auto) → Thấp nhất

✅ Auto-close: 5 giây (tất cả phương thức)
✅ Conflict resolution: Manual hủy auto-close
✅ Source tracking: Biết ai đang điều khiển
✅ Servo protection: Smooth movement, no jitter
```

**Button Control:**
```cpp
✅ Button Open (A0): Mở cửa + vào manual mode
✅ Button Close (A1): Đóng cửa + vào manual mode
✅ Debounce: 200ms
✅ Anti-spam: 500ms giữa các lần nhấn
✅ Manual timeout: 30 giây
```

### **ESP8266 - WiFi Master Coordinator**

**WiFi Management:**
```cpp
✅ Auto-reconnect: Tự động kết nối lại khi mất
✅ Connection timeout: 10 giây
✅ Retry mechanism: 5 lần thử
✅ Status LED: Nhấp nháy khi kết nối
✅ SSID scan: Tìm mạng mạnh nhất (tùy chọn)
```

**I2C Communication:**
```cpp
✅ Request interval: Mỗi 500ms
✅ Timeout: 100ms cho mỗi request
✅ Error handling: Skip nếu slave không phản hồi
✅ Data validation: Kiểm tra checksum (nếu cần)
✅ Bus recovery: Reset I2C nếu bị treo
```

**HTTP Communication:**
```cpp
✅ POST interval: 2 giây
✅ JSON format: ArduinoJson library
✅ Timeout: 5 giây
✅ Retry: 3 lần nếu thất bại
✅ Command polling: Mỗi 1 giây
```

### **Node.js Server - Backend Logic**

**Express REST API:**
```javascript
✅ CORS enabled: Cho phép cross-origin requests
✅ JSON parser: Body parser middleware
✅ Static files: Serve dashboard HTML/CSS/JS
✅ Error handling: Try-catch và error middleware
✅ Logging: Console log mọi request
```

**WebSocket Server:**
```javascript
✅ Port: 3001 (riêng biệt với HTTP)
✅ Broadcast: Gửi đến tất cả clients
✅ Init message: Gửi data khi client connect
✅ Heartbeat: Ping/pong keep-alive (tùy chọn)
✅ Auto-cleanup: Đóng connection zombie
```

**Data Management:**
```javascript
✅ In-memory storage: systemData object
✅ Command queue: pendingCommands object
✅ Auto-clear: Commands xóa sau khi ESP lấy
✅ Timestamp: Mỗi update có timestamp
✅ Validation: Kiểm tra data type
```

### **Flutter Mobile App - Cross-platform UI**

**Authentication System:**
```dart
✅ JSON Database: path_provider + JSON files
✅ Session management: SharedPreferences
✅ Default user: admin/admin123
✅ Auto-login: Remember session
✅ Logout: Clear session + navigate
```

**State Management:**
```dart
✅ Provider pattern: AuthProvider, IoTProvider
✅ Reactive UI: Auto rebuild khi state thay đổi
✅ Separation of concerns: Services/Providers/UI
✅ Error handling: Try-catch + user feedback
```

**Real-time Communication:**
```dart
✅ HTTP: REST API calls (http package)
✅ WebSocket: Real-time updates (web_socket_channel)
✅ Auto-reconnect: Tự động kết nối lại
✅ Offline handling: Hiển thị status
✅ Debounce: Tránh spam requests
```

**UI/UX Features:**
```dart
✅ Material Design 3: Modern, clean interface
✅ Animations: flutter_animate package
✅ Google Fonts: Professional typography
✅ Responsive: Adapt to screen sizes
✅ Dark mode: Support (tùy chọn)
✅ Splash screen: Loading animation
✅ Error snackbar: User-friendly messages
```

---

## 🔒 BẢO MẬT & TỐI ƯU HÓA

### **Bảo mật**
```
✅ Authentication: Login required cho Flutter app
✅ Password: Không lưu plain text (hash MD5/SHA256)
✅ Session: Timeout sau 24h
✅ RFID: UID validation trước khi mở cửa
✅ Network: WiFi WPA2 encryption
⚠️ TODO: HTTPS/SSL cho production
⚠️ TODO: API key authentication
⚠️ TODO: Rate limiting
```

### **Tối ưu hóa**
```
✅ Memory: F() macro cho strings (Arduino)
✅ I2C speed: 100kHz (stable) hoặc 400kHz (fast mode)
✅ Debounce: Hardware + software chống dội
✅ Timeout: Tránh blocking vô hạn
✅ Buffer: Giới hạn size tránh overflow
✅ WebSocket: Broadcast chỉ khi có thay đổi
✅ Flutter: Hot reload cho development
```

---

## 🧪 KIỂM TRA & DEBUG

### **Test checklist**

**Hardware:**
- [ ] I2C bus: Scanner tìm địa chỉ slaves (8, 9)
- [ ] PIR: Vẫy tay kiểm tra LED 1 bật
- [ ] DHT: Nhiệt độ, độ ẩm hiển thị đúng
- [ ] RFID: Quẹt thẻ, kiểm tra UID
- [ ] HC-SR04: Đưa tay gần < 10cm
- [ ] Servo: Mở/đóng mượt, không giật
- [ ] Button: Nhấn debounce tốt
- [ ] LED: Sáng đúng mức, không quá mờ

**Software:**
- [ ] ESP8266: Kết nối WiFi thành công
- [ ] I2C read: Dữ liệu từ Arduino đúng
- [ ] HTTP POST: Server nhận data
- [ ] Command: ESP nhận và gửi xuống Arduino
- [ ] WebSocket: Dashboard update realtime
- [ ] Flutter: Login thành công
- [ ] Flutter: Control LED/door hoạt động
- [ ] Auto-close: Đóng sau 5 giây

### **Serial Monitor Debug**

**Arduino Uno 1 (115200 baud):**
```
Arduino Uno 1 - Slave I2C Started
I2C Slave initialized at address: 8
DHT initialized
=== All systems ready ===

👤 PIR AUTO: Motion detected → LED 1 ON
📊 DHT: T=28.5°C, H=65.2%
I2C Request count: 1250
💤 PIR AUTO: No motion for 7s → LED 1 OFF
```

**Arduino Uno 2 (115200 baud):**
```
Arduino Uno 2 - Slave I2C Started
RFID initialized
HC-SR04 initialized
Servo attached
I2C Slave initialized at address: 9
=== All systems ready ===

🔓 RFID: Thẻ hợp lệ - Mở cửa
🚪 Door MANUAL OPEN by BUTTON
⏱️ Auto-close in 5s...
🚪 Door AUTO CLOSED
📏 Distance: 8.3 cm → AUTO OPEN triggered
```

**ESP8266 (115200 baud):**
```
ESP8266 Master I2C + WiFi Started
I2C Master initialized

=== Connecting to WiFi ===
SSID: MyWiFi
...
✅ WiFi Connected!
IP Address: 192.168.1.105

=== Sending data to server ===
{
  "pir":false,
  "led1":false,
  "led2":true,
  "temperature":28.5,
  "humidity":65.2,
  "door":true,
  "autoOpen":false,
  "rfid":true,
  "distance":8.3,
  "timestamp":1234567
}
HTTP Response code: 200

=== Checking for commands ===
Commands received: {"led2":"toggle"}
→ Sending to Slave 1: 0x03
```

**Node.js Server:**
```
==============================================
IoT Dashboard Server Started
==============================================
HTTP Server: http://localhost:3000
WebSocket Server: ws://localhost:3001
==============================================

WebSocket client connected
Received data from ESP8266: { pir: false, led1: false, ... }
Control command: led2 -> toggle
```

**Flutter App (Debug Console):**
```
Attempting login for: admin
Found 1 users
User found: admin
Credentials: admin, password match: true
Login successful!

Attempting to connect WebSocket...
WebSocket connected!
Received update: { pir: true, temperature: 29.0, ... }

Controlling LED2: on
Response: {status: success, message: ...}
```

---

## 🚨 XỬ LÝ LỖI THƯỜNG GẶP

### **Lỗi I2C**

**Symptom:** ESP8266 không đọc được data từ Arduino
```
Solution:
1. Kiểm tra kết nối SDA/SCL/GND
2. Đảm bảo pull-up resistor 4.7kΩ
3. Chạy I2C Scanner:
   Wire.beginTransmission(address);
   if (Wire.endTransmission() == 0) → OK
4. Kiểm tra địa chỉ: Slave 1 = 8, Slave 2 = 9
5. Thử giảm tốc độ I2C: Wire.setClock(50000);
```

**Symptom:** Data bị lỗi, sai số
```
Solution:
1. Thêm delay giữa các request (ít nhất 50ms)
2. Kiểm tra dây I2C không quá dài (< 1m)
3. Tránh nhiễu: Dùng dây xoắn, tụ lọc 100nF
4. Check voltage level: ESP 3.3V, Arduino 5V
```

### **Lỗi WiFi**

**Symptom:** ESP8266 không kết nối WiFi
```
Solution:
1. Kiểm tra SSID và password (case-sensitive)
2. Đảm bảo WiFi 2.4GHz (không phải 5GHz)
3. Kiểm tra khoảng cách router (< 10m tốt nhất)
4. Reset ESP8266: Nhấn button RST
5. Xóa WiFi cũ: WiFi.disconnect(true);
6. Kiểm tra nguồn: Cần ít nhất 500mA
```

**Symptom:** WiFi connect rồi disconnect
```
Solution:
1. Nguồn yếu → Dùng nguồn 5V/1A
2. Thêm tụ 100µF gần chân VCC/GND
3. WiFi.setAutoReconnect(true);
4. Giảm transmit power: WiFi.setOutputPower(15);
```

### **Lỗi Server**

**Symptom:** ESP8266 không gửi được data lên server
```
Solution:
1. Kiểm tra IP server trong code ESP (ipconfig)
2. Ping từ ESP đến server: http.begin("http://IP:3000")
3. Tắt Firewall hoặc allow port 3000, 3001
4. Kiểm tra server đang chạy: npm start
5. Cùng mạng WiFi: ESP và PC
```

**Symptom:** WebSocket không update
```
Solution:
1. Kiểm tra port 3001 không bị chặn
2. Refresh browser (Ctrl+Shift+R)
3. Xem console browser (F12) có lỗi không
4. Restart server
```

### **Lỗi Sensor**

**Symptom:** DHT đọc NaN
```
Solution:
1. Kiểm tra kết nối VCC/GND/DATA
2. Pull-up 10kΩ từ DATA lên VCC
3. Đợi 2 giây giữa các lần đọc
4. Thử đổi loại: DHT11 ↔ DHT22
5. Thay sensor mới (có thể hỏng)
```

**Symptom:** PIR trigger liên tục
```
Solution:
1. Chỉnh delay potentiometer trên PIR (xoay trái)
2. Chỉnh sensitivity (xoay phải)
3. Tránh gió, nhiệt nguồn
4. Debounce trong code (100ms)
```

**Symptom:** RFID không đọc thẻ
```
Solution:
1. Nguồn RFID phải 3.3V (KHÔNG 5V!)
2. Kiểm tra kết nối SPI (6 chân)
3. Thẻ phải Mifare 13.56MHz
4. Quẹt gần anten (< 3cm)
5. RFID.PCD_Init(); trong setup()
```

**Symptom:** HC-SR04 đọc 0 hoặc số lớn
```
Solution:
1. Kiểm tra Trig/Echo không đổi chỗ
2. Nguồn 5V ổn định
3. Timeout hợp lý (38ms cho 400cm)
4. Vật cản vuông góc, phẳng
5. Khoảng cách 2-400cm
```

**Symptom:** Servo giật, không mượt
```
Solution:
1. Nguồn servo riêng 5V/1A (KHÔNG từ Arduino!)
2. GND chung: Servo GND - Arduino GND
3. Tụ 100µF gần nguồn servo
4. Dùng servo.write() từ từ (delay 15ms)
5. Detach servo khi không dùng: servo.detach()
```

### **Lỗi Flutter App**

**Symptom:** Không login được
```
Solution:
1. Kiểm tra username/password: admin/admin123
2. Xóa app data và reinstall
3. Check console: flutter run --verbose
4. Database path: AppData/Roaming/.../
```

**Symptom:** Không kết nối server
```
Solution:
1. Đổi IP trong lib/services/iot_service.dart
2. PC và phone cùng WiFi
3. Firewall allow port 3000, 3001
4. Ping từ phone: http://192.168.1.xxx:3000
```

**Symptom:** Build failed
```
Solution:
1. flutter clean
2. flutter pub get
3. Kiểm tra pubspec.yaml syntax
4. Update Flutter: flutter upgrade
```

---

## 📊 GIÁM SÁT VÀ PHÂN TÍCH

### **Metrics quan trọng**

**System Performance:**
```
✅ I2C latency: < 10ms mỗi request
✅ WiFi ping: < 50ms
✅ HTTP POST: < 100ms
✅ WebSocket latency: < 20ms
✅ Auto-close timing: Chính xác ±100ms
✅ PIR response: < 500ms
✅ RFID read time: < 300ms
```

**Reliability:**
```
✅ I2C error rate: < 1%
✅ WiFi uptime: > 99%
✅ Server uptime: 24/7
✅ Sensor accuracy: ±5% (DHT), ±1cm (HC-SR04)
```

### **Logging**

**Arduino:**
```cpp
// Enable debug logging
#define DEBUG_MODE 1

#if DEBUG_MODE
  Serial.println(F("Debug: ..."));
#endif
```

**Node.js:**
```javascript
// Winston logger (optional)
const winston = require('winston');

logger.info('Data received', { data });
logger.error('Connection failed', { error });
```

**Flutter:**
```dart
// Debug print
print('Debug: $message');

// Production: Disable logs
if (kDebugMode) {
  print('Debug only: $message');
}
```

---

## 🔮 TÍNH NĂNG MỞ RỘNG

### **Đã hoàn thành**
- ✅ Multi-slave I2C architecture
- ✅ Cross-platform mobile app (Flutter)
- ✅ Real-time WebSocket updates
- ✅ Auto-close with priority system
- ✅ RFID access control with 5s display
- ✅ PIR inverted logic (LOW=motion)
- ✅ HC-SR04 auto-open < 10cm
- ✅ User authentication with JSON DB
- ✅ Material Design 3 UI

### **Có thể mở rộng**
- ⭐ HTTPS/SSL encryption
- ⭐ Database: MySQL/PostgreSQL thay JSON
- ⭐ Multi-user roles (Admin, User, Guest)
- ⭐ History logging (sensor data overtime)
- ⭐ Chart visualization (temperature trends)
- ⭐ Push notifications (motion detected, door opened)
- ⭐ Voice control (Google Assistant, Alexa)
- ⭐ Email/SMS alerts
- ⭐ IR remote control
- ⭐ Camera integration (ESP32-CAM)
- ⭐ Energy monitoring (current sensor)
- ⭐ Scheduling (turn on/off at specific time)
- ⭐ Geofencing (auto control khi về nhà)
- ⭐ Multiple rooms/zones
- ⭐ Cloud sync (Firebase, AWS IoT)

---

## 📖 TÀI LIỆU THAM KHẢO

### **Datasheets**
- ESP8266: https://www.espressif.com/sites/default/files/documentation/0a-esp8266ex_datasheet_en.pdf
- Arduino Uno: https://docs.arduino.cc/hardware/uno-rev3
- DHT11/DHT22: https://www.mouser.com/datasheet/2/758/DHT11-Technical-Data-Sheet-Translated-Version-1143054.pdf
- HC-SR04: https://cdn.sparkfun.com/datasheets/Sensors/Proximity/HCSR04.pdf
- MFRC522: https://www.nxp.com/docs/en/data-sheet/MFRC522.pdf
- SG90 Servo: http://www.ee.ic.ac.uk/pcheung/teaching/DE1_EE/stores/sg90_datasheet.pdf

### **Libraries**
- ArduinoJson: https://arduinojson.org/
- DHT Sensor: https://github.com/adafruit/DHT-sensor-library
- MFRC522: https://github.com/miguelbalboa/rfid
- Express.js: https://expressjs.com/
- Flutter: https://flutter.dev/docs

### **Protocols**
- I2C Specification: https://www.nxp.com/docs/en/user-guide/UM10204.pdf
- HTTP/1.1: https://tools.ietf.org/html/rfc2616
- WebSocket: https://tools.ietf.org/html/rfc6455

---

## 👥 ĐÓNG GÓP & HỖ TRỢ

### **Báo lỗi (Bug Report)**
Nếu gặp lỗi, vui lòng cung cấp:
1. Mô tả lỗi chi tiết
2. Các bước tái hiện
3. Serial Monitor output
4. Sơ đồ kết nối
5. Code đã sửa đổi (nếu có)

### **Đề xuất tính năng (Feature Request)**
1. Mô tả tính năng
2. Use case cụ thể
3. Ưu tiên (High/Medium/Low)
4. Có sẵn sàng contribute code không?

### **Pull Request**
1. Fork repository
2. Tạo branch mới: `git checkout -b feature/TenTinhNang`
3. Commit: `git commit -m 'Add TenTinhNang'`
4. Push: `git push origin feature/TenTinhNang`
5. Tạo Pull Request

---

## 📄 GIẤY PHÉP (LICENSE)

```
MIT License

Copyright (c) 2025 [Tên của bạn]

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## 📝 CHANGELOG

### Version 4.0.0 (2025-11-18)
**Added:**
- 🚀 **MQTT Protocol Implementation**: Thay thế HTTP polling bằng MQTT publish/subscribe
- 🔌 **Embedded MQTT Broker**: Aedes MQTT broker tích hợp trong Node.js server
- 📡 **Real-time MQTT Communication**: ESP8266 publish sensor data, subscribe commands
- 📱 **Flutter MQTT Client**: Mobile app sử dụng MQTT thay vì WebSocket
- 🏗️ **Topic-based Architecture**: Structured MQTT topics cho sensors và commands
- ⚡ **Event-driven Updates**: Real-time updates chỉ khi có thay đổi
- 🔄 **QoS Support**: MQTT Quality of Service levels
- 📊 **Retained Messages**: Sensor data được retain trên broker

**Changed:**
- 🔄 **Communication Protocol**: MQTT thay thế HTTP/WebSocket cho ESP8266
- 🔄 **Data Flow**: Event-driven thay vì polling-based
- 🔄 **Flutter Connection**: MQTT client thay thế WebSocket
- 🔄 **Server Architecture**: MQTT broker + client trong Node.js

**Technical Improvements:**
- ⚡ **Reduced Bandwidth**: Chỉ publish khi có thay đổi
- 🔋 **Better Power Efficiency**: ESP8266 không cần polling liên tục
- 🛠️ **Improved Reliability**: MQTT QoS và retained messages
- 📈 **Scalability**: Dễ dàng thêm nhiều devices
- 🔧 **Simplified Architecture**: Ít dependencies hơn

### Version 3.0.0 (2025-11-17)
**Added:**
- ✨ Flutter cross-platform mobile app (Android, iOS, Windows)
- ✨ User authentication with JSON database
- ✨ Material Design 3 UI/UX
- ✨ Real-time WebSocket communication
- ✨ Control panel for LED and Door
- ✨ RFID status display with 5-second timeout
- ✨ PIR inverted logic (LOW = motion detected)
- ✨ State management with Provider pattern

**Changed:**
- 🔄 HC-SR04: Auto-door (< 10cm) thay vì intruder (< 50cm)
- 🔄 RFID: Giữ trạng thái 5 giây thay vì reset ngay
- 🔄 Auto-close: Unified 5 giây cho tất cả methods
- 🔄 Priority system: Manual > Auto-close > RFID/HC-SR04

**Fixed:**
- 🐛 Memory overflow Arduino Uno 2 (111% → 70%)
- 🐛 I2C communication stability
- 🐛 RFID card detection reliability
- 🐛 Servo jitter prevention
- 🐛 Flutter database initialization loop

### Version 2.0.0 (2025-11-15)
**Added:**
- ✨ Arduino Uno 2 auto-close feature
- ✨ Door control priority system
- ✨ Manual mode timeout (30 seconds)
- ✨ HC-SR04 purpose change (auto-door)

**Changed:**
- 🔄 Door logic: Conflict resolution
- 🔄 RFID và HC-SR04: Không override manual

**Fixed:**
- 🐛 Auto-close conflicts
- 🐛 Button debounce improvement

### Version 1.0.0 (2025-11-10)
**Initial Release:**
- ✨ ESP8266 + 2 Arduino Uno I2C architecture
- ✨ PIR motion detection
- ✨ DHT temperature & humidity
- ✨ RFID access control
- ✨ HC-SR04 distance measurement
- ✨ Servo door control
- ✨ Node.js web dashboard
- ✨ WebSocket real-time updates

---

## 🎓 KẾT LUẬN

Hệ thống IoT Smart Home này minh họa việc tích hợp đa nền tảng:
- **Hardware**: Arduino, ESP8266, sensors, actuators
- **Embedded**: C/C++, I2C, SPI protocols
- **Backend**: Node.js, Express, WebSocket
- **Frontend**: HTML/CSS/JavaScript, Flutter/Dart
- **Database**: JSON file-based storage
- **Network**: WiFi, HTTP, WebSocket

### **Ứng dụng thực tế**
```
🏠 Smart Home: Tự động hóa nhà thông minh
🏢 Office: Kiểm soát ra vào bằng RFID
🏨 Hotel: Khóa cửa thông minh
🏭 Factory: Giám sát nhiệt độ, độ ẩm
🏥 Hospital: Kiểm soát truy cập phòng
🎓 School: Điểm danh tự động (RFID)
```

### **Kỹ năng đạt được**
```
✅ Lập trình nhúng (Arduino, ESP8266)
✅ Giao thức truyền thông (I2C, SPI, HTTP, WebSocket)
✅ Backend development (Node.js, REST API)
✅ Frontend development (Web, Flutter)
✅ Database design (JSON, schema)
✅ Network programming (WiFi, TCP/IP)
✅ State management (Provider pattern)
✅ UI/UX design (Material Design)
✅ Debugging & troubleshooting
✅ Documentation & reporting
```

---

**🎉 Chúc bạn thành công với dự án IoT Smart Home!**

**📧 Contact:**
- Email: your.email@example.com
- GitHub: https://github.com/yourusername
- Website: https://yourwebsite.com

**⭐ Nếu project hữu ích, hãy star repository!**

---

*Last updated: November 18, 2025*
*Version: 4.0.0*

---

## 🔌 KẾT NỐI PHẦN CỨNG

### **I2C Bus (Kết nối chung)**
```
ESP8266 (Master)       Arduino Uno 1 (Slave 1)    Arduino Uno 2 (Slave 2)
D1 (GPIO5 - SCL) -------- A5 (SCL) ----------------- A5 (SCL)
D2 (GPIO4 - SDA) -------- A4 (SDA) ----------------- A4 (SDA)
GND ---------------------- GND ---------------------- GND
```

**⚠️ LƯU Ý:** ESP8266 hoạt động ở 3.3V, Arduino Uno ở 5V. Cần dùng **level shifter** hoặc **pull-up resistor 4.7kΩ lên 3.3V** cho I2C bus!

---

### **Arduino Uno 1 - Kết nối**
| Linh kiện | Chân Arduino |
|-----------|--------------|
| PIR Sensor | 2 |
| DHT Sensor (DHT11/DHT22) | 3 |
| LED 1 (PIR) | 11 |
| LED 2 (Button) | 10 |
| Button 1 | 12 (INPUT_PULLUP) |
| I2C SDA | A4 |
| I2C SCL | A5 |

---

### **Arduino Uno 2 - Kết nối**
| Linh kiện | Chân Arduino |
|-----------|--------------|
| Button 2 (Mở cửa) | A0 |
| Button 3 (Đóng cửa) | A1 |
| Servo | A2 |
| HC-SR04 Trig | 4 |
| HC-SR04 Echo | 5 |
| RFID RC522 SDA | 10 |
| RFID RC522 SCK | 13 |
| RFID RC522 MOSI | 11 |
| RFID RC522 MISO | 12 |
| RFID RC522 RST | 9 |
| I2C SDA | A4 |
| I2C SCL | A5 |

---

## 📚 THƯ VIỆN CẦN CÀI ĐẶT

### **Arduino IDE**
1. Mở **Arduino IDE**
2. Vào **Tools → Manage Libraries**
3. Tìm và cài đặt các thư viện sau:

#### **Cho Arduino Uno 1:**
- `DHT sensor library` by Adafruit
- `Adafruit Unified Sensor`
- `Wire` (built-in)

#### **Cho Arduino Uno 2:**
- `MFRC522` by GithubCommunity
- `Servo` (built-in)
- `SPI` (built-in)
- `Wire` (built-in)

#### **Cho ESP8266:**
- `ESP8266WiFi` (built-in với ESP8266 board)
- `PubSubClient` by Nick O'Leary (MQTT client)
- `ArduinoJson` by Benoit Blanchon (v6.x)
- `PubSubClient` by Nick O'Leary (MQTT client)
- `Wire` (built-in)

### **Cài đặt Board ESP8266**
1. Vào **File → Preferences**
2. Thêm URL vào **Additional Board Manager URLs**:
   ```
   http://arduino.esp8266.com/stable/package_esp8266com_index.json
   ```
3. Vào **Tools → Board → Boards Manager**
4. Tìm **ESP8266** và cài đặt

---

## ⚙️ CẤU HÌNH & UPLOAD CODE

### **Bước 1: Upload code Arduino Uno 1**
1. Mở file `Arduino_Uno_1_Slave/Arduino_Uno_1_Slave.ino`
2. **Kiểm tra loại DHT sensor** (dòng 19):
   ```cpp
   #define DHTTYPE DHT11  // Hoặc DHT22
   ```
3. Chọn **Board: Arduino Uno**
4. Chọn **Port** (COM port của Arduino)
5. Nhấn **Upload**
6. Mở **Serial Monitor** (115200 baud) để kiểm tra

---

### **Bước 2: Upload code Arduino Uno 2**
1. Mở file `Arduino_Uno_2_Slave/Arduino_Uno_2_Slave.ino`
2. **Cấu hình UID thẻ RFID hợp lệ** (dòng 42):
   ```cpp
   byte validCard[4] = {0xDE, 0xAD, 0xBE, 0xEF};  // Thay bằng UID thẻ của bạn
   ```
   
   **Cách tìm UID thẻ:**
   - Upload code và mở Serial Monitor
   - Quẹt thẻ RFID
   - Xem UID hiển thị (ví dụ: `DE AD BE EF`)
   - Copy và paste vào mảng `validCard`

3. Chọn **Board: Arduino Uno**
4. Chọn **Port**
5. Nhấn **Upload**
6. Kiểm tra Serial Monitor

---

### **Bước 3: Upload code ESP8266**
1. Mở file `ESP8266_Master/ESP8266_Master.ino`
2. **Cấu hình WiFi** (dòng 17-18):
   ```cpp
   const char* ssid = "TEN_WIFI_CUA_BAN";
   const char* password = "MAT_KHAU_WIFI";
   ```

3. **Cấu hình IP máy tính** (dòng 21):
   - Tìm IP máy tính:
     - Windows: Mở CMD, gõ `ipconfig`
     - Tìm dòng **IPv4 Address** (ví dụ: 192.168.1.100)
   - Thay vào code:
     ```cpp
     const char* serverIP = "192.168.1.100";  // IP máy tính của bạn
     ```

4. Chọn **Board: NodeMCU 1.0 (ESP-12E Module)** hoặc board ESP8266 tương ứng
5. Chọn **Port**
6. Nhấn **Upload**
7. Mở **Serial Monitor** (115200 baud)
8. **Kiểm tra kết nối WiFi và server**

---

## 🖥️ CHẠY NODE.JS SERVER

### **Bước 1: Cài đặt Node.js**
- Tải và cài đặt từ: https://nodejs.org/ (phiên bản LTS)
- Kiểm tra: Mở CMD/PowerShell, gõ:
  ```bash
  node --version
  npm --version
  ```

### **Bước 2: Cài đặt dependencies**
1. Mở **Terminal/CMD** trong thư mục `NodeJS_Server`
2. Chạy lệnh:
   ```bash
   npm install
   ```

### **Bước 3: Chạy server**
```bash
npm start
```

Hoặc chế độ development (tự động restart khi thay đổi code):
```bash
npm run dev
```

### **Bước 4: Mở Dashboard**
- Mở trình duyệt web
- Truy cập: `http://localhost:3000`
- Dashboard sẽ tự động cập nhật khi nhận dữ liệu từ ESP8266

---

## 📡 GIAO THỨC I2C

### **Frame dữ liệu từ Arduino Uno 1 (7 bytes):**
| Byte | Nội dung |
|------|----------|
| 0 | PIR state (0/1) |
| 1 | LED 1 state (0/1) |
| 2 | LED 2 state (0/1) |
| 3-4 | Temperature (int16 × 10) |
| 5-6 | Humidity (int16 × 10) |

### **Frame dữ liệu từ Arduino Uno 2 (5 bytes):**
| Byte | Nội dung |
|------|----------|
| 0 | Door state (0/1) |
| 1 | Auto-open active (0/1) |
| 2 | RFID access granted (0/1) |
| 3-4 | Distance (int16 × 10) cm |

### **Lệnh điều khiển từ ESP8266:**

**Gửi đến Arduino Uno 1:**
- `0x01`: Bật LED 2
- `0x02`: Tắt LED 2
- `0x03`: Toggle LED 2
- `0x04`: Bật LED 1 (override PIR)
- `0x05`: Tắt LED 1 (override PIR)

**Gửi đến Arduino Uno 2:**
- `0x10`: Mở cửa
- `0x11`: Đóng cửa
- `0x12`: Toggle cửa

---

## 🎯 CHỨC NĂNG HỆ THỐNG

### **Arduino Uno 1:**
✅ Phát hiện chuyển động (PIR) → tự động bật LED 1  
✅ Tắt LED 1 sau 7 giây không có chuyển động  
✅ Nhấn Button 1 → đảo trạng thái LED 2  
✅ Đo nhiệt độ, độ ẩm (DHT)  
✅ Gửi dữ liệu về ESP8266 qua I2C  
✅ Nhận lệnh điều khiển LED từ ESP8266  

### **Arduino Uno 2:**
✅ Nhấn Button 2 → mở cửa (servo 0° → 90°)  
✅ Nhấn Button 3 → đóng cửa (servo 90° → 0°)  
✅ Quẹt RFID đúng thẻ → tự động mở cửa  
✅ Đo khoảng cách bằng HC-SR04  
✅ Tự động mở cửa khi phát hiện người ở khoảng cách < 10cm  
✅ Gửi dữ liệu về ESP8266 qua I2C  
✅ Nhận lệnh điều khiển cửa từ ESP8266  

### **ESP8266:**
✅ Thu thập dữ liệu từ 2 Arduino qua I2C  
✅ Kết nối WiFi (STA mode)  
✅ Gửi dữ liệu lên Node.js server mỗi 2 giây  
✅ Nhận lệnh điều khiển từ server  
✅ Gửi lệnh xuống 2 Arduino qua I2C  

### **Node.js Dashboard:**
✅ Hiển thị nhiệt độ, độ ẩm  
✅ Hiển thị trạng thái PIR, LED, cửa, RFID  
✅ Hiển thị khoảng cách từ HC-SR04  
✅ Hiển thị trạng thái tự động mở cửa (màu xanh lá)  
✅ Điều khiển LED (bật/tắt/toggle)  
✅ Điều khiển cửa (mở/đóng/toggle)  
✅ Cập nhật realtime qua WebSocket  

---

## 🔧 TROUBLESHOOTING

### **Lỗi I2C không giao tiếp được:**
1. Kiểm tra kết nối SDA, SCL, GND
2. Đảm bảo có pull-up resistor 4.7kΩ trên SDA và SCL
3. Kiểm tra địa chỉ I2C (Slave 1 = 8, Slave 2 = 9)
4. Dùng I2C scanner để tìm địa chỉ:
   ```cpp
   Wire.beginTransmission(address);
   byte error = Wire.endTransmission();
   ```

### **ESP8266 không kết nối WiFi:**
1. Kiểm tra SSID và password
2. Đảm bảo WiFi là 2.4GHz (ESP8266 không hỗ trợ 5GHz)
3. Kiểm tra khoảng cách đến router
4. Xem Serial Monitor để debug

### **Server không nhận dữ liệu:**
1. Kiểm tra IP máy tính trong code ESP8266
2. Tắt Firewall hoặc cho phép port 3000, 3001
3. Đảm bảo ESP8266 và PC cùng mạng WiFi
4. Xem console của server (npm start)

### **RFID không đọc được thẻ:**
1. Kiểm tra kết nối SPI (SDA, SCK, MOSI, MISO, RST)
2. Nguồn RFID phải đủ (3.3V, không dùng 5V!)
3. Quẹt thẻ gần anten
4. Xem Serial Monitor để debug UID

### **Servo không hoạt động:**
1. Servo cần nguồn riêng (5V, ít nhất 1A)
2. Không cấp nguồn servo từ chân Arduino
3. Nối GND chung giữa nguồn servo và Arduino

---

## 📊 KIẾN TRÚC TRUYỀN THÔNG

```
┌─────────────────┐
│   Dashboard     │  ← Browser (http://localhost:3000)
│   (HTML/CSS/JS) │
└────────┬────────┘
          │ WebSocket (port 3001)
          │ HTTP REST API (port 3000)
          ▼
┌─────────────────┐
│  Node.js Server │  ← PC (Express + WebSocket + MQTT)
│   (server.js)   │
│                 │
│ MQTT Broker     │  ← Aedes MQTT Broker (port 1883)
│ (Aedes)         │
└────────┬────────┘
          │ MQTT Publish/Subscribe
          │ WiFi Network (2.4GHz)
          ▼
┌─────────────────┐
│    ESP8266      │  ← Master I2C + MQTT Client
│   (WiFi STA)    │
│                 │
│ MQTT Publisher  │  ← Publish sensor data
│ MQTT Subscriber │  ← Subscribe to commands
└────────┬────────┘
          │ I2C Bus (SDA/SCL)
          │
     ─────┴─────
     │         │
     ▼         ▼
┌────────┐ ┌────────┐
│Arduino │ │Arduino │
│ Uno 1  │ │ Uno 2  │
│(Slave 8)│ │(Slave 9)│
└────────┘ └────────┘
```

---

## 📝 NOTES

- **Mức điện áp:** ESP8266 (3.3V), Arduino Uno (5V) → **Cần level shifter cho I2C!**
- **Pull-up resistor:** 4.7kΩ từ SDA/SCL lên 3.3V
- **Nguồn servo:** Dùng nguồn riêng 5V/1A, nối GND chung
- **WiFi:** Chỉ hỗ trợ 2.4GHz
- **Firewall:** Cho phép port 3000 và 3001
- **Serial Monitor:** Baud rate 115200 (ESP8266), 9600 (Arduino)

---

## 🎨 TÍNH NĂNG DASHBOARD

- 🌡️ **Nhiệt độ & độ ẩm** hiển thị realtime
- 👤 **Cảm biến chuyển động** với animation
- 💡 **Điều khiển 2 LED** từ xa
- 🚪 **Mở/đóng cửa** bằng nút bấm
- 🔐 **Trạng thái RFID** access
- 🚶 **Tự động mở cửa** khi phát hiện người (< 10cm)
- 📊 **Khoảng cách** từ HC-SR04
- ⚡ **Cập nhật tức thời** qua WebSocket
- 🎨 **Giao diện đẹp** responsive design

---

## 👨‍💻 HỖ TRỢ

Nếu gặp vấn đề, kiểm tra:
1. **Serial Monitor** của cả 3 board
2. **Console** của Node.js server
3. **Developer Tools (F12)** trên browser
4. Kiểm tra kết nối phần cứng theo sơ đồ

---

## 📄 LICENSE

MIT License - Tự do sử dụng cho mục đích học tập và thương mại.

---

**🎉 Chúc bạn thành công với dự án IoT Smart Home!**
