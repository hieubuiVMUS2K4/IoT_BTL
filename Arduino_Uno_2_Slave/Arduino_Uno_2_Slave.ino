/*
 * Arduino Uno 2 - Slave UART (SoftwareSerial)
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
 * - UART Software: Pin 2 (RX), Pin 3 (TX) <--> ESP8266 D6 (TX), D5 (RX)
 */

#include <SoftwareSerial.h>
#include <SPI.h>
#include <MFRC522.h>
#include <Servo.h>

// ===== CẤU HÌNH CHÂN =====
#define RX_PIN 2
#define TX_PIN 3
#define BUTTON_OPEN_PIN A0
#define BUTTON_CLOSE_PIN A1
#define SERVO_PIN 6  // Đổi sang D6 (PWM)
#define RST_PIN 9
#define SS_PIN 10
#define TRIG_PIN 4
#define ECHO_PIN 5

// ===== CẤU HÌNH UART =====
SoftwareSerial mySerial(RX_PIN, TX_PIN);

// ===== CẤU HÌNH SERVO =====
Servo doorServo;
const int DOOR_CLOSED_ANGLE = 0;   // Cửa đóng
const int DOOR_OPEN_ANGLE = 90;   // Cửa mở (tăng từ 90 lên 180 để đủ lực)
bool servoMoving = false;
int currentServoAngle = 0;
int targetServoAngle = 0;
unsigned long lastServoMoveTime = 0;
const int SERVO_STEP_DELAY = 20;  // ms giữa mỗi bước (tăng từ 15 lên 20)

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
bool securityModeActive = false;  // Chế độ an ninh (khi bật thì không mở cửa tự động)

// ===== BIẾN TỰ ĐỘNG ĐÓNG CỬA =====
bool autoCloseScheduled = false;  // Đã lên lịch tự động đóng cửa
unsigned long autoCloseTime = 0;   // Thời điểm tự động đóng cửa
const unsigned long autoCloseDelay = 5000;  // 5 giây - THỐNG NHẤT CHO TẤT CẢ
enum DoorSource { NONE, AUTO_SENSOR, MANUAL_BUTTON, WEB_COMMAND };
DoorSource lastDoorSource = NONE;  // Nguồn gốc mở cửa gần nhất

// ===== BUFFER DỮ LIỆU =====
byte dataBuffer[5];
byte commandBuffer = 0;

// ===== PROTOCOL =====
// Command từ Master:
// 'R': Request data
// 'C': Command prefix -> Next byte is command code
// 0x10: Mở cửa
// 0x11: Đóng cửa
// 0x12: Toggle cửa

void setup() {
  Serial.begin(9600);
  Serial.println(F("Uno2 Start UART"));
  
  // KHỞI TẠO UART SOFTWARE
  mySerial.begin(9600);
  Serial.println("SoftwareSerial initialized on pins 2(RX), 3(TX)");
  
  // Khởi tạo chân
  pinMode(BUTTON_OPEN_PIN, INPUT_PULLUP);
  pinMode(BUTTON_CLOSE_PIN, INPUT_PULLUP);
  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);
  
  // Khởi tạo Servo
  doorServo.attach(SERVO_PIN);
  Serial.println("Servo attached. Testing movement...");
  
  // Test Servo (Wave) để báo hiệu khởi động thành công
  doorServo.write(45);
  delay(500);
  doorServo.write(DOOR_CLOSED_ANGLE);
  delay(500);
  
  doorServo.detach();  // Detach để tránh jitter
  Serial.println("Servo test done.");
  
  SPI.begin();
  mfrc522.PCD_Init();
  delay(50);
  Serial.println(F("OK"));
}

void loop() {
  // ===== XỬ LÝ UART =====
  handleUART();
  
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
  
  // ===== 7. CẬP NHẬT SERVO (SMOOTH MOVEMENT) =====
  updateServo();
  
  delay(10);  // Giảm delay để servo mượt hơn
}

// ===== XỬ LÝ UART =====
void handleUART() {
  if (mySerial.available()) {
    char c = mySerial.read();
    Serial.print("UART RX: "); Serial.println(c); // Debug - BẬT ĐỂ KIỂM TRA
    
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
  dataBuffer[0] = doorOpen ? 1 : 0;
  dataBuffer[1] = autoOpenTriggered ? 1 : 0;  // Gửi trạng thái auto-open
  dataBuffer[2] = rfidAccessGranted ? 1 : 0;
  
  int16_t distInt = (int16_t)(distance * 10);
  dataBuffer[3] = (distInt >> 8) & 0xFF;
  dataBuffer[4] = distInt & 0xFF;
  
  mySerial.write(dataBuffer, 5);
  Serial.println("Sent 5 bytes to Master");
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
  
  // Đọc xung echo - GIẢM TIMEOUT XUỐNG 10ms (tầm 1.7m) để tránh block lâu
  long duration = pulseIn(ECHO_PIN, HIGH, 10000); 
  
  // Tính khoảng cách (cm)
  if (duration > 0) {
    distance = duration * 0.034 / 2.0;
  } else {
    distance = 999.9;  // Không đo được
  }
  
  lastMeasure = millis();
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

// ===== TỰ ĐỘNG MỞ CỬA KHI PHÁT HIỆN NGƯỜI =====
// Nếu khoảng cách < 10cm (người đến gần) → TỰ ĐỘNG MỞ CỬA
// Chỉ hoạt động khi không ở chế độ manual hoặc security mode
void autoOpenDoor() {
  // Nếu đang manual mode, bỏ qua tự động mở cửa
  if (manualDoorMode) {
    autoOpenTriggered = false;
    return;
  }
  
  // Nếu security mode đang bật, KHÔNG mở cửa tự động
  if (securityModeActive) {
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

// ===== CẬP NHẬT SERVO (SMOOTH MOVEMENT) =====
void updateServo() {
  if (!servoMoving) return;
  
  if (millis() - lastServoMoveTime >= SERVO_STEP_DELAY) {
    lastServoMoveTime = millis();
    
    // Attach servo trước khi di chuyển (nếu chưa attach)
    if (!doorServo.attached()) {
      doorServo.attach(SERVO_PIN);
      delay(50);  // Chờ servo ổn định
    }
    
    if (currentServoAngle < targetServoAngle) {
      currentServoAngle++;
      doorServo.write(currentServoAngle);
    } else if (currentServoAngle > targetServoAngle) {
      currentServoAngle--;
      doorServo.write(currentServoAngle);
    } else {
      // Đã đến vị trí mục tiêu
      servoMoving = false;
      delay(300);  // Giữ vị trí ổn định
      doorServo.detach();  // Detach để tránh jitter và tiết kiệm pin
      Serial.print(F("Servo:Done@"));
      Serial.println(currentServoAngle);
    }
  }
}

// ===== MỞ CỬA =====
void openDoor() {
  if (!doorOpen) {
    targetServoAngle = DOOR_OPEN_ANGLE;
    servoMoving = true;
    doorOpen = true;
    Serial.println(F("Door:Opening..."));
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
    targetServoAngle = DOOR_CLOSED_ANGLE;
    servoMoving = true;
    doorOpen = false;
    Serial.println(F("Door:Closing..."));
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
    case 0x20:  // Bật Security Mode
      securityModeActive = true;
      autoOpenTriggered = false;  // Reset auto-open
      Serial.println(F("🛡️ Security Mode: ON"));
      break;
    case 0x21:  // Tắt Security Mode
      securityModeActive = false;
      Serial.println(F("🔓 Security Mode: OFF"));
      break;
  }
  commandBuffer = 0;
}

// ===== I2C REQUEST EVENT =====
// Master yêu cầu dữ liệu
// void requestEvent() {
//   requestCount++;
  
//   i2cBuffer[0] = doorOpen ? 1 : 0;
//   i2cBuffer[1] = autoOpenTriggered ? 1 : 0;  // Gửi trạng thái auto-open
//   i2cBuffer[2] = rfidAccessGranted ? 1 : 0;
  
//   int16_t distInt = (int16_t)(distance * 10);
//   i2cBuffer[3] = (distInt >> 8) & 0xFF;
//   i2cBuffer[4] = distInt & 0xFF;
  
//   Wire.write(i2cBuffer, 5);
// }

// ===== I2C RECEIVE EVENT =====
// Master gửi lệnh
// void receiveEvent(int byteCount) {
//   if (byteCount > 0) {
//     commandBuffer = Wire.read();
//     while (Wire.available()) Wire.read();
//   }
// }
