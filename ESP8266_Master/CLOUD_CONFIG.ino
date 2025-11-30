/*
 * ESP8266 - Cloud Configuration for HiveMQ
 * 
 * Replace these values with your HiveMQ Cloud credentials
 */

// ===== WiFi Configuration (unchanged) =====
const char* ssid = "your-wifi-ssid";
const char* password = "your-wifi-password";

// ===== MQTT Cloud Broker Configuration =====
// Option 1: LOCAL Mosquitto (for development)
/*
const char* mqtt_server = "10.137.147.176";
const int mqtt_port = 1883;
const char* mqtt_user = "";
const char* mqtt_pass = "";
bool use_tls = false;
*/

// Option 2: HiveMQ Cloud (for production - remote access)
const char* mqtt_server = "abc123xyz.s1.eu.hivemq.cloud";  // Replace with your cluster URL
const int mqtt_port = 8883;  // TLS port
const char* mqtt_user = "your-hivemq-username";  // Replace with your username
const char* mqtt_pass = "your-hivemq-password";  // Replace with your password
bool use_tls = true;

// ===== Setup Code Changes =====
/*
In your ESP8266_Master.ino setup(), add TLS support:

#include <WiFiClientSecure.h>

// Replace:
WiFiClient espClient;
PubSubClient client(espClient);

// With:
WiFiClientSecure espClient;
PubSubClient client(espClient);

void setup() {
  Serial.begin(115200);
  
  // Connect WiFi
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWiFi connected!");
  
  // Setup MQTT
  if (use_tls) {
    espClient.setInsecure();  // Skip certificate validation (for testing)
    // For production, use: espClient.setCACert(ca_cert);
  }
  
  client.setServer(mqtt_server, mqtt_port);
  client.setCallback(callback);
}

void reconnectMQTT() {
  while (!client.connected()) {
    Serial.print("Connecting to MQTT...");
    
    String clientId = "ESP8266_" + String(random(0xffff), HEX);
    
    bool connected;
    if (use_tls && strlen(mqtt_user) > 0) {
      connected = client.connect(clientId.c_str(), mqtt_user, mqtt_pass);
    } else {
      connected = client.connect(clientId.c_str());
    }
    
    if (connected) {
      Serial.println("connected!");
      // Subscribe to topics
      client.subscribe("iot/control/#");
    } else {
      Serial.print("failed, rc=");
      Serial.print(client.state());
      Serial.println(" retry in 5s");
      delay(5000);
    }
  }
}
*/

// ===== Testing Steps =====
/*
1. Update credentials above
2. Modify ESP8266_Master.ino with code changes
3. Upload to ESP8266
4. Open Serial Monitor (115200 baud)
5. Check for "connected!" message
6. Test from Flutter app on 4G/5G network

Expected output:
WiFi connected!
IP: 192.168.x.x
Connecting to MQTT...connected!
Subscribed to topics
📤 Published: {"temperature":26.5, ...}
*/
