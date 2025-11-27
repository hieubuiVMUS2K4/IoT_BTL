# I2C Debug Checklist

## Current Problem: ESP8266 nhận 0 bytes từ CẢ 2 Arduino

### ✅ Step 1: Kiểm tra Arduino Serial Monitor

**Arduino Uno 1 (9600 baud):**
- Có thấy: `✓ I2C requests received: X` ?
- Nếu KHÔNG → ESP8266 KHÔNG gửi request đến Arduino
- Nếu CÓ → Arduino nhận request nhưng không gửi data về

**Arduino Uno 2 (9600 baud):**
- Có thấy: `I2C: X` (số lần request)?
- Tương tự như Uno 1

### ✅ Step 2: Kiểm tra dây nối I2C

**Kết nối ĐÚNG phải là:**

```
ESP8266 D1 (GPIO5/SCL) ─────┬─── Arduino Uno 1 pin A5
                             └─── Arduino Uno 2 pin A5

ESP8266 D2 (GPIO4/SDA) ─────┬─── Arduino Uno 1 pin A4  
                             └─── Arduino Uno 2 pin A4

ESP8266 GND ────────────────┬─── Arduino Uno 1 GND
                             └─── Arduino Uno 2 GND
```

**QUAN TRỌNG:**
- Cả 3 board PHẢI chung GND
- SDA nối với SDA (A4)
- SCL nối với SCL (A5)
- KHÔNG nối 5V với 3.3V trực tiếp

### ✅ Step 3: Kiểm tra nguồn điện

- Arduino Uno 1: Có LED power sáng?
- Arduino Uno 2: Có LED power sáng?
- ESP8266: Có kết nối WiFi? (check ESP Serial: "✓ WiFi connected!")

### ✅ Step 4: Test riêng từng Arduino

**Test Uno 1 RIÊNG LẺ:**
1. Ngắt kết nối I2C với Uno 2 (rút dây A4, A5 của Uno 2)
2. Chỉ để Uno 1 nối với ESP8266
3. Upload lại code ESP8266 hoặc reset
4. Xem có nhận được data từ Uno 1 không

**Test Uno 2 RIÊNG LẺ:**
1. Ngắt kết nối I2C với Uno 1
2. Chỉ để Uno 2 nối với ESP8266
3. Reset ESP8266
4. Xem có nhận được data từ Uno 2 không

### ✅ Step 5: Kiểm tra địa chỉ I2C

**Chạy I2C Scanner trên ESP8266:**

Upload code sau lên ESP8266 để scan thiết bị I2C:

```cpp
#include <Wire.h>

void setup() {
  Serial.begin(115200);
  Wire.begin(4, 5); // SDA=D2, SCL=D1
  Serial.println("\nI2C Scanner");
}

void loop() {
  byte error, address;
  int nDevices = 0;

  Serial.println("Scanning...");

  for(address = 1; address < 127; address++ ) {
    Wire.beginTransmission(address);
    error = Wire.endTransmission();

    if (error == 0) {
      Serial.print("Device found at 0x");
      if (address<16) Serial.print("0");
      Serial.print(address,HEX);
      Serial.println();
      nDevices++;
    }
  }
  
  if (nDevices == 0)
    Serial.println("No I2C devices found\n");
  else
    Serial.println("done\n");

  delay(5000);
}
```

**Kết quả mong đợi:**
```
Device found at 0x08  <- Arduino Uno 1
Device found at 0x09  <- Arduino Uno 2
```

### ✅ Step 6: Kiểm tra Pull-up resistor

I2C cần pull-up resistor trên SDA và SCL:
- Arduino Uno có pull-up internal (~20-50kΩ) - có thể KHÔNG đủ mạnh
- ESP8266 có pull-up internal yếu

**Giải pháp:** Thêm 2 điện trở 4.7kΩ:
- 4.7kΩ từ SDA → 3.3V (ESP8266)
- 4.7kΩ từ SCL → 3.3V (ESP8266)

### ✅ Step 7: Kiểm tra level shifter (nếu dùng)

- ESP8266: 3.3V logic
- Arduino Uno: 5V logic

**NẾU đấu trực tiếp 5V từ Uno vào ESP8266 → CÓ THỂ hỏng ESP8266!**

Cần dùng:
- Level shifter 3.3V ↔ 5V cho I2C
- Hoặc chia áp cho SDA/SCL

---

## Next Actions:

1. **NGAY LẬP TỨC:** Mở Serial Monitor Arduino Uno 1 và Uno 2
2. Paste output vào chat
3. Chụp ảnh dây nối I2C (nếu có thể)
4. Kiểm tra lại GND chung

Rất có thể là:
- ❌ Dây SDA/SCL nối sai chân
- ❌ Thiếu GND chung
- ❌ Arduino không được cấp nguồn đầy đủ
- ❌ Xung đột địa chỉ I2C
