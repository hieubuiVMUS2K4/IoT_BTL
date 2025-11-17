# HƯỚNG DẪN NHANH - QUICK START

## 🚀 CÁC BƯỚC THỰC HIỆN

### 1️⃣ CÀI ĐẶT THƯ VIỆN ARDUINO
Mở Arduino IDE → Tools → Manage Libraries, tìm và cài:
- `DHT sensor library` (Adafruit)
- `Adafruit Unified Sensor`
- `MFRC522`
- `ArduinoJson` (v6.x)

Cài board ESP8266:
- File → Preferences → Additional Board Manager URLs:
  ```
  http://arduino.esp8266.com/stable/package_esp8266com_index.json
  ```
- Tools → Board → Boards Manager → tìm "ESP8266" và cài

---

### 2️⃣ CẤU HÌNH & UPLOAD CODE

**Arduino Uno 1:**
1. Mở `Arduino_Uno_1_Slave/Arduino_Uno_1_Slave.ino`
2. Kiểm tra loại DHT (dòng 19): `DHT11` hoặc `DHT22`
3. Upload (Board: Arduino Uno)

**Arduino Uno 2:**
1. Mở `Arduino_Uno_2_Slave/Arduino_Uno_2_Slave.ino`
2. Quẹt thẻ RFID để xem UID trong Serial Monitor
3. Thay UID vào dòng 42:
   ```cpp
   byte validCard[4] = {0xDE, 0xAD, 0xBE, 0xEF};
   ```
4. Upload (Board: Arduino Uno)

**ESP8266:**
1. Mở `ESP8266_Master/ESP8266_Master.ino`
2. Sửa WiFi (dòng 17-18):
   ```cpp
   const char* ssid = "TEN_WIFI";
   const char* password = "MAT_KHAU";
   ```
3. Tìm IP máy tính (CMD → `ipconfig`) và sửa dòng 21:
   ```cpp
   const char* serverIP = "192.168.1.100";  // IP máy bạn
   ```
4. Upload (Board: NodeMCU 1.0)

---

### 3️⃣ CHẠY NODE.JS SERVER

```bash
cd NodeJS_Server
npm install
npm start
```

Mở browser: `http://localhost:3000`

---

## ⚠️ LƯU Ý QUAN TRỌNG

### Kết nối I2C:
```
ESP8266 D1 (SCL) ──┬── Arduino Uno 1 A5 (SCL)
                   └── Arduino Uno 2 A5 (SCL)

ESP8266 D2 (SDA) ──┬── Arduino Uno 1 A4 (SDA)
                   └── Arduino Uno 2 A4 (SDA)

GND ────────────────┴── GND chung
```

**🔴 BẮT BUỘC:** Dùng **level shifter** hoặc **pull-up resistor 4.7kΩ lên 3.3V** cho I2C!

### Nguồn Servo:
- ❌ KHÔNG cấp nguồn servo từ Arduino
- ✅ Dùng nguồn riêng 5V/1A
- ✅ Nối GND chung

### Troubleshooting:
- **WiFi không kết nối:** Kiểm tra WiFi 2.4GHz (không phải 5GHz)
- **Server không nhận:** Tắt Firewall hoặc cho phép port 3000, 3001
- **I2C lỗi:** Kiểm tra pull-up resistor và level shifter
- **RFID không đọc:** Nguồn RFID phải 3.3V (không phải 5V!)

---

## 📊 KIỂM TRA

1. ✅ Serial Monitor Arduino Uno 1 (9600 baud): Xem dữ liệu PIR, DHT
2. ✅ Serial Monitor Arduino Uno 2 (9600 baud): Xem RFID UID, khoảng cách
3. ✅ Serial Monitor ESP8266 (115200 baud): Xem WiFi kết nối và gửi data
4. ✅ Terminal Node.js: Xem server nhận dữ liệu
5. ✅ Browser Dashboard: Xem giao diện cập nhật realtime

---

**Đọc chi tiết trong file README.md chính!**
