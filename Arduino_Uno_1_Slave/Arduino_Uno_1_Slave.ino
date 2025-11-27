/*
 * Arduino Uno 1 - Slave I2C (Address: 8)
 * Nhiệm vụ: Điều khiển PIR, DHT, 2 LED, 1 Button
 * 
 * Kết nối phần cứng:
 * - PIR Sensor: chân 2
 * - DHT Sensor: chân 3
 * - LED 1 (điều khiển bởi PIR): chân 11
 * - LED 2 (điều khiển bởi Button): chân 10
 * - Button 1: chân 12 (INPUT_PULLUP)
 * - I2C: A4 (SDA), A5 (SCL)
 */

#include <Wire.h>
#include <DHT.h>

// ===== CẤU HÌNH CHÂN =====
#define SLAVE_ADDRESS 8
#define PIR_PIN 2
#define DHT_PIN 3
#define LED_PIR_PIN 11
#define LED_BUTTON_PIN 10
#define BUTTON_PIN 12

// ===== CẤU HÌNH QUẠT L298N =====
#define FAN_ENA_PIN 6    // PWM cho tốc độ quạt
#define FAN_IN1_PIN 7    // Hướng quay 1
#define FAN_IN2_PIN 8    // Hướng quay 2

// ===== CẤU HÌNH DHT =====
#define DHTTYPE DHT11  // Hoặc DHT22
DHT dht(DHT_PIN, DHTTYPE);

// ===== BIẾN TRẠNG THÁI =====
bool pirState = false;
bool led1State = false;  // LED PIR
bool led2State = false;  // LED Button
float temperature = 0.0;
float humidity = 0.0;

// ===== BIẾN QUẠT =====
bool fanState = false;           // Trạng thái quạt (bật/tắt)
bool fanAutoMode = true;         // Chế độ tự động theo nhiệt độ
int fanSpeed = 255;              // Tốc độ quạt (0-255)
const float TEMP_THRESHOLD = 30.0;  // Ngưỡng nhiệt độ 30°C
unsigned long fanManualTimeout = 0;
const unsigned long fanManualDuration = 60000;  // 60s manual mode

// ===== BIẾN BUTTON =====
bool lastButtonState = HIGH;
bool currentButtonState = HIGH;
unsigned long lastDebounceTime = 0;
const unsigned long debounceDelay = 200;  // Tăng lên 200ms để chống dội tốt hơn
unsigned long lastButtonPressTime = 0;   // Chống spam

// ===== BIẾN PIR TIMEOUT =====
unsigned long pirLastTriggerTime = 0;
const unsigned long pirTimeout = 7000;  // 7 giây timeout

// ===== BIẾN QUẢN LÝ CHẾ ĐỘ =====
// Chỉ có LED 2 mới có manual mode (điều khiển từ web/button)
// LED 1 HOÀN TOÀN tự động bởi PIR, không có manual mode
bool manualLED2Mode = false;  // Chế độ điều khiển LED 2 thủ công
unsigned long manualLED2Timeout = 0;  // Thời gian hết hiệu lực điều khiển thủ công LED 2
const unsigned long manualTimeout = 30000;  // 30 giây timeout cho lệnh thủ công

// ===== BUFFER DỮ LIỆU I2C =====
byte i2cBuffer[10];
byte commandBuffer = 0;
volatile unsigned long requestCount = 0;  // Đếm số lần requestEvent được gọi

// ===== PROTOCOL I2C =====
// Command từ Master:
// 0x01: Bật LED 2
// 0x02: Tắt LED 2
// 0x03: Toggle LED 2
// 0x07: Bật quạt (manual) - FIXED từ 0x04 tránh xung đột LED1
// 0x08: Tắt quạt (manual) - FIXED từ 0x05
// 0x09: Toggle quạt - FIXED từ 0x06
// (LED 1 KHÔNG có lệnh điều khiển - chỉ tự động bởi PIR)

void setup() {
  // Khởi tạo Serial (debug)
  Serial.begin(9600);
  Serial.println("Arduino Uno 1 - Slave I2C Started");
  
  // KHỞI TẠO I2C TRƯỚC TIÊN (quan trọng!)
  Wire.begin(SLAVE_ADDRESS);
  Wire.onRequest(requestEvent);   // Khi Master yêu cầu dữ liệu
  Wire.onReceive(receiveEvent);   // Khi Master gửi lệnh
  Serial.println("I2C Slave initialized at address: " + String(SLAVE_ADDRESS));
  delay(100);  // Delay để I2C ổn định
  
  // Khởi tạo chân
  pinMode(PIR_PIN, INPUT);
  pinMode(LED_PIR_PIN, OUTPUT);
  pinMode(LED_BUTTON_PIN, OUTPUT);
  pinMode(BUTTON_PIN, INPUT_PULLUP);
  
  // Khởi tạo chân quạt L298N
  pinMode(FAN_ENA_PIN, OUTPUT);
  pinMode(FAN_IN1_PIN, OUTPUT);
  pinMode(FAN_IN2_PIN, OUTPUT);
  
  // Tắt LED ban đầu
  digitalWrite(LED_PIR_PIN, LOW);
  digitalWrite(LED_BUTTON_PIN, LOW);
  
  // Tắt quạt ban đầu
  digitalWrite(FAN_IN1_PIN, LOW);
  digitalWrite(FAN_IN2_PIN, LOW);
  analogWrite(FAN_ENA_PIN, 0);
  
  // Khởi tạo DHT
  dht.begin();
  delay(50);
  
  Serial.println("=== All systems ready ===");
  Serial.println("Waiting for I2C requests from ESP8266...");
}

void loop() {
  // ===== DEBUG: Hiển thị số lần I2C request =====
  static unsigned long lastRequestCount = 0;
  static unsigned long lastDebug = 0;
  
  if (millis() - lastDebug > 3000) {  // Mỗi 3 giây
    if (requestCount > lastRequestCount) {
      Serial.print("✓ I2C requests received: ");
      Serial.println(requestCount);
      lastRequestCount = requestCount;
    } else {
      Serial.println("✗ WARNING: No I2C requests from ESP8266!");
    }
    lastDebug = millis();
  }
  
  // ===== 1. XỬ LÝ BUTTON VẬT LÝ TRÊN BOARD =====
  // Button 1 (chân 12) - Bật/tắt LED 2 (toggle)
  handleButton();
  
  // ===== 2. XỬ LÝ CẢM BIẾN PIR (TỰ ĐỘNG BẬT LED 1) =====
  // Khi phát hiện chuyển động → LED 1 tự động BẬT
  // Không có chuyển động > 7s → LED 1 tự động TẮT
  handlePIR();
  
  // ===== 3. ĐỌC CẢM BIẾN NHIỆT ẨM DHT =====
  readDHT();
  
  // ===== 4. XỨ LÝ QUẠT TỰ ĐỘNG THEO NHIỆT ĐỘ =====
  handleFan();
  
  // ===== 5. XỨ LÝ LỆNH TỪ ESP8266 (ĐIỀU KHIỂN TỪ XA) =====
  processCommand();
  
  delay(100);  // Delay nhỏ để tránh quá tải
}

// ===== XỬ LÝ BUTTON VẬT LÝ =====
// Button 1 (chân 12): Nhấn để TOGGLE (đảo) trạng thái LED 2
// Dùng INPUT_PULLUP nên:
//   - Không nhấn: chân đọc HIGH (do pull-up kéo lên 5V)
//   - Nhấn: chân đọc LOW (nối xuống GND)
void handleButton() {
  // ===== KIỂM TRA MANUAL MODE TIMEOUT LED 2 =====
  if (manualLED2Mode && (millis() - manualLED2Timeout > manualTimeout)) {
    manualLED2Mode = false;
    Serial.println("⏰ LED 2 manual mode EXPIRED → Back to normal");
  }
  
  int reading = digitalRead(BUTTON_PIN);
  
  // DEBUG: In trạng thái button mỗi khi thay đổi
  static int lastReading = HIGH;
  if (reading != lastReading) {
    Serial.print("🔍 Button raw state: ");
    Serial.println(reading == LOW ? "PRESSED (LOW)" : "RELEASED (HIGH)");
    lastReading = reading;
  }
  
  // Debounce: Chống nhiễu khi nhấn nút
  if (reading != lastButtonState) {
    lastDebounceTime = millis();
    Serial.println("⏱ Debounce timer reset");
  }
  
  // Chờ đủ thời gian debounce (200ms)
  if ((millis() - lastDebounceTime) > debounceDelay) {
    // Nếu trạng thái đã ổn định và thay đổi
    if (reading != currentButtonState) {
      currentButtonState = reading;
      Serial.print("✓ Button state confirmed: ");
      Serial.println(currentButtonState == LOW ? "PRESSED" : "RELEASED");
      
      // Phát hiện cạnh xuống (nhấn button): HIGH → LOW
      // LOW vì dùng INPUT_PULLUP (nhấn = nối GND = LOW)
      if (currentButtonState == LOW) {
        // Chống spam: Chỉ cho phép nhấn sau 500ms từ lần trước
        if (millis() - lastButtonPressTime < 500) {
          Serial.println("⚠ Button press ignored (too fast)");
          lastButtonState = reading;
          return;
        }
        lastButtonPressTime = millis();
        
        // TOGGLE: Đảo trạng thái LED 2
        led2State = !led2State;
        digitalWrite(LED_BUTTON_PIN, led2State ? HIGH : LOW);
        
        // Button vật lý CŨNG vào manual mode (ưu tiên user)
        manualLED2Mode = true;
        manualLED2Timeout = millis();
        
        Serial.println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        Serial.print("🔘 BUTTON PHYSICAL: LED 2 ");
        Serial.println(led2State ? "ON ✓" : "OFF ✗");
        Serial.println("   → Manual mode 30s");
        Serial.println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
      }
    }
  }
  
  lastButtonState = reading;
}

// ===== XỬ LÝ CẢM BIẾN PIR (TỰ ĐỘNG ĐIỀU KHIỂN LED 1) =====
// PIR phát hiện chuyển động → TỰ ĐỘNG BẬT LED 1
// Không có chuyển động > 7 giây → TỰ ĐỘNG TẮT LED 1
// LED 1 HOÀN TOÀN tự động, KHÔNG CÓ manual mode
void handlePIR() {
  static bool lastPirValue = LOW;
  static unsigned long pirDebounceTime = 0;
  const unsigned long pirDebounceDelay = 100; // 100ms debounce cho PIR
  
  int reading = digitalRead(PIR_PIN);
  
  // Debounce PIR
  if (reading != lastPirValue) {
    pirDebounceTime = millis();
  }
  
  if ((millis() - pirDebounceTime) > pirDebounceDelay) {
    // Giá trị ổn định sau debounce
    // ĐẢO NGƯỢC LOGIC: LOW = có người, HIGH = không có người
    if (reading == LOW) {
      // 👤 PHÁT HIỆN CHUYỂN ĐỘNG!
      if (!pirState) {
        pirState = true;
        led1State = true;
        digitalWrite(LED_PIR_PIN, HIGH);
        Serial.println("👤 PIR AUTO: Motion detected → LED 1 ON");
      }
      // Reset timer mỗi khi còn chuyển động
      pirLastTriggerTime = millis();
      
    } else {
      // PIR = HIGH (không phát hiện chuyển động)
      // Kiểm tra đã quá timeout chưa
      if (pirState && (millis() - pirLastTriggerTime > pirTimeout)) {
        pirState = false;
        led1State = false;
        digitalWrite(LED_PIR_PIN, LOW);
        Serial.println("💤 PIR AUTO: No motion for 7s → LED 1 OFF");
      }
    }
  }
  
  lastPirValue = reading;
}

// ===== XỨ LÝ QUẠT TỰ ĐỘNG =====
// Tự động bật quạt khi nhiệt độ > 30°C
// Manual mode có thời hạn 60 giây
void handleFan() {
  // Kiểm tra manual mode timeout
  if (!fanAutoMode && (millis() - fanManualTimeout > fanManualDuration)) {
    fanAutoMode = true;
    Serial.println("⏰ Fan: Back to AUTO mode");
  }
  
  // Chế độ tự động
  if (fanAutoMode) {
    if (temperature >= TEMP_THRESHOLD && !fanState) {
      // Nhiệt độ cao, bật quạt
      turnOnFan();
      Serial.print("🌡️ AUTO FAN ON: Temp=");
      Serial.print(temperature);
      Serial.println("°C");
    } else if (temperature < (TEMP_THRESHOLD - 2.0) && fanState) {
      // Nhiệt độ giảm (hysteresis 2°C), tắt quạt
      turnOffFan();
      Serial.print("❄️ AUTO FAN OFF: Temp=");
      Serial.print(temperature);
      Serial.println("°C");
    }
  }
}

// ===== BẬT QUẠT =====
void turnOnFan() {
  fanState = true;
  
  // CRITICAL: Set direction FIRST, then enable PWM
  digitalWrite(FAN_IN1_PIN, HIGH);
  digitalWrite(FAN_IN2_PIN, LOW);
  delay(10);  // Short delay to stabilize
  
  // Use direct 255 value (full speed)
  analogWrite(FAN_ENA_PIN, 255);
  
  // DEBUG: Kiểm tra trạng thái các chân
  Serial.println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  Serial.println("🔧 FAN ON DEBUG:");
  Serial.println("   ENA (D6) PWM: 255 (FULL SPEED)");
  Serial.print("   IN1 (D7): ");
  Serial.println(digitalRead(FAN_IN1_PIN) ? "HIGH" : "LOW");
  Serial.print("   IN2 (D8): ");
  Serial.println(digitalRead(FAN_IN2_PIN) ? "HIGH" : "LOW");
  Serial.println("   ⚠️ CHECK: L298N ENA jumper REMOVED?");
  Serial.println("   ⚠️ CHECK: 12V power to L298N?");
  Serial.println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
}

// ===== TẮT QUẠT =====
void turnOffFan() {
  fanState = false;
  // FIXED: Set hướng = LOW trước để tránh quạt giật
  digitalWrite(FAN_IN1_PIN, LOW);
  digitalWrite(FAN_IN2_PIN, LOW);
  analogWrite(FAN_ENA_PIN, 0);  // Tắt PWM sau cùng
  
  Serial.println("⚫ FAN OFF - All pins set to LOW/0");
}

// ===== ĐỌC CẢM BIẾN DHT =====
void readDHT() {
  static unsigned long lastRead = 0;
  static float lastValidTemp = 25.0;  // FIXED: Lưu giá trị hợp lệ trước đó
  static float lastValidHum = 50.0;
  
  // Đọc DHT mỗi 2 giây
  if (millis() - lastRead > 2000) {
    float h = dht.readHumidity();
    float t = dht.readTemperature();
    
    // FIXED: Chống nhiễu - chỉ cập nhật nếu hợp lệ và thay đổi > 0.5°C
    if (!isnan(h) && !isnan(t) && t > 0 && t < 100 && h > 0 && h < 100) {
      // Chỉ cập nhật nếu thay đổi đáng kể (tránh nhiễu nhỏ)
      if (abs(t - lastValidTemp) > 0.5 || abs(h - lastValidHum) > 1.0) {
        humidity = h;
        temperature = t;
        lastValidTemp = t;
        lastValidHum = h;
        Serial.print("Temp: ");
        Serial.print(temperature);
        Serial.print("°C, Humidity: ");
        Serial.print(humidity);
        Serial.println("%");
      }
    } else {
      Serial.println("⚠ DHT read error - using last valid value");
      // Giữ nguyên giá trị cũ, không cập nhật
    }
    
    lastRead = millis();
  }
}

// ===== XỬ LÝ LỆNH TỪ MASTER =====
void processCommand() {
  if (commandBuffer == 0) return;
  
  Serial.print("🌐 Processing WEB command: 0x");
  Serial.println(commandBuffer, HEX);
  
  switch (commandBuffer) {
    case 0x01:  // Bật LED 2
      led2State = true;
      digitalWrite(LED_BUTTON_PIN, HIGH);
      manualLED2Mode = true;
      manualLED2Timeout = millis();
      Serial.println("🌐 WEB: LED 2 ON (manual mode 30s)");
      break;
      
    case 0x02:  // Tắt LED 2
      led2State = false;
      digitalWrite(LED_BUTTON_PIN, LOW);
      manualLED2Mode = true;
      manualLED2Timeout = millis();
      Serial.println("🌐 WEB: LED 2 OFF (manual mode 30s)");
      break;
      
    case 0x03:  // Toggle LED 2
      led2State = !led2State;
      digitalWrite(LED_BUTTON_PIN, led2State ? HIGH : LOW);
      manualLED2Mode = true;
      manualLED2Timeout = millis();
      Serial.println("🌐 WEB: LED 2 TOGGLE (manual mode 30s)");
      break;
    
    case 0x07:  // Bật quạt (manual) - FIXED từ 0x04
      fanAutoMode = false;
      fanManualTimeout = millis();
      turnOnFan();
      Serial.println("🌐 WEB: FAN ON (manual 60s)");
      break;
    
    case 0x08:  // Tắt quạt (manual) - FIXED từ 0x05
      fanAutoMode = false;
      fanManualTimeout = millis();
      turnOffFan();
      Serial.println("🌐 WEB: FAN OFF (manual 60s)");
      break;
    
    case 0x09:  // Toggle quạt - FIXED từ 0x06
      fanAutoMode = false;
      fanManualTimeout = millis();
      if (fanState) turnOffFan();
      else turnOnFan();
      Serial.println("🌐 WEB: FAN TOGGLE (manual 60s)");
      break;
      
   
      
    default:
      Serial.print("⚠️ Unknown command: 0x");
      Serial.println(commandBuffer, HEX);
      break;
  }
  
  commandBuffer = 0;  // Clear command
}

// ===== I2C REQUEST EVENT =====
// Master yêu cầu dữ liệu
void requestEvent() {
  requestCount++;  // Đếm số lần được gọi
  
  // KHÔNG DÙNG Serial.println trong interrupt!
  
  i2cBuffer[0] = pirState ? 1 : 0;
  i2cBuffer[1] = led1State ? 1 : 0;
  i2cBuffer[2] = led2State ? 1 : 0;
  
  int16_t tempInt = (int16_t)(temperature * 10);
  int16_t humInt = (int16_t)(humidity * 10);
  
  i2cBuffer[3] = (tempInt >> 8) & 0xFF;
  i2cBuffer[4] = tempInt & 0xFF;
  i2cBuffer[5] = (humInt >> 8) & 0xFF;
  i2cBuffer[6] = humInt & 0xFF;
  
  // Thêm trạng thái quạt
  i2cBuffer[7] = fanState ? 1 : 0;
  i2cBuffer[8] = fanAutoMode ? 1 : 0;
  
  Wire.write(i2cBuffer, 9);  // Gửi 9 bytes (thêm 2 bytes quạt)
}

// ===== I2C RECEIVE EVENT =====
// Master gửi lệnh
void receiveEvent(int byteCount) {
  if (byteCount > 0) {
    commandBuffer = Wire.read();
    
    // Đọc hết dữ liệu còn lại (nếu có)
    while (Wire.available()) {
      Wire.read();
    }
    
    Serial.print("Received command: 0x");
    Serial.println(commandBuffer, HEX);
  }
}
