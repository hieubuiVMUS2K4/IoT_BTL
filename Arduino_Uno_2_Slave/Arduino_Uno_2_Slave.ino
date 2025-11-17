/*
 * Arduino Uno 2 - Slave I2C (Address: 9)
 * Nhiệm vụ: Điều khiển RFID, HC-SR04, Servo, 2 Button
 * 
 * Kết nối phần cứng:
 * - Button 2 (mở cửa): A0
 * - Button 3 (đóng cửa): A1
 * - Servo: A2
 * - RFID RC522:
 *   + SDA: 10
 *   + SCK: 13
 *   + MOSI: 11
 *   + MISO: 12
 *   + RST: 9
 * - HC-SR04:
 *   + Trig: 4
 *   + Echo: 5
 * - I2C: A4 (SDA), A5 (SCL)
 */

#include <Wire.h>
#include <SPI.h>
#include <MFRC522.h>
#include <Servo.h>

// ===== CẤU HÌNH CHÂN =====
#define SLAVE_ADDRESS 9
#define BUTTON_OPEN_PIN A0
#define BUTTON_CLOSE_PIN A1
#define SERVO_PIN A2
#define RST_PIN 9
#define SS_PIN 10
#define TRIG_PIN 4
#define ECHO_PIN 5

// ===== CẤU HÌNH SERVO =====
Servo doorServo;
const int DOOR_CLOSED_ANGLE = 0;
const int DOOR_OPEN_ANGLE = 90;

// ===== CẤU HÌNH RFID =====
MFRC522 mfrc522(SS_PIN, RST_PIN);

// ===== THẺ RFID HỢP LỆ =====
// UID thẻ được cấp phép
byte validCard[4] = {0x96, 0x97, 0x03, 0x5F};  // 96 97 03 5F

// ===== BIẾN TRẠNG THÁI =====
bool doorOpen = false;
float distance = 0.0;
bool autoOpenTriggered = false;  // Đã kích hoạt mở cửa tự động
bool rfidAccessGranted = false;
unsigned long rfidGrantedTime = 0;  // Thời điểm quẹt thẻ
const unsigned long rfidDisplayDuration = 5000;  // Hiển thị RFID trong 5 giây

// ===== BIẾN BUTTON =====
bool lastButtonOpenState = HIGH;
bool lastButtonCloseState = HIGH;
bool currentButtonOpenState = HIGH;
bool currentButtonCloseState = HIGH;
unsigned long lastDebounceTimeOpen = 0;
unsigned long lastDebounceTimeClose = 0;
const unsigned long debounceDelay = 200;  // Tăng lên 200ms
unsigned long lastButtonOpenPressTime = 0;   // Chống spam
unsigned long lastButtonClosePressTime = 0;  // Chống spam

// ===== BIẾN QUẢN LÝ CHẾ ĐỘ =====
bool manualDoorMode = false;  // Chế độ điều khiển cửa thủ công
unsigned long manualDoorTimeout = 0;  // Thời gian hết hiệu lực điều khiển thủ công
const unsigned long manualTimeout = 30000;  // 30 giây timeout

// ===== BIẾN TỰ ĐỘNG ĐÓNG CỬA =====
bool autoCloseScheduled = false;  // Đã lên lịch tự động đóng cửa
unsigned long autoCloseTime = 0;   // Thời điểm tự động đóng cửa
const unsigned long autoCloseDelay = 5000;  // 5 giây - THỐNG NHẤT CHO TẤT CẢ
enum DoorSource { NONE, AUTO_SENSOR, MANUAL_BUTTON, WEB_COMMAND };
DoorSource lastDoorSource = NONE;  // Nguồn gốc mở cửa gần nhất

// ===== BUFFER DỮ LIỆU I2C =====
byte i2cBuffer[5];  // Chỉ cần 5 bytes
byte commandBuffer = 0;
volatile unsigned long requestCount = 0;  // Đếm số lần requestEvent được gọi

// ===== PROTOCOL I2C =====
// Command từ Master:
// 0x10: Mở cửa
// 0x11: Đóng cửa
// 0x12: Toggle cửa

void setup() {
  Serial.begin(9600);
  Serial.println(F("Uno2 Start"));
  
  Wire.begin(SLAVE_ADDRESS);
  Wire.onRequest(requestEvent);
  Wire.onReceive(receiveEvent);
  delay(100);
  
  // Khởi tạo chân
  pinMode(BUTTON_OPEN_PIN, INPUT_PULLUP);
  pinMode(BUTTON_CLOSE_PIN, INPUT_PULLUP);
  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);
  
  // Khởi tạo Servo
  doorServo.attach(SERVO_PIN);
  doorServo.write(DOOR_CLOSED_ANGLE);  // Đóng cửa ban đầu
  doorOpen = false;
  
  SPI.begin();
  mfrc522.PCD_Init();
  delay(50);
  Serial.println(F("OK"));
}

void loop() {
  static unsigned long lastDebug = 0;
  if (millis() - lastDebug > 5000) {
    Serial.print(F("I2C:"));
    Serial.println(requestCount);
    lastDebug = millis();
  }
  
  // ===== 1. XỬ LÝ BUTTON VẬT LÝ TRÊN BOARD =====
  // Button 2 (A0) - Mở cửa thủ công
  // Button 3 (A1) - Đóng cửa thủ công
  handleButtons();
  
  // ===== 2. XỬ LÝ RFID (TỰ ĐỘNG MỞ CỬA KHI QUẸT THẺ ĐÚNG) =====
  // Quẹt thẻ UID: 96 97 03 5F → Tự động mở cửa
  handleRFID();
  
  // ===== 3. ĐO KHOẢNG CÁCH HC-SR04 =====
  measureDistance();
  
  // ===== 4. TỰ ĐỘNG MỞ CỬA KHI PHÁT HIỆN NGƯỜI (< 10CM) =====
  autoOpenDoor();
  
  // ===== 5. TỰ ĐỘNG ĐÓNG CỬA SAU 5 GIÂY =====
  handleAutoClose();
  
  // ===== 6. XỬ LÝ LỆNH TỪ ESP8266 (ĐIỀU KHIỂN TỪ XA) =====
  processCommand();
  
  delay(100);
}

// ===== XỬ LÝ BUTTON VẬT LÝ =====
// Button 2 (A0): Nhấn để MỞ CỬA thủ công
// Button 3 (A1): Nhấn để ĐÓNG CỬA thủ công
// Dùng INPUT_PULLUP (nhấn = LOW)
void handleButtons() {
  if (manualDoorMode && (millis() - manualDoorTimeout > manualTimeout)) {
    manualDoorMode = false;
  }
  
  // ===== BUTTON 2: MỞ CỬA =====
  int readingOpen = digitalRead(BUTTON_OPEN_PIN);
  
  if (readingOpen != lastButtonOpenState) {
    lastDebounceTimeOpen = millis();
  }
  
  if ((millis() - lastDebounceTimeOpen) > debounceDelay) {
    if (readingOpen != currentButtonOpenState) {
      currentButtonOpenState = readingOpen;
      
      // Phát hiện cạnh xuống (nhấn): HIGH → LOW
      if (currentButtonOpenState == LOW) {
        if (millis() - lastButtonOpenPressTime >= 500) {
          lastButtonOpenPressTime = millis();
          openDoorWithAutoClose(autoCloseDelay, MANUAL_BUTTON);
          manualDoorMode = true;
          manualDoorTimeout = millis();
          Serial.println(F("Btn2:Open"));
        }
      }
    }
  }
  lastButtonOpenState = readingOpen;
  
  // ===== BUTTON 3: ĐÓNG CỬA =====
  int readingClose = digitalRead(BUTTON_CLOSE_PIN);
  
  if (readingClose != lastButtonCloseState) {
    lastDebounceTimeClose = millis();
  }
  
  if ((millis() - lastDebounceTimeClose) > debounceDelay) {
    if (readingClose != currentButtonCloseState) {
      currentButtonCloseState = readingClose;
      
      // Phát hiện cạnh xuống (nhấn): HIGH → LOW
      if (currentButtonCloseState == LOW) {
        if (millis() - lastButtonClosePressTime >= 500) {
          lastButtonClosePressTime = millis();
          closeDoor();
          autoCloseScheduled = false;  // Hủy auto-close
          manualDoorMode = true;
          manualDoorTimeout = millis();
          Serial.println(F("Btn3:Close"));
        }
      }
    }
  }
  lastButtonCloseState = readingClose;
}

// ===== XỬ LÝ RFID (TỰ ĐỘNG MỞ CỬA) =====
// Quẹt thẻ RFID đúng UID → TỰ ĐỘNG MỞ CỬA (CHỈ KHI KHÔNG Ở CHẾ ĐỘ MANUAL)
// UID hợp lệ: 96 97 03 5F
void handleRFID() {
  // Kiểm tra timeout - nếu quá 5s thì reset trạng thái
  if (rfidAccessGranted && (millis() - rfidGrantedTime > rfidDisplayDuration)) {
    rfidAccessGranted = false;
  }
  
  if (manualDoorMode) {
    return;  // Giữ nguyên trạng thái hiện tại, không reset
  }
  
  // Kiểm tra xem có thẻ mới không
  if (!mfrc522.PICC_IsNewCardPresent()) {
    return;  // Không reset rfidAccessGranted ở đây
  }
  
  // Đọc thẻ
  if (!mfrc522.PICC_ReadCardSerial()) {
    return;  // Không reset rfidAccessGranted ở đây
  }
  
  if (checkValidCard(mfrc522.uid.uidByte, mfrc522.uid.size)) {
    Serial.println(F("🔓 RFID: Thẻ hợp lệ - Mở cửa"));
    rfidAccessGranted = true;
    rfidGrantedTime = millis();  // Ghi lại thời điểm
    openDoorWithAutoClose(autoCloseDelay, AUTO_SENSOR);
  } else {
    Serial.println(F("❌ RFID: Thẻ không hợp lệ"));
    rfidAccessGranted = false;
  }
  
  // Halt PICC
  mfrc522.PICC_HaltA();
  mfrc522.PCD_StopCrypto1();
}

// ===== KIỂM TRA THẺ HỢP LỆ =====
bool checkValidCard(byte *cardUID, byte cardSize) {
  if (cardSize != 4) return false;
  
  for (byte i = 0; i < 4; i++) {
    if (cardUID[i] != validCard[i]) {
      return false;
    }
  }
  return true;
}

// ===== ĐO KHOẢNG CÁCH HC-SR04 =====
void measureDistance() {
  static unsigned long lastMeasure = 0;
  
  // Đo mỗi 200ms
  if (millis() - lastMeasure < 200) return;
  
  // Gửi xung trigger
  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);
  
  // Đọc xung echo
  long duration = pulseIn(ECHO_PIN, HIGH, 30000);  // Timeout 30ms
  
  // Tính khoảng cách (cm)
  if (duration > 0) {
    distance = duration * 0.034 / 2.0;
  } else {
    distance = 999.9;  // Không đo được
  }
  
  lastMeasure = millis();
}

// ===== PHÁT HIỆN ĐỘT NHẬP (TỰ ĐỘNG CẢNH BÁO) =====
// Nếu khoảng cách < 50cm VÀ cửa đang đóng → CẢNH BÁO ĐỘT NHẬP
// ===== TỰ ĐỘNG MỞ CỬA KHI PHÁT HIỆN NGƯỜI =====
// Nếu khoảng cách < 10cm (người đến gần) → TỰ ĐỘNG MỞ CỬA
// Chỉ hoạt động khi không ở chế độ manual
void autoOpenDoor() {
  // Nếu đang manual mode, bỏ qua tự động mở cửa
  if (manualDoorMode) {
    autoOpenTriggered = false;
    return;
  }
  
  // Điều kiện: Khoảng cách < 10cm (người đến rất gần)
  if (distance < 10.0 && distance > 0) {
    if (!autoOpenTriggered) {
      autoOpenTriggered = true;
      openDoorWithAutoClose(autoCloseDelay, AUTO_SENSOR);
      Serial.println(F("AutoOpen:10cm"));
    }
  } else {
    // Khi người đi xa (> 10cm), reset flag
    autoOpenTriggered = false;
  }
}

// ===== TỰ ĐỘNG ĐÓNG CỬA =====
void handleAutoClose() {
  // Nếu vào manual mode từ web, HỦY lịch đóng tự động từ sensor
  if (manualDoorMode && autoCloseScheduled && lastDoorSource == AUTO_SENSOR) {
    autoCloseScheduled = false;
    Serial.println(F("AutoClose:Canceled"));
    return;
  }
  
  // Nếu đã lên lịch đóng cửa và đã đến thời điểm
  if (autoCloseScheduled && millis() >= autoCloseTime) {
    closeDoor();
    Serial.println(F("AutoClose:Done"));
    autoCloseScheduled = false;
    lastDoorSource = NONE;
  }
}

// ===== MỞ CỬA =====
void openDoor() {
  if (!doorOpen) {
    doorServo.write(DOOR_OPEN_ANGLE);
    doorOpen = true;
    delay(500);
  }
}

// ===== MỞ CỬA VỚI AUTO-CLOSE (cho sensor) =====
void openDoorWithAutoClose(unsigned long closeDelay, DoorSource source) {
  openDoor();
  
  // CHỈ lên lịch nếu CHƯA có lịch, tránh ghi đè
  if (!autoCloseScheduled) {
    autoCloseScheduled = true;
    autoCloseTime = millis() + closeDelay;
    lastDoorSource = source;
  }
}

// ===== ĐÓNG CỬA =====
void closeDoor() {
  if (doorOpen) {
    doorServo.write(DOOR_CLOSED_ANGLE);
    doorOpen = false;
    delay(500);
  }
}

// ===== XỬ LÝ LỆNH TỪ MASTER =====
void processCommand() {
  if (commandBuffer == 0) return;
  
  switch (commandBuffer) {
    case 0x10:  // Mở cửa từ web - KHÔNG auto-close
      openDoor();
      autoCloseScheduled = false;  // Hủy auto-close
      lastDoorSource = WEB_COMMAND;
      manualDoorMode = true;
      manualDoorTimeout = millis();
      break;
    case 0x11:  // Đóng cửa từ web
      closeDoor();
      autoCloseScheduled = false;  // Hủy auto-close
      manualDoorMode = true;
      manualDoorTimeout = millis();
      break;
    case 0x12:  // Toggle từ web
      if (doorOpen) closeDoor();
      else openDoor();
      autoCloseScheduled = false;  // Hủy auto-close
      lastDoorSource = WEB_COMMAND;
      manualDoorMode = true;
      manualDoorTimeout = millis();
      break;
  }
  commandBuffer = 0;
}

// ===== I2C REQUEST EVENT =====
// Master yêu cầu dữ liệu
void requestEvent() {
  requestCount++;
  
  i2cBuffer[0] = doorOpen ? 1 : 0;
  i2cBuffer[1] = autoOpenTriggered ? 1 : 0;  // Gửi trạng thái auto-open
  i2cBuffer[2] = rfidAccessGranted ? 1 : 0;
  
  int16_t distInt = (int16_t)(distance * 10);
  i2cBuffer[3] = (distInt >> 8) & 0xFF;
  i2cBuffer[4] = distInt & 0xFF;
  
  Wire.write(i2cBuffer, 5);
}

// ===== I2C RECEIVE EVENT =====
// Master gửi lệnh
void receiveEvent(int byteCount) {
  if (byteCount > 0) {
    commandBuffer = Wire.read();
    while (Wire.available()) Wire.read();
  }
}
