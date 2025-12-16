/*
 * ESP8266 Web Server for WiFi Configuration & OTA
 * Include file này vào ESP8266_Master.ino để thêm tính năng:
 * - Cấu hình WiFi qua web interface
 * - OTA (Over-The-Air) firmware update
 * - REST API cho Flutter app
 */

#ifndef ESP_CONFIG_SERVER_H
#define ESP_CONFIG_SERVER_H

#include <ESP8266WebServer.h>
#include <ESP8266HTTPUpdateServer.h>
#include <EEPROM.h>
#include <ArduinoJson.h>

// ===== CẤU HÌNH =====
#define EEPROM_SIZE 512
#define CONFIG_START 0
#define FIRMWARE_VERSION "1.0.0"

// EEPROM Structure
struct WiFiConfigData {
  char ssid[32];
  char password[64];
  char mqttServer[64];
  int mqttPort;
  char mqttUser[32];
  char mqttPass[64];
  bool configured;
  char checksum;
};

// ===== GLOBAL VARIABLES =====
ESP8266WebServer configServer(80);
ESP8266HTTPUpdateServer httpUpdater;
WiFiConfigData savedConfig;
bool apModeActive = false;

// ===== FUNCTION DECLARATIONS =====
void setupConfigServer();
void handleConfigServer();
void loadConfigFromEEPROM();
void saveConfigToEEPROM();
void startAPMode();
void sendCorsHeaders();

// ===== IMPLEMENTATION =====

void loadConfigFromEEPROM() {
  EEPROM.begin(EEPROM_SIZE);
  EEPROM.get(CONFIG_START, savedConfig);
  EEPROM.end();
  
  // Validate checksum
  if (savedConfig.checksum != 'V') {
    // First time or corrupted - use defaults
    strcpy(savedConfig.ssid, "");
    strcpy(savedConfig.password, "");
    strcpy(savedConfig.mqttServer, "5013cd33cc4841a0b2537c65d64aa6e7.s1.eu.hivemq.cloud");
    savedConfig.mqttPort = 8883;
    strcpy(savedConfig.mqttUser, "iot_device");
    strcpy(savedConfig.mqttPass, "bacJjRNFYB@v9JT");
    savedConfig.configured = false;
    savedConfig.checksum = 'V';
  }
}

void saveConfigToEEPROM() {
  savedConfig.checksum = 'V';
  EEPROM.begin(EEPROM_SIZE);
  EEPROM.put(CONFIG_START, savedConfig);
  EEPROM.commit();
  EEPROM.end();
  Serial.println("Config saved to EEPROM");
}

void startAPMode() {
  apModeActive = true;
  WiFi.mode(WIFI_AP_STA);  // Cho phép cả AP và STA để scan WiFi
  WiFi.softAP("ESP8266_SmartHome", "12345678");
  delay(500);  // Đợi AP khởi động
  
  Serial.println("\n========================================");
  Serial.println("✓ AP Mode Started!");
  Serial.println("WiFi Name: ESP8266_SmartHome");
  Serial.println("Password:  12345678");
  Serial.print("AP IP:     ");
  Serial.println(WiFi.softAPIP());
  Serial.println("========================================");
  Serial.println("Open browser: http://192.168.4.1");
  Serial.println("========================================\n");
  
  // Đảm bảo web server chạy
  if (!configServer.client()) {
    configServer.begin();
    Serial.println("Web server restarted on port 80");
  }
}

void sendCorsHeaders() {
  configServer.sendHeader("Access-Control-Allow-Origin", "*");
  configServer.sendHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  configServer.sendHeader("Access-Control-Allow-Headers", "Content-Type");
}

void setupConfigServer() {
  loadConfigFromEEPROM();
  
  // ===== API ENDPOINTS =====
  
  // Simple ping endpoint (test server đang chạy)
  configServer.on("/ping", HTTP_GET, []() {
    configServer.send(200, "text/plain", "pong");
  });
  
  // Health check
  configServer.on("/", HTTP_GET, []() {
    sendCorsHeaders();
    String html = "<html><head><meta charset='UTF-8'></head><body>";
    html += "<h1>ESP8266 IoT Smart Home</h1>";
    html += "<p>Firmware: " FIRMWARE_VERSION "</p>";
    html += "<p>IP: " + WiFi.softAPIP().toString() + "</p>";
    html += "<p>Heap: " + String(ESP.getFreeHeap()) + " bytes</p>";
    html += "<hr>";
    html += "<form action='/api/wifi/config' method='POST'>";
    html += "<h2>Cấu hình WiFi</h2>";
    html += "SSID: <input name='ssid' value='" + String(savedConfig.ssid) + "'><br><br>";
    html += "Password: <input name='password' type='password'><br><br>";
    html += "<button type='submit'>Lưu & Restart</button>";
    html += "</form>";
    html += "<hr><p><a href='/update'>Firmware Update</a></p>";
    html += "</body></html>";
    configServer.send(200, "text/html", html);
  });
  
  // Handle form POST cho web browser
  configServer.on("/api/wifi/config", HTTP_POST, []() {
    sendCorsHeaders();
    
    // Check if this is form submission
    if (configServer.hasArg("ssid")) {
      strlcpy(savedConfig.ssid, configServer.arg("ssid").c_str(), sizeof(savedConfig.ssid));
      if (configServer.hasArg("password")) {
        strlcpy(savedConfig.password, configServer.arg("password").c_str(), sizeof(savedConfig.password));
      }
      savedConfig.configured = true;
      saveConfigToEEPROM();
      
      configServer.send(200, "text/html", 
        "<h1>Đã lưu!</h1><p>ESP sẽ restart trong 3 giây...</p>");
      delay(3000);
      ESP.restart();
      return;
    }
    
    // JSON body (from Flutter app)
    if (configServer.hasArg("plain")) {
      StaticJsonDocument<512> doc;
      DeserializationError error = deserializeJson(doc, configServer.arg("plain"));
      
      if (error) {
        configServer.send(400, "application/json", "{\"error\":\"Invalid JSON\"}");
        return;
      }
      
      // Update config
      if (doc.containsKey("ssid")) {
        strlcpy(savedConfig.ssid, doc["ssid"], sizeof(savedConfig.ssid));
      }
      if (doc.containsKey("password")) {
        strlcpy(savedConfig.password, doc["password"], sizeof(savedConfig.password));
      }
      if (doc.containsKey("mqttServer")) {
        strlcpy(savedConfig.mqttServer, doc["mqttServer"], sizeof(savedConfig.mqttServer));
      }
      if (doc.containsKey("mqttPort")) {
        savedConfig.mqttPort = doc["mqttPort"];
      }
      if (doc.containsKey("mqttUsername")) {
        strlcpy(savedConfig.mqttUser, doc["mqttUsername"], sizeof(savedConfig.mqttUser));
      }
      if (doc.containsKey("mqttPassword")) {
        strlcpy(savedConfig.mqttPass, doc["mqttPassword"], sizeof(savedConfig.mqttPass));
      }
      
      savedConfig.configured = true;
      saveConfigToEEPROM();
      
      configServer.send(200, "application/json", "{\"success\":true}");
      return;
    }
    
    configServer.send(400, "application/json", "{\"error\":\"No body\"}");
  });
  
  // Get device info
  configServer.on("/api/info", HTTP_GET, []() {
    sendCorsHeaders();
    StaticJsonDocument<512> doc;
    
    doc["deviceId"] = ESP.getChipId();
    doc["firmwareVersion"] = FIRMWARE_VERSION;
    doc["ipAddress"] = WiFi.localIP().toString();
    doc["apIpAddress"] = WiFi.softAPIP().toString();
    doc["macAddress"] = WiFi.macAddress();
    doc["freeHeap"] = ESP.getFreeHeap();
    doc["uptime"] = millis() / 1000;
    doc["wifiSsid"] = WiFi.SSID();
    doc["wifiRssi"] = WiFi.RSSI();
    doc["mqttConnected"] = mqttClient.connected();
    doc["apMode"] = apModeActive;
    
    String response;
    serializeJson(doc, response);
    configServer.send(200, "application/json", response);
  });
  
  // Get WiFi config
  configServer.on("/api/wifi/config", HTTP_GET, []() {
    sendCorsHeaders();
    StaticJsonDocument<256> doc;
    
    doc["ssid"] = savedConfig.ssid;
    doc["mqttServer"] = savedConfig.mqttServer;
    doc["mqttPort"] = savedConfig.mqttPort;
    doc["mqttUsername"] = savedConfig.mqttUser;
    // Don't send passwords
    
    String response;
    serializeJson(doc, response);
    configServer.send(200, "application/json", response);
  });
  
  // Scan WiFi networks
  configServer.on("/api/wifi/scan", HTTP_GET, []() {
    sendCorsHeaders();
    
    int n = WiFi.scanNetworks();
    StaticJsonDocument<1024> doc;
    JsonArray networks = doc.to<JsonArray>();
    
    for (int i = 0; i < n && i < 10; i++) {
      JsonObject network = networks.createNestedObject();
      network["ssid"] = WiFi.SSID(i);
      network["rssi"] = WiFi.RSSI(i);
      network["secured"] = WiFi.encryptionType(i) != ENC_TYPE_NONE;
      network["encryption"] = WiFi.encryptionType(i) == ENC_TYPE_WEP ? "WEP" :
                              WiFi.encryptionType(i) == ENC_TYPE_TKIP ? "WPA" :
                              WiFi.encryptionType(i) == ENC_TYPE_CCMP ? "WPA2" :
                              WiFi.encryptionType(i) == ENC_TYPE_AUTO ? "AUTO" : "OPEN";
    }
    
    String response;
    serializeJson(doc, response);
    configServer.send(200, "application/json", response);
  });
  
  // MQTT config update
  configServer.on("/api/mqtt/config", HTTP_POST, []() {
    sendCorsHeaders();
    
    if (!configServer.hasArg("plain")) {
      configServer.send(400, "application/json", "{\"error\":\"No body\"}");
      return;
    }
    
    StaticJsonDocument<256> doc;
    DeserializationError error = deserializeJson(doc, configServer.arg("plain"));
    
    if (error) {
      configServer.send(400, "application/json", "{\"error\":\"Invalid JSON\"}");
      return;
    }
    
    if (doc.containsKey("server")) {
      strlcpy(savedConfig.mqttServer, doc["server"], sizeof(savedConfig.mqttServer));
    }
    if (doc.containsKey("port")) {
      savedConfig.mqttPort = doc["port"];
    }
    if (doc.containsKey("username")) {
      strlcpy(savedConfig.mqttUser, doc["username"], sizeof(savedConfig.mqttUser));
    }
    if (doc.containsKey("password")) {
      strlcpy(savedConfig.mqttPass, doc["password"], sizeof(savedConfig.mqttPass));
    }
    
    saveConfigToEEPROM();
    configServer.send(200, "application/json", "{\"success\":true}");
  });
  
  // Restart device
  configServer.on("/api/restart", HTTP_POST, []() {
    sendCorsHeaders();
    configServer.send(200, "application/json", "{\"success\":true,\"message\":\"Restarting...\"}");
    delay(500);
    ESP.restart();
  });
  
  // Factory reset
  configServer.on("/api/factory-reset", HTTP_POST, []() {
    sendCorsHeaders();
    
    // Clear EEPROM
    EEPROM.begin(EEPROM_SIZE);
    for (int i = 0; i < EEPROM_SIZE; i++) {
      EEPROM.write(i, 0);
    }
    EEPROM.commit();
    EEPROM.end();
    
    configServer.send(200, "application/json", "{\"success\":true,\"message\":\"Factory reset complete\"}");
    delay(500);
    ESP.restart();
  });
  
  // OTA check
  configServer.on("/api/ota/check", HTTP_GET, []() {
    sendCorsHeaders();
    StaticJsonDocument<256> doc;
    
    doc["update_available"] = false; // Set true when new version available
    doc["current_version"] = FIRMWARE_VERSION;
    doc["latest_version"] = FIRMWARE_VERSION;
    
    String response;
    serializeJson(doc, response);
    configServer.send(200, "application/json", response);
  });
  
  // OTA status
  configServer.on("/api/ota/status", HTTP_GET, []() {
    sendCorsHeaders();
    StaticJsonDocument<128> doc;
    
    doc["status"] = "idle";
    doc["progress"] = 0;
    
    String response;
    serializeJson(doc, response);
    configServer.send(200, "application/json", response);
  });
  
  // CORS preflight
  configServer.on("/api/wifi/config", HTTP_OPTIONS, []() {
    sendCorsHeaders();
    configServer.send(204);
  });
  configServer.on("/api/mqtt/config", HTTP_OPTIONS, []() {
    sendCorsHeaders();
    configServer.send(204);
  });
  configServer.on("/api/restart", HTTP_OPTIONS, []() {
    sendCorsHeaders();
    configServer.send(204);
  });
  configServer.on("/api/factory-reset", HTTP_OPTIONS, []() {
    sendCorsHeaders();
    configServer.send(204);
  });
  
  // Web-based config page
  configServer.on("/config", HTTP_GET, []() {
    String html = R"rawliteral(
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>ESP8266 Config</title>
  <style>
    body { font-family: Arial; max-width: 400px; margin: 50px auto; padding: 20px; }
    h1 { color: #333; }
    input, select { width: 100%; padding: 10px; margin: 5px 0 15px; box-sizing: border-box; }
    button { background: #4CAF50; color: white; padding: 15px; border: none; width: 100%; cursor: pointer; }
    button:hover { background: #45a049; }
    .danger { background: #f44336; }
  </style>
</head>
<body>
  <h1>WiFi Configuration</h1>
  <form action="/save" method="POST">
    <label>WiFi SSID:</label>
    <input type="text" name="ssid" required>
    <label>WiFi Password:</label>
    <input type="password" name="password">
    <label>MQTT Server:</label>
    <input type="text" name="mqtt_server" value=")rawliteral" + String(savedConfig.mqttServer) + R"rawliteral(">
    <label>MQTT Port:</label>
    <input type="number" name="mqtt_port" value=")rawliteral" + String(savedConfig.mqttPort) + R"rawliteral(">
    <label>MQTT Username:</label>
    <input type="text" name="mqtt_user" value=")rawliteral" + String(savedConfig.mqttUser) + R"rawliteral(">
    <label>MQTT Password:</label>
    <input type="password" name="mqtt_pass">
    <button type="submit">Save & Restart</button>
  </form>
  <br>
  <form action="/api/factory-reset" method="POST">
    <button type="submit" class="danger">Factory Reset</button>
  </form>
</body>
</html>
)rawliteral";
    configServer.send(200, "text/html", html);
  });
  
  // Save config from web form
  configServer.on("/save", HTTP_POST, []() {
    if (configServer.hasArg("ssid")) {
      strlcpy(savedConfig.ssid, configServer.arg("ssid").c_str(), sizeof(savedConfig.ssid));
    }
    if (configServer.hasArg("password") && configServer.arg("password").length() > 0) {
      strlcpy(savedConfig.password, configServer.arg("password").c_str(), sizeof(savedConfig.password));
    }
    if (configServer.hasArg("mqtt_server")) {
      strlcpy(savedConfig.mqttServer, configServer.arg("mqtt_server").c_str(), sizeof(savedConfig.mqttServer));
    }
    if (configServer.hasArg("mqtt_port")) {
      savedConfig.mqttPort = configServer.arg("mqtt_port").toInt();
    }
    if (configServer.hasArg("mqtt_user")) {
      strlcpy(savedConfig.mqttUser, configServer.arg("mqtt_user").c_str(), sizeof(savedConfig.mqttUser));
    }
    if (configServer.hasArg("mqtt_pass") && configServer.arg("mqtt_pass").length() > 0) {
      strlcpy(savedConfig.mqttPass, configServer.arg("mqtt_pass").c_str(), sizeof(savedConfig.mqttPass));
    }
    
    savedConfig.configured = true;
    saveConfigToEEPROM();
    
    configServer.send(200, "text/html", 
      "<h1>Config Saved!</h1><p>Restarting in 3 seconds...</p>"
      "<script>setTimeout(function(){window.location='/';}, 5000);</script>"
    );
    
    delay(3000);
    ESP.restart();
  });
  
  // Setup HTTP update server for OTA via web
  httpUpdater.setup(&configServer, "/update");
  
  configServer.begin();
  Serial.println("Config server started on port 80");
}

void handleConfigServer() {
  configServer.handleClient();
}

// Helper function để lấy saved config
const char* getSavedSSID() { return savedConfig.ssid; }
const char* getSavedPassword() { return savedConfig.password; }
const char* getSavedMqttServer() { return savedConfig.mqttServer; }
int getSavedMqttPort() { return savedConfig.mqttPort; }
const char* getSavedMqttUser() { return savedConfig.mqttUser; }
const char* getSavedMqttPass() { return savedConfig.mqttPass; }
bool isConfigured() { return savedConfig.configured; }

#endif
