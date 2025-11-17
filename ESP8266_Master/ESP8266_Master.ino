/*
 * ESP8266 - Master I2C + WiFi Client
 * Nhiệm vụ: Thu thập dữ liệu từ 2 Arduino, gửi về Node.js server qua WiFi
 * 
 * Kết nối phần cứng:
 * - I2C: D1 (GPIO5 - SCL), D2 (GPIO4 - SDA)
 * 
 * Chế độ WiFi: STA (Station)
 * Kết nối đến Node.js server chạy trên PC
 */

#include <ESP8266WiFi.h>
#include <ESP8266HTTPClient.h>
#include <Wire.h>
#include <ArduinoJson.h>

// ===== CẤU HÌNH WIFI =====
const char* ssid = "Khaidepzai";          // Thay bằng tên WiFi của bạn
const char* password = "hieuhieuhoangkhai";   // Thay bằng mật khẩu WiFi

// ===== CẤU HÌNH SERVER =====
const char* serverIP = "192.168.1.220";  // Thay bằng IP máy tính chạy Node.js server
const int serverPort = 3000;
String serverURL = "http://" + String(serverIP) + ":" + String(serverPort);

// ===== CẤU HÌNH I2C =====
#define SLAVE1_ADDRESS 8  // Arduino Uno 1
#define SLAVE2_ADDRESS 9  // Arduino Uno 2
#define SDA_PIN 4  // D2
#define SCL_PIN 5  // D1

// ===== DỮ LIỆU TỪ SLAVE 1 =====
struct Slave1Data {
  bool pirState;
  bool led1State;
  bool led2State;
  float temperature;
  float humidity;
};
Slave1Data slave1Data;

// ===== DỮ LIỆU TỪ SLAVE 2 =====
struct Slave2Data {
  bool doorOpen;
  bool autoOpenActive;  // Trạng thái tự động mở cửa (< 10cm)
  bool rfidAccess;
  float distance;
};
Slave2Data slave2Data;

// ===== BIẾN ĐIỀU KHIỂN =====
WiFiClient wifiClient;
unsigned long lastUpdate = 0;
const unsigned long updateInterval = 2000;  // Gửi dữ liệu mỗi 2 giây

void setup() {
  Serial.begin(115200);
  Serial.println("\n\n=== ESP8266 Master I2C Started ===");
  
  // Bật pull-up resistor nội bộ (tạm thời)
  pinMode(SDA_PIN, INPUT_PULLUP);
  pinMode(SCL_PIN, INPUT_PULLUP);
  delay(100);
  
  // Khởi tạo I2C với clock speed RẤT THẤP (50kHz)
  Wire.begin(SDA_PIN, SCL_PIN);
  Wire.setClock(50000);  // 50kHz - rất chậm nhưng ổn định
  Wire.setClockStretchLimit(1500);  // Tăng thời gian chờ
  Serial.println("I2C Master initialized (SDA=D2/GPIO4, SCL=D1/GPIO5)");
  Serial.println("I2C Clock: 50kHz with internal pull-ups");
  
  // Đợi Arduino Uno khởi động xong (quan trọng!)
  Serial.println("Waiting for Arduino slaves to initialize...");
  delay(5000);  // Tăng lên 5 giây
  
  // Scan I2C bus để kiểm tra slaves
  Serial.println("\n!!! CRITICAL: Checking I2C connection !!!");
  scanI2C();
  
  // Kết nối WiFi
  connectWiFi();
  
  Serial.println("System ready!");
}

void loop() {
  // Kiểm tra kết nối WiFi
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi disconnected, reconnecting...");
    connectWiFi();
  }
  
  // Thu thập dữ liệu từ Slave 1
  readSlave1Data();
  delay(100);  // Tăng delay giữa các lần đọc
  
  // Thu thập dữ liệu từ Slave 2
  readSlave2Data();
  delay(100);  // Tăng delay giữa các lần đọc
  
  // Gửi dữ liệu lên server
  if (millis() - lastUpdate > updateInterval) {
    sendDataToServer();
    lastUpdate = millis();
  }
  
  // Kiểm tra lệnh từ server
  checkServerCommands();
  
  delay(500);
}

// ===== KẾT NỐI WIFI =====
void connectWiFi() {
  Serial.print("Connecting to WiFi: ");
  Serial.println(ssid);
  
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);
  
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 30) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nWiFi connected!");
    Serial.print("IP address: ");
    Serial.println(WiFi.localIP());
    Serial.print("Server URL: ");
    Serial.println(serverURL);
  } else {
    Serial.println("\nWiFi connection failed!");
  }
}

// ===== ĐỌC DỮ LIỆU TỪ SLAVE 1 =====
void readSlave1Data() {
  // Request 7 bytes từ Slave 1 (7 bytes = 56 bits, OK)
  byte bytesReceived = Wire.requestFrom(SLAVE1_ADDRESS, 7);
  
  // Delay để Arduino kịp chuẩn bị dữ liệu trong requestEvent()
  delay(5);  // 5ms - đủ thời gian cho Arduino xử lý
  
  // Đợi dữ liệu với timeout
  unsigned long timeout = millis();
  while (Wire.available() < 7 && (millis() - timeout < 500)) {
    delay(1);
  }
  
  if (Wire.available() >= 7) {
    Serial.println("✓ Slave 1 responded with 7 bytes");
    
    // Byte 0: PIR state
    slave1Data.pirState = Wire.read() == 1;
    
    // Byte 1: LED 1 state
    slave1Data.led1State = Wire.read() == 1;
    
    // Byte 2: LED 2 state
    slave1Data.led2State = Wire.read() == 1;
    
    // Byte 3-4: Temperature
    int16_t tempInt = (Wire.read() << 8) | Wire.read();
    slave1Data.temperature = tempInt / 10.0;
    
    // Byte 5-6: Humidity
    int16_t humInt = (Wire.read() << 8) | Wire.read();
    slave1Data.humidity = humInt / 10.0;
    
    Serial.println("--- Slave 1 Data ---");
    Serial.println("PIR: " + String(slave1Data.pirState));
    Serial.println("LED1: " + String(slave1Data.led1State));
    Serial.println("LED2: " + String(slave1Data.led2State));
    Serial.println("Temp: " + String(slave1Data.temperature) + "°C");
    Serial.println("Humidity: " + String(slave1Data.humidity) + "%");
  } else {
    Serial.print("✗ Slave 1 ERROR: Received only ");
    Serial.print(Wire.available());
    Serial.print(" bytes (expected 7) - Check Arduino Uno 1 Serial Monitor!");
    Serial.println();
  }
  
  // Clear buffer
  while (Wire.available()) {
    Wire.read();
  }
}

// ===== ĐỌC DỮ LIỆU TỪ SLAVE 2 =====
void readSlave2Data() {
  // Request 5 bytes từ Slave 2 (5 bytes = 40 bits, OK)
  byte bytesReceived = Wire.requestFrom(SLAVE2_ADDRESS, 5);
  
  // Delay để Arduino kịp chuẩn bị dữ liệu trong requestEvent()
  delay(5);  // 5ms - đủ thời gian cho Arduino xử lý
  
  // Đợi dữ liệu với timeout
  unsigned long timeout = millis();
  while (Wire.available() < 5 && (millis() - timeout < 500)) {
    delay(1);
  }
  
  if (Wire.available() >= 5) {
    Serial.println("✓ Slave 2 responded with 5 bytes");
    
    // Byte 0: Door state
    slave2Data.doorOpen = Wire.read() == 1;
    
    // Byte 1: Auto-open active (< 10cm)
    slave2Data.autoOpenActive = Wire.read() == 1;
    
    // Byte 2: RFID access
    slave2Data.rfidAccess = Wire.read() == 1;
    
    // Byte 3-4: Distance
    int16_t distInt = (Wire.read() << 8) | Wire.read();
    slave2Data.distance = distInt / 10.0;
    
    Serial.println("--- Slave 2 Data ---");
    Serial.println("Door: " + String(slave2Data.doorOpen ? "OPEN" : "CLOSED"));
    Serial.println("AutoOpen: " + String(slave2Data.autoOpenActive));
    Serial.println("RFID: " + String(slave2Data.rfidAccess));
    Serial.println("Distance: " + String(slave2Data.distance) + " cm");
  } else {
    Serial.print("✗ Slave 2 ERROR: Received only ");
    Serial.print(Wire.available());
    Serial.print(" bytes (expected 5) - Check Arduino Uno 2 Serial Monitor!");
    Serial.println();
  }
  
  // Clear buffer
  while (Wire.available()) {
    Wire.read();
  }
}

// ===== GỬI DỮ LIỆU LÊN SERVER =====
void sendDataToServer() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi not connected, skipping data send");
    return;
  }
  
  HTTPClient http;
  
  // Tạo JSON payload
  StaticJsonDocument<512> doc;
  
  // Slave 1 data
  doc["pir"] = slave1Data.pirState;
  doc["led1"] = slave1Data.led1State;
  doc["led2"] = slave1Data.led2State;
  doc["temperature"] = slave1Data.temperature;
  doc["humidity"] = slave1Data.humidity;
  
  // Slave 2 data
  doc["door"] = slave2Data.doorOpen;
  doc["autoOpen"] = slave2Data.autoOpenActive;  // Trạng thái tự động mở
  doc["rfid"] = slave2Data.rfidAccess;
  doc["distance"] = slave2Data.distance;
  
  // Timestamp
  doc["timestamp"] = millis();
  
  String jsonString;
  serializeJson(doc, jsonString);
  
  Serial.println("\n=== Sending data to server ===");
  Serial.println(jsonString);
  
  // Gửi POST request
  http.begin(wifiClient, serverURL + "/api/data");
  http.addHeader("Content-Type", "application/json");
  
  int httpCode = http.POST(jsonString);
  
  if (httpCode > 0) {
    Serial.print("HTTP Response code: ");
    Serial.println(httpCode);
    
    if (httpCode == HTTP_CODE_OK) {
      String response = http.getString();
      Serial.println("Response: " + response);
    }
  } else {
    Serial.print("HTTP Error: ");
    Serial.println(http.errorToString(httpCode));
  }
  
  http.end();
}

// ===== KIỂM TRA LỆNH TỪ SERVER =====
void checkServerCommands() {
  if (WiFi.status() != WL_CONNECTED) {
    return;
  }
  
  HTTPClient http;
  
  http.begin(wifiClient, serverURL + "/api/commands");
  int httpCode = http.GET();
  
  if (httpCode == HTTP_CODE_OK) {
    String payload = http.getString();
    
    if (payload.length() > 2) {  // Không phải "{}"
      Serial.println("\n=== Received commands from server ===");
      Serial.println(payload);
      
      // Parse JSON
      StaticJsonDocument<256> doc;
      DeserializationError error = deserializeJson(doc, payload);
      
      if (!error) {
        // Xử lý lệnh LED 1
        if (doc.containsKey("led1")) {
          const char* led1Cmd = doc["led1"];
          if (strcmp(led1Cmd, "on") == 0) {
            sendCommandToSlave1(0x04);
          } else if (strcmp(led1Cmd, "off") == 0) {
            sendCommandToSlave1(0x05);
          }
        }
        
        // Xử lý lệnh LED 2
        if (doc.containsKey("led2")) {
          const char* led2Cmd = doc["led2"];
          if (strcmp(led2Cmd, "on") == 0) {
            sendCommandToSlave1(0x01);
          } else if (strcmp(led2Cmd, "off") == 0) {
            sendCommandToSlave1(0x02);
          } else if (strcmp(led2Cmd, "toggle") == 0) {
            sendCommandToSlave1(0x03);
          }
        }
        
        // Xử lý lệnh cửa
        if (doc.containsKey("door")) {
          const char* doorCmd = doc["door"];
          if (strcmp(doorCmd, "open") == 0) {
            sendCommandToSlave2(0x10);
          } else if (strcmp(doorCmd, "close") == 0) {
            sendCommandToSlave2(0x11);
          } else if (strcmp(doorCmd, "toggle") == 0) {
            sendCommandToSlave2(0x12);
          }
        }
      }
    }
  }
  
  http.end();
}

// ===== SCAN I2C BUS =====
void scanI2C() {
  Serial.println("\n========================================");
  Serial.println("Scanning I2C bus for devices...");
  Serial.println("========================================");
  byte count = 0;
  
  for (byte address = 1; address < 127; address++) {
    Wire.beginTransmission(address);
    byte error = Wire.endTransmission();
    
    if (error == 0) {
      Serial.print("✓ I2C device FOUND at address 0x");
      if (address < 16) Serial.print("0");
      Serial.print(address, HEX);
      Serial.print(" (decimal: ");
      Serial.print(address);
      Serial.print(")");
      
      if (address == 8) Serial.print(" <- Arduino Uno 1");
      if (address == 9) Serial.print(" <- Arduino Uno 2");
      
      Serial.println();
      count++;
    } else if (error == 4) {
      Serial.print("✗ Unknown error at address 0x");
      if (address < 16) Serial.print("0");
      Serial.println(address, HEX);
    }
  }
  
  Serial.println("========================================");
  if (count == 0) {
    Serial.println("✗✗✗ ERROR: No I2C devices found! ✗✗✗");
    Serial.println("\nHARDWARE CHECK REQUIRED:");
    Serial.println("1. SDA connection: ESP8266 D2 (GPIO4) -> Arduino A4");
    Serial.println("2. SCL connection: ESP8266 D1 (GPIO5) -> Arduino A5");
    Serial.println("3. GND: Must be connected between all boards");
    Serial.println("4. Pull-up resistors: 4.7kΩ from SDA to 3.3V");
    Serial.println("                      4.7kΩ from SCL to 3.3V");
    Serial.println("5. Arduino power: Check both Arduinos have power");
    Serial.println("6. Check Serial Monitor of Arduinos - are they running?");
    Serial.println("\nSYSTEM WILL CONTINUE BUT DATA WILL BE ALL ZEROS");
  } else {
    Serial.print("✓ Found ");
    Serial.print(count);
    Serial.println(" I2C device(s) - Good!");
    
    if (count < 2) {
      Serial.println("\n⚠ WARNING: Expected 2 devices but found only " + String(count));
      Serial.println("Check the missing Arduino connection!");
    }
  }
  Serial.println("========================================\n");
}

// ===== GỬI LỆNH ĐẾN SLAVE 1 =====
void sendCommandToSlave1(byte command) {
  Serial.print("Sending command to Slave 1: 0x");
  Serial.println(command, HEX);
  
  Wire.beginTransmission(SLAVE1_ADDRESS);
  Wire.write(command);
  byte error = Wire.endTransmission();
  
  if (error == 0) {
    Serial.println("Command sent successfully");
  } else {
    Serial.print("I2C error: ");
    Serial.println(error);
  }
}

// ===== GỬI LỆNH ĐẾN SLAVE 2 =====
void sendCommandToSlave2(byte command) {
  Serial.print("Sending command to Slave 2: 0x");
  Serial.println(command, HEX);
  
  Wire.beginTransmission(SLAVE2_ADDRESS);
  Wire.write(command);
  byte error = Wire.endTransmission();
  
  if (error == 0) {
    Serial.println("Command sent successfully");
  } else {
    Serial.print("I2C error: ");
    Serial.println(error);
  }
}
