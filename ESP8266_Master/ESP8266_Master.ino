/*
 * ESP8266 - Master I2C + MQTT Client
 * Nhiệm vụ: Thu thập dữ liệu từ 2 Arduino, gửi về MQTT Broker
 * 
 * Kết nối phần cứng:
 * - I2C: D1 (GPIO5 - SCL), D2 (GPIO4 - SDA)
 * 
 * MQTT Topics:
 * - Publish: iot/sensors/data (JSON sensor data)
 * - Subscribe: iot/control/# (all control commands)
 */

#include <ESP8266WiFi.h>
#include <PubSubClient.h>
#include <Wire.h>
#include <ArduinoJson.h>

// ===== CẤU HÌNH WIFI =====
const char* ssid = "tinhvdth";
const char* password = "123456789tt";

// ===== CẤU HÌNH MQTT =====
const char* mqtt_server = "10.137.147.176";  // IP máy chạy Mosquitto (giữ nguyên nếu Mosquitto chạy trên máy khác)
const int mqtt_port = 1883;
const char* mqtt_client_id = "ESP8266_IoT_Master";

// MQTT Topics
const char* topic_data = "iot/sensors/data";
const char* topic_control_led2 = "iot/control/led2";
const char* topic_control_fan = "iot/control/fan";
const char* topic_control_door = "iot/control/door";

// ===== CẤU HÌNH I2C =====
#define SLAVE1_ADDRESS 8
#define SLAVE2_ADDRESS 9
#define SDA_PIN 4
#define SCL_PIN 5

// ===== DỮ LIỆU TỪ SLAVE 1 =====
struct Slave1Data {
  bool pirActive;
  bool led1State;
  bool led2State;
  float temperature;
  float humidity;
  bool fanState;
  bool fanAutoMode;
};
Slave1Data slave1Data;

// ===== DỮ LIỆU TỪ SLAVE 2 =====
struct Slave2Data {
  bool doorOpen;
  bool autoOpenActive;
  bool rfidAccess;
  float distance;
};
Slave2Data slave2Data;

// ===== MQTT CLIENT =====
WiFiClient espClient;
PubSubClient mqttClient(espClient);

// ===== BIẾN ĐIỀU KHIỂN =====
unsigned long lastUpdate = 0;
const unsigned long updateInterval = 5000;  // Tăng từ 2s lên 5s để debug rõ hơn

void setup() {
  Serial.begin(115200);
  Serial.println("\n\n=== ESP8266 MQTT IoT System ===");
  
  // Khởi tạo I2C
  pinMode(SDA_PIN, INPUT_PULLUP);
  pinMode(SCL_PIN, INPUT_PULLUP);
  delay(100);
  
  Wire.begin(SDA_PIN, SCL_PIN);
  Wire.setClock(50000);
  Wire.setClockStretchLimit(1500);
  Serial.println("I2C Master initialized (50kHz)");
  
  // Đợi Arduino
  Serial.println("Waiting for Arduino slaves...");
  delay(5000);
  
  // Scan I2C
  scanI2C();
  
  // Kết nối WiFi
  connectWiFi();
  
  // Cấu hình MQTT
  mqttClient.setServer(mqtt_server, mqtt_port);
  mqttClient.setCallback(mqttCallback);
  
  Serial.println("System ready!");
}

void loop() {
  // Kết nối WiFi
  if (WiFi.status() != WL_CONNECTED) {
    connectWiFi();
  }
  
  // Kết nối MQTT
  if (!mqttClient.connected()) {
    reconnectMQTT();
  }
  mqttClient.loop();
  
  // Đọc dữ liệu từ Arduino
  readSlave1Data();
  delay(100);
  readSlave2Data();
  delay(100);
  
  // Publish dữ liệu
  if (millis() - lastUpdate > updateInterval) {
    publishSensorData();
    lastUpdate = millis();
  }
  
  delay(100);
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
    Serial.println("\n✓ WiFi connected!");
    Serial.print("IP: ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println("\n✗ WiFi failed!");
  }
}

// ===== KẾT NỐI MQTT =====
void reconnectMQTT() {
  while (!mqttClient.connected()) {
    Serial.print("Connecting to MQTT...");
    
    if (mqttClient.connect(mqtt_client_id)) {
      Serial.println(" ✓ Connected!");
      
      // Subscribe control topics
      mqttClient.subscribe(topic_control_led2);
      mqttClient.subscribe(topic_control_fan);
      mqttClient.subscribe(topic_control_door);
      
      Serial.println("✓ Subscribed to control topics");
    } else {
      Serial.print(" ✗ Failed, rc=");
      Serial.print(mqttClient.state());
      Serial.println(" Retry in 5s...");
      delay(5000);
    }
  }
}

// ===== MQTT CALLBACK (Nhận lệnh) =====
void mqttCallback(char* topic, byte* payload, unsigned int length) {
  String message = "";
  for (unsigned int i = 0; i < length; i++) {
    message += (char)payload[i];
  }
  
  Serial.print("📥 MQTT Received [");
  Serial.print(topic);
  Serial.print("]: ");
  Serial.println(message);
  
  // Xử lý lệnh LED2
  if (strcmp(topic, topic_control_led2) == 0) {
    if (message == "on") sendCommandToSlave1(0x01);
    else if (message == "off") sendCommandToSlave1(0x02);
    else if (message == "toggle") sendCommandToSlave1(0x03);
  }
  
  // Xử lý lệnh Fan
  else if (strcmp(topic, topic_control_fan) == 0) {
    if (message == "on") sendCommandToSlave1(0x07);
    else if (message == "off") sendCommandToSlave1(0x08);
    else if (message == "toggle") sendCommandToSlave1(0x09);
  }
  
  // Xử lý lệnh Door
  else if (strcmp(topic, topic_control_door) == 0) {
    if (message == "open") sendCommandToSlave2(0x10);
    else if (message == "close") sendCommandToSlave2(0x11);
    else if (message == "toggle") sendCommandToSlave2(0x12);
  }
}

// ===== PUBLISH DỮ LIỆU =====
void publishSensorData() {
  StaticJsonDocument<512> doc;
  
  // Slave 1
  doc["pir"] = slave1Data.pirActive;
  doc["led1"] = slave1Data.led1State;
  doc["led2"] = slave1Data.led2State;
  doc["temperature"] = slave1Data.temperature;
  doc["humidity"] = slave1Data.humidity;
  doc["fan"] = slave1Data.fanState;
  doc["fanAuto"] = slave1Data.fanAutoMode;
  
  // Slave 2
  doc["door"] = slave2Data.doorOpen;
  doc["autoOpen"] = slave2Data.autoOpenActive;
  doc["rfid"] = slave2Data.rfidAccess;
  doc["distance"] = slave2Data.distance;
  
  doc["timestamp"] = millis();
  
  String jsonString;
  serializeJson(doc, jsonString);
  
  if (mqttClient.publish(topic_data, jsonString.c_str())) {
    Serial.println("📤 Published: " + jsonString);
  } else {
    Serial.println("✗ Publish failed!");
  }
}

// ===== ĐỌC SLAVE 1 =====
void readSlave1Data() {
  Wire.requestFrom(SLAVE1_ADDRESS, 9);
  delay(50);  // Tăng từ 5ms lên 50ms
  
  unsigned long timeout = millis();
  while (Wire.available() < 9 && (millis() - timeout < 500)) {
    delay(1);
  }
  
  int available = Wire.available();
  Serial.print("[Slave1] Requested 9 bytes, received: ");
  Serial.print(available);
  Serial.println(" bytes");
  
  if (available >= 9) {
    slave1Data.pirActive = Wire.read() == 1;
    slave1Data.led1State = Wire.read() == 1;
    slave1Data.led2State = Wire.read() == 1;
    
    int16_t tempInt = (Wire.read() << 8) | Wire.read();
    slave1Data.temperature = tempInt / 10.0;
    
    int16_t humInt = (Wire.read() << 8) | Wire.read();
    slave1Data.humidity = humInt / 10.0;
    
    slave1Data.fanState = Wire.read() == 1;
    slave1Data.fanAutoMode = Wire.read() == 1;
    
    Serial.println("✓ Slave1 data read OK");
  } else if (available == 0) {
    Serial.println("✗ Slave1 NO RESPONSE - Check wiring!");
  } else {
    Serial.print("✗ Slave1 INCOMPLETE - Got ");
    Serial.print(available);
    Serial.println("/9 bytes");
  }
  
  while (Wire.available()) Wire.read();
}

// ===== ĐỌC SLAVE 2 =====
void readSlave2Data() {
  Wire.requestFrom(SLAVE2_ADDRESS, 5);
  delay(50);  // Tăng từ 5ms lên 50ms
  
  unsigned long timeout = millis();
  while (Wire.available() < 5 && (millis() - timeout < 500)) {
    delay(1);
  }
  
  int available = Wire.available();
  Serial.print("[Slave2] Requested 5 bytes, received: ");
  Serial.print(available);
  Serial.println(" bytes");
  
  if (available >= 5) {
    slave2Data.doorOpen = Wire.read() == 1;
    slave2Data.autoOpenActive = Wire.read() == 1;
    slave2Data.rfidAccess = Wire.read() == 1;
    
    int16_t distInt = (Wire.read() << 8) | Wire.read();
    slave2Data.distance = distInt / 10.0;
    
    Serial.println("✓ Slave2 data read OK");
  } else if (available == 0) {
    Serial.println("✗ Slave2 NO RESPONSE - Check wiring!");
  } else {
    Serial.print("✗ Slave2 INCOMPLETE - Got ");
    Serial.print(available);
    Serial.println("/5 bytes");
  }
  
  while (Wire.available()) Wire.read();
}

// ===== SCAN I2C =====
void scanI2C() {
  Serial.println("\n=== Scanning I2C Bus ===");
  byte count = 0;
  
  for (byte address = 1; address < 127; address++) {
    Wire.beginTransmission(address);
    byte error = Wire.endTransmission();
    
    if (error == 0) {
      Serial.print("✓ Device at 0x");
      if (address < 16) Serial.print("0");
      Serial.print(address, HEX);
      if (address == 8) Serial.print(" <- Uno 1");
      if (address == 9) Serial.print(" <- Uno 2");
      Serial.println();
      count++;
    }
  }
  
  Serial.print("Found ");
  Serial.print(count);
  Serial.println(" device(s)\n");
}

// ===== GỬI LỆNH ĐẾN SLAVE =====
void sendCommandToSlave1(byte command) {
  Wire.beginTransmission(SLAVE1_ADDRESS);
  Wire.write(command);
  Wire.endTransmission();
  Serial.print("→ Slave1 cmd: 0x");
  Serial.println(command, HEX);
}

void sendCommandToSlave2(byte command) {
  Wire.beginTransmission(SLAVE2_ADDRESS);
  Wire.write(command);
  Wire.endTransmission();
  Serial.print("→ Slave2 cmd: 0x");
  Serial.println(command, HEX);
}
