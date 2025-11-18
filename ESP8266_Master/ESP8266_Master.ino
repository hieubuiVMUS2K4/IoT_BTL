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
#include <Wire.h>
#include <ArduinoJson.h>
#include <PubSubClient.h>

// ===== NETWORK CONFIGURATION =====
// Thay đổi IP này khi chuyển mạng WiFi khác
const char* SERVER_IP = "10.137.147.176";  // IP của máy tính chạy server

// ===== CẤU HÌNH WIFI =====
const char* ssid = "tinhvdth";          // Thay bằng tên WiFi của bạn
const char* password = "123456789tt";   // Thay bằng mật khẩu WiFi

// ===== CẤU HÌNH MQTT =====
const char* mqttServer = SERVER_IP;  // Sử dụng constant thay vì hardcode
const int mqttPort = 1883;
const char* mqttUser = "";              // Username (nếu có)
const char* mqttPassword = "";          // Password (nếu có)
const char* mqttClientId = "esp8266-iot-001";

// MQTT Topics
const char* topicTemperature = "/iot/smarthome/sensors/temperature";
const char* topicMotion = "/iot/smarthome/sensors/motion";
const char* topicDoor = "/iot/smarthome/sensors/door";
const char* topicDistance = "/iot/smarthome/sensors/distance";
const char* topicStatus = "/iot/smarthome/status/esp8266";
const char* topicLed2 = "/iot/smarthome/commands/led2";
const char* topicDoorCmd = "/iot/smarthome/commands/door";

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
PubSubClient mqttClient(wifiClient);

// Non-blocking timing variables
unsigned long lastUpdate = 0;
const unsigned long updateInterval = 2000;  // Gửi dữ liệu mỗi 2 giây
unsigned long lastMqttReconnect = 0;
const unsigned long mqttReconnectInterval = 5000;  // Thử kết nối MQTT mỗi 5 giây
unsigned long lastI2CRead = 0;
const unsigned long i2cReadInterval = 100;  // Đọc I2C mỗi 100ms
unsigned long lastSlave1Read = 0;
unsigned long lastSlave2Read = 0;
const unsigned long slaveReadInterval = 50;  // Khoảng cách tối thiểu giữa 2 lần đọc slave

// ===== MQTT CALLBACK =====
void mqttCallback(char* topic, byte* payload, unsigned int length) {
  Serial.print("MQTT Message arrived [");
  Serial.print(topic);
  Serial.print("]: ");

  // Convert payload to string
  char message[length + 1];
  memcpy(message, payload, length);
  message[length] = '\0';
  Serial.println(message);

  // Parse JSON message
  StaticJsonDocument<256> doc;
  DeserializationError error = deserializeJson(doc, message);

  if (error) {
    Serial.print("JSON parse error: ");
    Serial.println(error.c_str());
    return;
  }

  // Handle commands
  if (strcmp(topic, topicLed2) == 0) {
    const char* action = doc["action"];
    if (strcmp(action, "on") == 0) {
      sendCommandToSlave1(0x01);  // Turn LED 2 ON
      Serial.println("LED2 ON command received");
    } else if (strcmp(action, "off") == 0) {
      sendCommandToSlave1(0x02);  // Turn LED 2 OFF
      Serial.println("LED2 OFF command received");
    } else if (strcmp(action, "toggle") == 0) {
      sendCommandToSlave1(0x03);  // Toggle LED 2
      Serial.println("LED2 TOGGLE command received");
    }
  } else if (strcmp(topic, topicDoorCmd) == 0) {
    const char* action = doc["action"];
    if (strcmp(action, "open") == 0) {
      sendCommandToSlave2(0x10);  // Open door
      Serial.println("DOOR OPEN command received");
    } else if (strcmp(action, "close") == 0) {
      sendCommandToSlave2(0x11);  // Close door
      Serial.println("DOOR CLOSE command received");
    } else if (strcmp(action, "toggle") == 0) {
      sendCommandToSlave2(0x12);  // Toggle door
      Serial.println("DOOR TOGGLE command received");
    }
  }
}

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

  // Khởi tạo MQTT
  mqttClient.setServer(mqttServer, mqttPort);
  mqttClient.setCallback(mqttCallback);

  Serial.println("System ready!");
}

void loop() {
   unsigned long currentMillis = millis();

   // Kiểm tra kết nối WiFi (non-blocking)
   if (WiFi.status() != WL_CONNECTED) {
     Serial.println("WiFi disconnected, reconnecting...");
     connectWiFi();
   }

   // Kiểm tra kết nối MQTT (non-blocking)
   if (!mqttClient.connected()) {
     if (currentMillis - lastMqttReconnect > mqttReconnectInterval) {
       reconnectMQTT();
       lastMqttReconnect = currentMillis;
     }
   }

   // MQTT loop phải chạy liên tục để nhận messages (CRITICAL for instant response)
   if (mqttClient.connected()) {
     mqttClient.loop();
   }

   // Thu thập dữ liệu từ I2C slaves (non-blocking với timing)
   if (currentMillis - lastI2CRead > i2cReadInterval) {
     // Đọc Slave 1
     if (currentMillis - lastSlave1Read > slaveReadInterval) {
       readSlave1Data();
       lastSlave1Read = currentMillis;
     }

     // Đọc Slave 2 (xen kẽ với Slave 1)
     if (currentMillis - lastSlave2Read > slaveReadInterval &&
         currentMillis - lastSlave1Read > slaveReadInterval / 2) {
       readSlave2Data();
       lastSlave2Read = currentMillis;
     }

     lastI2CRead = currentMillis;
   }

   // Gửi dữ liệu lên MQTT broker (non-blocking)
   if (currentMillis - lastUpdate > updateInterval) {
     publishSensorData();
     lastUpdate = currentMillis;
   }

   // Không có delay() - loop chạy liên tục để đảm bảo responsiveness
}

// ===== KẾT NỐI MQTT =====
void reconnectMQTT() {
  Serial.print("Attempting MQTT connection...");

  if (mqttClient.connect(mqttClientId, mqttUser, mqttPassword)) {
    Serial.println("connected");

    // Subscribe to command topics
    mqttClient.subscribe(topicLed2);
    mqttClient.subscribe(topicDoorCmd);

    Serial.println("Subscribed to command topics");

    // Publish online status
    mqttClient.publish(topicStatus, "{\"status\":\"online\"}", true);

  } else {
    Serial.print("failed, rc=");
    Serial.print(mqttClient.state());
    Serial.println(" try again in 5 seconds");
  }
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

// ===== PUBLISH DỮ LIỆU LÊN MQTT =====
void publishSensorData() {
  if (!mqttClient.connected()) {
    Serial.println("MQTT not connected, skipping data publish");
    return;
  }

  Serial.println("\n=== Publishing sensor data to MQTT ===");

  // Publish temperature & humidity
  StaticJsonDocument<128> tempDoc;
  tempDoc["temperature"] = slave1Data.temperature;
  tempDoc["humidity"] = slave1Data.humidity;
  tempDoc["timestamp"] = millis();

  String tempPayload;
  serializeJson(tempDoc, tempPayload);
  mqttClient.publish(topicTemperature, tempPayload.c_str(), true);  // Retained
  Serial.println("Published temperature: " + tempPayload);

  // Publish motion sensor
  StaticJsonDocument<64> motionDoc;
  motionDoc["motion"] = slave1Data.pirState;
  motionDoc["timestamp"] = millis();

  String motionPayload;
  serializeJson(motionDoc, motionPayload);
  mqttClient.publish(topicMotion, motionPayload.c_str(), true);  // Retained
  Serial.println("Published motion: " + motionPayload);

  // Publish door status
  StaticJsonDocument<128> doorDoc;
  doorDoc["door"] = slave2Data.doorOpen;
  doorDoc["autoOpen"] = slave2Data.autoOpenActive;
  doorDoc["rfid"] = slave2Data.rfidAccess;
  doorDoc["timestamp"] = millis();

  String doorPayload;
  serializeJson(doorDoc, doorPayload);
  mqttClient.publish(topicDoor, doorPayload.c_str(), true);  // Retained
  Serial.println("Published door: " + doorPayload);

  // Publish distance
  StaticJsonDocument<64> distDoc;
  distDoc["distance"] = slave2Data.distance;
  distDoc["timestamp"] = millis();

  String distPayload;
  serializeJson(distDoc, distPayload);
  mqttClient.publish(topicDistance, distPayload.c_str(), true);  // Retained
  Serial.println("Published distance: " + distPayload);
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
