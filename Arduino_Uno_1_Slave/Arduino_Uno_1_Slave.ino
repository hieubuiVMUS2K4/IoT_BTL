/*
 * Arduino Uno 1 - Slave UART (SoftwareSerial)
 * Nhiệm vụ: Điều khiển PIR, DHT, 2 LED, 1 Button
 * 
 * Kết nối phần cứng:
 * - PIR Sensor: chân 2
 * - DHT Sensor: chân 3
 * - LED 1 (điều khiển bởi PIR): chân 11
 * - LED 2 (điều khiển bởi Button): chân 10
 * - Button 1: chân 12 (INPUT_PULLUP)
 * - UART Software: Pin 4 (RX), Pin 5 (TX) <--> ESP8266 D2 (TX), D1 (RX)
 */

#include <SoftwareSerial.h>
#include <DHT.h>

// ===== CẤU HÌNH CHÂN =====
#define RX_PIN 4
#define TX_PIN 5
#define PIR_PIN 2
#define DHT_PIN 3
#define LED_PIR_PIN 11
#define LED_BUTTON_PIN 10
#define BUTTON_PIN 12

// ===== CẤU HÌNH UART =====
SoftwareSerial mySerial(RX_PIN, TX_PIN);

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
const float TEMP_THRESHOLD = 30;  // Ngưỡng nhiệt độ 30°C
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

// ===== BUFFER DỮ LIỆU =====
byte dataBuffer[10];
byte commandBuffer = 0;

// ===== CHẾ ĐỘ AN NINH =====
bool securityModeActive = false;
unsigned long lastSecurityBlinkTime = 0;
bool securityLEDState = false;
const unsigned long securityBlinkInterval = 300;  // Nhấp nháy 300ms

// ===== PROTOCOL =====
// Command từ Master:
// 'R': Request data
// 'C': Command prefix -> Next byte is command code
// 0x01: Bật LED 2
// 0x02: Tắt LED 2
// 0x03: Toggle LED 2
// 0x07: Bật quạt (manual)
// 0x08: Tắt quạt (manual)
// 0x09: Toggle quạt
// 0x20: Bật Security Mode
// 0x21: Tắt Security Mode

void setup() {
  // Khởi tạo Serial (debug)
  Serial.begin(9600);
  Serial.println("Arduino Uno 1 - Slave UART Started");
  
  // KHỞI TẠO UART SOFTWARE
  mySerial.begin(9600);
  Serial.println("SoftwareSerial initialized on pins 4(RX), 5(TX)");
  
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
}

void loop() {
  // ===== XỬ LÝ UART =====
  handleUART();
  
  // ===== 1. XỬ LÝ BUTTON VẬT LÝ TRÊN BOARD =====
  handleButton();
  
  // ===== 2. XỬ LÝ CẢM BIẾN PIR (TỰ ĐỘNG BẬT LED 1) =====
  handlePIR();
  
  // ===== 3. ĐỌC CẢM BIẾN NHIỆT ẨM DHT =====
  readDHT();
  
  // ===== 4. XỨ LÝ QUẠT TỰ ĐỘNG THEO NHIỆT ĐỘ =====
  handleFan();
  
  // ===== 5. XỬ LÝ CHẾ ĐỘ AN NINH =====
  handleSecurityMode();
  
  // ===== 6. XỬ LÝ LỆNH TỪ ESP8266 (ĐIỀU KHIỂN TỪ XA) =====
  processCommand();
  
  delay(10);  // Delay nhỏ
}

// ===== XỬ LÝ UART =====
void handleUART() {
  if (mySerial.available()) {
    char c = mySerial.read();
    
    if (c == 'R') {
      // Master yêu cầu dữ liệu
      sendData();
    } else if (c == 'C') {
      // Master gửi lệnh, đợi byte tiếp theo
      unsigned long timeout = millis();
      while (!mySerial.available() && (millis() - timeout < 100));
      
      if (mySerial.available()) {
        commandBuffer = mySerial.read();
        Serial.print("Received command: 0x");
        Serial.println(commandBuffer, HEX);
      }
    }
  }
}

// ===== GỬI DỮ LIỆU =====
void sendData() {
  dataBuffer[0] = pirState ? 1 : 0;
  dataBuffer[1] = led1State ? 1 : 0;
  dataBuffer[2] = led2State ? 1 : 0;
  
  int16_t tempInt = (int16_t)(temperature * 10);
  int16_t humInt = (int16_t)(humidity * 10);
  
  dataBuffer[3] = (tempInt >> 8) & 0xFF;
  dataBuffer[4] = tempInt & 0xFF;
  dataBuffer[5] = (humInt >> 8) & 0xFF;
  dataBuffer[6] = humInt & 0xFF;
  
  // Thêm trạng thái quạt
  dataBuffer[7] = fanState ? 1 : 0;
  dataBuffer[8] = fanAutoMode ? 1 : 0;
  
  mySerial.write(dataBuffer, 9);
  Serial.println("Sent 9 bytes to Master");
}

// ===== XỬ LÝ BUTTON VẬT LÝ =====
// Button 1 (chân 12): Nhấn để TOGGLE (đảo) trạng thái LED 2
// Dùng INPUT_PULLUP nên:
//   - Không nhấn: chân đọc HIGH (do pull-up kéo lên 5V)
//   - Nhấn: chân đọc LOW (nối xuống GND)
// QUAN TRỌNG: Không hoạt động khi Security Mode bật
void handleButton() {
  // Không cho phép button khi security mode
  if (securityModeActive) return;
  
  // ===== KIỂM TRA MANUAL MODE TIMEOUT LED 2 =====
  if (manualLED2Mode && (millis() - manualLED2Timeout > manualTimeout)) {
    manualLED2Mode = false;
    Serial.println("⏰ LED 2 manual mode EXPIRED → Back to normal");
  }
  
  int reading = digitalRead(BUTTON_PIN);
  
  // Debounce: Chống nhiễu khi nhấn nút
  if (reading != lastButtonState) {
    lastDebounceTime = millis();
  }
  
  // Chờ đủ thời gian debounce (200ms)
  if ((millis() - lastDebounceTime) > debounceDelay) {
    // Nếu trạng thái đã ổn định và thay đổi
    if (reading != currentButtonState) {
      currentButtonState = reading;
      
      // Phát hiện cạnh xuống (nhấn button): HIGH → LOW
      if (currentButtonState == LOW) {
        // Chống spam: Chỉ cho phép nhấn sau 500ms từ lần trước
        if (millis() - lastButtonPressTime < 500) {
          return;
        }
        lastButtonPressTime = millis();
        
        // TOGGLE: Đảo trạng thái LED 2
        led2State = !led2State;
        digitalWrite(LED_BUTTON_PIN, led2State ? HIGH : LOW);
        
        // Button vật lý CŨNG vào manual mode (ưu tiên user)
        manualLED2Mode = true;
        manualLED2Timeout = millis();
        
        Serial.println("🔘 BUTTON PHYSICAL: LED 2 TOGGLE");
      }
    }
  }
  
  lastButtonState = reading;
}

// ===== XỬ LÝ CẢM BIẾN PIR (TỰ ĐỘNG ĐIỀU KHIỂN LED 1) =====
// PIR phát hiện chuyển động → TỰ ĐỘNG BẬT LED 1
// Không có chuyển động > 7 giây → TỰ ĐỘNG TẮT LED 1
// LED 1 HOÀN TOÀN tự động, KHÔNG CÓ manual mode
// QUAN TRỌNG: Không điều khiển LED khi Security Mode bật (để nhấp nháy)
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
        // Chỉ bật LED nếu KHÔNG ở security mode
        if (!securityModeActive) {
          digitalWrite(LED_PIR_PIN, HIGH);
        }
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
        // Chỉ tắt LED nếu KHÔNG ở security mode
        if (!securityModeActive) {
          digitalWrite(LED_PIR_PIN, LOW);
        }
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
}

// ===== TẮT QUẠT =====
void turnOffFan() {
  fanState = false;
  // FIXED: Set hướng = LOW trước để tránh quạt giật
  digitalWrite(FAN_IN1_PIN, LOW);
  digitalWrite(FAN_IN2_PIN, LOW);
  analogWrite(FAN_ENA_PIN, 0);  // Tắt PWM sau cùng
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
      if (!securityModeActive) {  // Không cho phép điều khiển khi security mode
        led2State = true;
        digitalWrite(LED_BUTTON_PIN, HIGH);
        manualLED2Mode = true;
        manualLED2Timeout = millis();
        Serial.println("🌐 WEB: LED 2 ON (manual mode 30s)");
      } else {
        Serial.println("⚠️ Cannot control LED2: Security mode active");
      }
      break;
      
    case 0x02:  // Tắt LED 2
      if (!securityModeActive) {
        led2State = false;
        digitalWrite(LED_BUTTON_PIN, LOW);
        manualLED2Mode = true;
        manualLED2Timeout = millis();
        Serial.println("🌐 WEB: LED 2 OFF (manual mode 30s)");
      } else {
        Serial.println("⚠️ Cannot control LED2: Security mode active");
      }
      break;
      
    case 0x03:  // Toggle LED 2
      if (!securityModeActive) {
        led2State = !led2State;
        digitalWrite(LED_BUTTON_PIN, led2State ? HIGH : LOW);
        manualLED2Mode = true;
        manualLED2Timeout = millis();
        Serial.println("🌐 WEB: LED 2 TOGGLE (manual mode 30s)");
      } else {
        Serial.println("⚠️ Cannot control LED2: Security mode active");
      }
      break;
    
    case 0x07:  // Bật quạt (manual)
      fanAutoMode = false;
      fanManualTimeout = millis();
      turnOnFan();
      Serial.println("🌐 WEB: FAN ON (manual 60s)");
      break;
    
    case 0x08:  // Tắt quạt (manual)
      fanAutoMode = false;
      fanManualTimeout = millis();
      turnOffFan();
      Serial.println("🌐 WEB: FAN OFF (manual 60s)");
      break;
    
    case 0x09:  // Toggle quạt
      fanAutoMode = false;
      fanManualTimeout = millis();
      if (fanState) turnOffFan();
      else turnOnFan();
      Serial.println("🌐 WEB: FAN TOGGLE (manual 60s)");
      break;
    
    case 0x20:  // Bật Security Mode
      securityModeActive = true;
      Serial.println("🔒 SECURITY MODE: ON");
      break;
    
    case 0x21:  // Tắt Security Mode
      securityModeActive = false;
      securityLEDState = false;
      // Khôi phục trạng thái LED theo logic thực
      digitalWrite(LED_PIR_PIN, led1State ? HIGH : LOW);
      digitalWrite(LED_BUTTON_PIN, led2State ? HIGH : LOW);
      Serial.println("🔓 SECURITY MODE: OFF");
      break;
      
    default:
      Serial.print("⚠️ Unknown command: 0x");
      Serial.println(commandBuffer, HEX);
      break;
  }
  
  commandBuffer = 0;  // Clear command
}

// ===== XỬ LÝ CHẾ ĐỘ AN NINH =====
void handleSecurityMode() {
  if (!securityModeActive) return;
  
  // Nhấp nháy LED khi security mode bật
  if (millis() - lastSecurityBlinkTime >= securityBlinkInterval) {
    securityLEDState = !securityLEDState;
    
    // Nhấp nháy cả 2 LED
    digitalWrite(LED_PIR_PIN, securityLEDState ? HIGH : LOW);
    digitalWrite(LED_BUTTON_PIN, securityLEDState ? HIGH : LOW);
    
    lastSecurityBlinkTime = millis();
  }
}
