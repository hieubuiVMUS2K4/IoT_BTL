# 🔍 HƯỚNG DẪN DEBUG HỆ THỐNG

## ❌ VẤN ĐỀ PHÁT HIỆN

### 1. **Quạt không chạy khi điều khiển từ Flutter**
- ✅ Cửa hoạt động OK
- ✅ LED hoạt động OK
- ❌ Quạt chỉ thấy gửi lệnh nhưng không chạy

### 2. **Dashboard không cập nhật dữ liệu**
- WebSocket không kết nối được

### 3. **WiFi Config timeout**
- ESP8266 IP address không đúng

### 4. **Reports screen lỗi**
- LocaleDataException - Đã fix!

---

## ✅ ĐÃ FIX

1. **LocaleDataException** - Thêm `initializeDateFormatting()` trong main.dart
2. **setState() after dispose** - Thêm kiểm tra `mounted` trước setState
3. **ESP8266 compile error** - Đổi `default_ssid` → `fallback_ssid`

---

## 🔧 DEBUG QUẠT KHÔNG CHẠY

### **Bước 1: Kiểm tra Serial Monitor Arduino Uno 1**

Khi bạn nhấn nút điều khiển quạt từ Flutter, kiểm tra xem Arduino có nhận được lệnh không:

```
Expected output:
Received command: 0x07  // Bật quạt
🌐 WEB: FAN ON (manual 60s)
```

### **Bước 2: Kiểm tra kết nối phần cứng**

**L298N Fan Driver:**
```
Arduino Uno 1:
- Pin 6 (ENA_PIN) → L298N ENA (PWM speed control)
- Pin 7 (IN1_PIN) → L298N IN1
- Pin 8 (IN2_PIN) → L298N IN2
- GND → L298N GND
- 5V → L298N 5V (logic)

L298N:
- OUT1, OUT2 → Motor Fan
- 12V power supply → L298N 12V input
```

### **Bước 3: Test quạt trực tiếp**

Upload code test đơn giản:

```cpp
void setup() {
  pinMode(6, OUTPUT); // ENA
  pinMode(7, OUTPUT); // IN1
  pinMode(8, OUTPUT); // IN2
  
  digitalWrite(7, HIGH);
  digitalWrite(8, LOW);
  analogWrite(6, 255); // Full speed
}

void loop() {
  // Quạt sẽ chạy liên tục
}
```

Nếu quạt KHÔNG chạy → **Lỗi phần cứng** (dây nối hoặc L298N hỏng)

### **Bước 4: Kiểm tra ESP8266 Serial Monitor**

```
Expected output khi nhấn nút Fan:
📥 MQTT Received [iot/control/fan]: on
→ Slave1 cmd: 0x07
```

### **Bước 5: Kiểm tra UART giữa ESP8266 và Arduino**

**Kết nối UART:**
```
ESP8266 D2 (TX/GPIO4) → Arduino Uno 1 Pin 4 (RX)
ESP8266 D1 (RX/GPIO5) → Arduino Uno 1 Pin 5 (TX)
GND → GND (quan trọng!)
```

---

## 🌐 DEBUG DASHBOARD KHÔNG CẬP NHẬT

### **Nguyên nhân:**

Flutter app đang kết nối đến **Render server**, nhưng có thể:
1. Render server chưa deploy code mới
2. WebSocket URL không đúng

### **Fix:**

Kiểm tra file `iot_service.dart`:

```dart
IoTService({
  this.baseUrl = 'https://iot-btl-9tr7.onrender.com',
  this.wsUrl = 'wss://iot-btl-9tr7.onrender.com',  // ✅ WSS (not WS)
});
```

### **Test WebSocket:**

Mở Developer Console trong browser và test:

```javascript
const ws = new WebSocket('wss://iot-btl-9tr7.onrender.com');
ws.onmessage = (e) => console.log('Data:', e.data);
ws.onerror = (e) => console.error('Error:', e);
```

---

## 📡 DEBUG WIFI CONFIG TIMEOUT

### **Vấn đề:**

ESP8266 IP mặc định là `192.168.4.1` (AP mode), nhưng khi đã kết nối WiFi thì IP sẽ khác.

### **Tìm IP của ESP8266:**

1. Mở Serial Monitor của ESP8266 (115200 baud)
2. Sau khi khởi động, xem dòng:
   ```
   ✓ WiFi connected!
   IP: 192.168.1.xxx  ← ĐÂY LÀ IP CẦN DÙNG
   ```

3. Trong Flutter app, nhập IP này vào ô "ESP8266 IP Address"

---

## 📊 CHECKLIST HOÀN CHỈNH

### **Hardware:**
- [ ] Arduino Uno 1 đã nạp code mới
- [ ] Arduino Uno 2 đã nạp code mới
- [ ] ESP8266 đã nạp code mới
- [ ] Tất cả GND được nối chung
- [ ] UART connections đúng
- [ ] L298N được cấp nguồn 12V
- [ ] Quạt test trực tiếp hoạt động OK

### **Software:**
- [ ] Render server đã deploy code mới (check logs)
- [ ] Flutter app đã rebuild (`flutter clean; flutter run`)
- [ ] ESP8266 kết nối WiFi "tinhvdth" thành công
- [ ] ESP8266 kết nối MQTT HiveMQ thành công
- [ ] WebSocket từ Flutter → Render hoạt động

### **Serial Monitor Checks:**
- [ ] Arduino Uno 1: Nhận được lệnh 0x07, 0x08, 0x09
- [ ] ESP8266: Publish MQTT topics thành công
- [ ] ESP8266: Subscribe control topics thành công

---

## 🚀 LỆNH CHẠY HỆ THỐNG

### **1. Nạp code vào hardware:**

```bash
# Arduino IDE
# 1. Mở Arduino_Uno_1_Slave.ino → Upload (Board: Arduino Uno)
# 2. Mở Arduino_Uno_2_Slave.ino → Upload (Board: Arduino Uno)
# 3. Mở ESP8266_Master.ino → Upload (Board: NodeMCU 1.0)
```

### **2. Chạy Flutter App:**

```powershell
cd "c:\Users\hieuu\Downloads\IoT_BTL\IoT_BTL\FlutterApp"
flutter clean
flutter pub get
flutter run -d windows
```

### **3. Monitor logs:**

**Terminal 1 - ESP8266:**
```
Arduino IDE → Tools → Serial Monitor → 115200 baud
```

**Terminal 2 - Arduino Uno 1:**
```
Arduino IDE → Tools → Serial Monitor → 9600 baud
```

**Terminal 3 - Render Logs:**
```
https://dashboard.render.com → iot-mqtt-server → Logs
```

---

## 💡 TIP DEBUG

### **Nếu quạt vẫn không chạy:**

Thêm debug log vào `Arduino_Uno_1_Slave.ino`:

```cpp
void turnOnFan() {
  Serial.println("DEBUG: turnOnFan() called");
  Serial.print("  Setting IN1=HIGH, IN2=LOW... ");
  digitalWrite(FAN_IN1_PIN, HIGH);
  digitalWrite(FAN_IN2_PIN, LOW);
  Serial.println("OK");
  
  delay(10);
  
  Serial.print("  Setting ENA=255 (PWM)... ");
  analogWrite(FAN_ENA_PIN, 255);
  Serial.println("OK");
  
  fanState = true;
  Serial.println("  fanState = true");
  Serial.println("DEBUG: turnOnFan() completed");
}
```

Upload lại và xem Serial Monitor để biết lệnh có thực thi đúng không!

---

## 📞 COMMON ISSUES

| Vấn đề | Nguyên nhân | Giải pháp |
|--------|------------|-----------|
| Quạt không chạy | Dây nối sai / L298N hỏng | Kiểm tra kết nối phần cứng |
| Dashboard trống | WebSocket không kết nối | Check Render server logs |
| WiFi Config timeout | IP address sai | Lấy IP từ Serial Monitor ESP8266 |
| Reports crash | LocaleData chưa init | Đã fix trong main.dart |
| ESP không kết nối MQTT | Credentials sai | Check HiveMQ Cloud dashboard |

