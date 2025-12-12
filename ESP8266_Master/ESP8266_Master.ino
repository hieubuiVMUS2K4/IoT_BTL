/*
 * ESP8266 - Master UART (SoftwareSerial) + MQTT Client + Web Config
 * Nhiệm vụ: Thu thập dữ liệu từ 2 Arduino qua UART, gửi về MQTT Broker
 * 
 * Kết nối phần cứng (UART Software):
 * - Arduino 1: D1 (RX) - D2 (TX)  <--> Uno 1: Pin 5 (TX) - Pin 4 (RX)
 * - Arduino 2: D5 (RX) - D6 (TX)  <--> Uno 2: Pin 3 (TX) - Pin 2 (RX)
 * 
 * MQTT Topics:
 * - Publish: iot/sensors/data (JSON sensor data)
 * - Subscribe: iot/control/# (all control commands)
 * 
 * Web Interface:
 * - http://<ip>/config - WiFi Configuration
 * - http://<ip>/update - OTA Firmware Update
 * - http://<ip>/api/info - Device Info API
 */

#include <ESP8266WiFi.h>
#include <PubSubClient.h>
#include <SoftwareSerial.h>
#include <ArduinoJson.h>
#include <WiFiClientSecure.h>  // Thêm để hỗ trợ TLS

// ===== FORWARD DECLARATIONS =====
void mqttCallback(char* topic, byte* payload, unsigned int length);

// ===== MQTT CLIENT (khai báo trước để esp_config_server.h có thể dùng) =====
WiFiClientSecure espClient;  // Đổi sang WiFiClientSecure cho TLS
PubSubClient mqttClient(espClient);

// ===== INCLUDE CONFIG SERVER =====
#include "esp_config_server.h"

// ===== CẤU HÌNH WIFI (fallback nếu chưa config) =====
const char* fallback_ssid = "tinhvdth";
const char* fallback_password = "123456789tt";

// ===== CẤU HÌNH MQTT (fallback nếu chưa config) =====
const char* fallback_mqtt_server = "5013cd33cc4841a0b2537c65d64aa6e7.s1.eu.hivemq.cloud";
const int fallback_mqtt_port = 8883;
const char* fallback_mqtt_username = "iot_device";
const char* fallback_mqtt_password = "bacJjRNFYB@v9JT";
const char* mqtt_client_id = "ESP8266_IoT_Master";

// MQTT Topics
const char* topic_data = "iot/sensors/data";
const char* topic_control_led2 = "iot/control/led2";
const char* topic_control_fan = "iot/control/fan";
const char* topic_control_door = "iot/control/door";
const char* topic_control_security = "iot/control/security";

// ===== CẤU HÌNH UART SOFTWARE =====
// Slave 1 (Uno 1)
#define S1_RX_PIN D1  // GPIO 5
#define S1_TX_PIN D2  // GPIO 4
SoftwareSerial swSer1(S1_RX_PIN, S1_TX_PIN);

// Slave 2 (Uno 2)
#define S2_RX_PIN D5  // GPIO 14
#define S2_TX_PIN D6  // GPIO 12
SoftwareSerial swSer2(S2_RX_PIN, S2_TX_PIN);

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

// ===== BIẾN ĐIỀU KHIỂN =====
unsigned long lastUpdate = 0;
const unsigned long updateInterval = 2000;  // 2 giây cập nhật 1 lần

// ===== CHẾ ĐỘ AN NINH =====
bool securityModeActive = false;  // Chế độ an ninh
bool intruderDetected = false;    // Phát hiện xâm nhập

void setup() {
  Serial.begin(115200);
  Serial.println("\n\n=== ESP8266 MQTT IoT System (UART + Web Config) ===");
  
  // Khởi tạo SoftwareSerial
  swSer1.begin(9600);
  swSer2.begin(9600);
  Serial.println("SoftwareSerial initialized (9600 baud)");
  
  // Khởi tạo Config Server (load config từ EEPROM)
  setupConfigServer();
  
  // Kết nối WiFi
  connectWiFi();
  
  // Cấu hình TLS cho HiveMQ Cloud
  espClient.setInsecure();  // Bỏ qua certificate verification
  
  // Cấu hình MQTT (sử dụng config từ EEPROM nếu có)
  const char* mqtt_server = isConfigured() ? getSavedMqttServer() : fallback_mqtt_server;
  int mqtt_port = isConfigured() ? getSavedMqttPort() : fallback_mqtt_port;
  
  mqttClient.setServer(mqtt_server, mqtt_port);
  mqttClient.setCallback(mqttCallback);
  
  Serial.println("System ready!");
  Serial.print("Web Config: http://");
  Serial.println(WiFi.localIP());
}

void loop() {
  // Xử lý Web Server
  handleConfigServer();
  
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
}

// ===== KẾT NỐI WIFI =====
void connectWiFi() {
  // Sử dụng config từ EEPROM nếu có
  const char* wifi_ssid = (isConfigured() && strlen(getSavedSSID()) > 0) ? getSavedSSID() : fallback_ssid;
  const char* wifi_pass = (isConfigured() && strlen(getSavedPassword()) > 0) ? getSavedPassword() : fallback_password;
  
  Serial.print("Connecting to WiFi: ");
  Serial.println(wifi_ssid);
  
  WiFi.mode(WIFI_STA);
  WiFi.begin(wifi_ssid, wifi_pass);
  
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
    Serial.println("\n✗ WiFi connection failed!");
    Serial.println("⇒ Starting AP Mode for configuration...");
    startAPMode();
  }
}

// ===== KẾT NỐI MQTT =====
void reconnectMQTT() {
  // Sử dụng config từ EEPROM nếu có
  const char* mqtt_user = isConfigured() ? getSavedMqttUser() : fallback_mqtt_username;
  const char* mqtt_pass = isConfigured() ? getSavedMqttPass() : fallback_mqtt_password;
  
  while (!mqttClient.connected()) {
    Serial.print("Connecting to MQTT...");
    
    // Kết nối với username và password
    if (mqttClient.connect(mqtt_client_id, mqtt_user, mqtt_pass)) {
      Serial.println(" ✓ Connected!");
      
      // Subscribe control topics
      mqttClient.subscribe(topic_control_led2);
      mqttClient.subscribe(topic_control_fan);
      mqttClient.subscribe(topic_control_door);
      mqttClient.subscribe(topic_control_security);
      
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
  
  // Xử lý lệnh Security Mode
  else if (strcmp(topic, topic_control_security) == 0) {
    if (message == "on") {
      securityModeActive = true;
      intruderDetected = false;  // Reset cảnh báo
      // GỬI LỆNH XUỐNG CẢ 2 ARDUINO
      sendCommandToSlave1(0x20);  // Arduino Uno 1: Bật LED nhấp nháy
      sendCommandToSlave2(0x20);  // Arduino Uno 2: Tắt auto-open cửa
      Serial.println("🔒 SECURITY MODE: ON");
    } else if (message == "off") {
      securityModeActive = false;
      intruderDetected = false;
      // GỬI LỆNH XUỐNG CẢ 2 ARDUINO
      sendCommandToSlave1(0x21);  // Arduino Uno 1: Tắt LED nhấp nháy
      sendCommandToSlave2(0x21);  // Arduino Uno 2: Bật lại auto-open cửa
      Serial.println("🔓 SECURITY MODE: OFF");
    }
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
  
  // Security Mode
  doc["securityMode"] = securityModeActive;
  doc["intruder"] = intruderDetected;
  
  // Logic phát hiện xâm nhập
  if (securityModeActive) {
    bool currentThreat = false;
    
    // PIR phát hiện chuyển động
    if (slave1Data.pirActive) {
      currentThreat = true;
      if (!intruderDetected) {
        Serial.println("🚨 INTRUDER ALERT: Motion detected!");
      }
    }
    
    // Khoảng cách < 30cm
    if (slave2Data.distance > 0 && slave2Data.distance < 30) {
      currentThreat = true;
      if (!intruderDetected) {
        Serial.println("🚨 INTRUDER ALERT: Close distance!");
      }
    }
    
    // Cập nhật trạng thái
    intruderDetected = currentThreat;
    
    // Tự động clear cảnh báo khi không còn mối đe dọa
    if (!currentThreat && intruderDetected) {
      Serial.println("✓ All clear - No threats detected");
    }
  }
  
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
  swSer1.listen();  // Lắng nghe cổng 1
  delay(50);        // Delay nhỏ để ổn định
  swSer1.flush();   // Flush buffer
  
  // Xóa buffer cũ
  while (swSer1.available()) swSer1.read();
  
  // Gửi yêu cầu
  swSer1.write('R');
  
  // Đợi phản hồi (timeout 100ms)
  unsigned long timeout = millis();
  while (swSer1.available() < 9 && (millis() - timeout < 100)) {
    delay(1);
  }
  
  int available = swSer1.available();
  
  if (available >= 9) {
    slave1Data.pirActive = swSer1.read() == 1;
    slave1Data.led1State = swSer1.read() == 1;
    slave1Data.led2State = swSer1.read() == 1;
    
    int16_t tempInt = (swSer1.read() << 8) | swSer1.read();
    slave1Data.temperature = tempInt / 10.0;
    
    int16_t humInt = (swSer1.read() << 8) | swSer1.read();
    slave1Data.humidity = humInt / 10.0;
    
    slave1Data.fanState = swSer1.read() == 1;
    slave1Data.fanAutoMode = swSer1.read() == 1;
    
    Serial.println("✓ Slave1 data read OK");
  } else {
    Serial.print("✗ Slave1 Timeout/Incomplete: ");
    Serial.println(available);
  }
}

// ===== ĐỌC SLAVE 2 =====
void readSlave2Data() {
  swSer2.listen();  // Lắng nghe cổng 2
  delay(100);       // Tăng delay chờ ổn định
  swSer2.flush();   // Flush buffer
  
  // Xóa buffer cũ
  while (swSer2.available()) swSer2.read();
  
  // Gửi yêu cầu
  swSer2.write('R');
  
  // Đợi phản hồi (timeout 300ms)
  unsigned long timeout = millis();
  while (swSer2.available() < 5 && (millis() - timeout < 300)) {
    delay(1);
  }
  
  int available = swSer2.available();
  
  if (available >= 5) {
    slave2Data.doorOpen = swSer2.read() == 1;
    slave2Data.autoOpenActive = swSer2.read() == 1;
    slave2Data.rfidAccess = swSer2.read() == 1;
    
    int16_t distInt = (swSer2.read() << 8) | swSer2.read();
    slave2Data.distance = distInt / 10.0;
    
    Serial.println("✓ Slave2 data read OK");
  } else {
    Serial.print("✗ Slave2 Timeout/Incomplete: ");
    Serial.println(available);
    
    // RETRY ONCE
    Serial.println("  Retrying Slave 2...");
    while (swSer2.available()) swSer2.read();
    swSer2.write('R');
    timeout = millis();
    while (swSer2.available() < 5 && (millis() - timeout < 300)) {
      delay(1);
    }
    if (swSer2.available() >= 5) {
       // Read data (duplicate code simplified)
       slave2Data.doorOpen = swSer2.read() == 1;
       slave2Data.autoOpenActive = swSer2.read() == 1;
       slave2Data.rfidAccess = swSer2.read() == 1;
       int16_t distInt = (swSer2.read() << 8) | swSer2.read();
       slave2Data.distance = distInt / 10.0;
       Serial.println("✓ Slave2 Retry OK");
    }
  }
}

// ===== GỬI LỆNH ĐẾN SLAVE =====
void sendCommandToSlave1(byte command) {
  swSer1.listen();
  swSer1.write('C');     // Header lệnh
  swSer1.write(command); // Mã lệnh
  Serial.print("→ Slave1 cmd: 0x");
  Serial.println(command, HEX);
}

void sendCommandToSlave2(byte command) {
  swSer2.listen();
  swSer2.write('C');     // Header lệnh
  swSer2.write(command); // Mã lệnh
  Serial.print("→ Slave2 cmd: 0x");
  Serial.println(command, HEX);
}
