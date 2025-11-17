// ===== CẤU HÌNH HỆ THỐNG =====
// File này chứa tất cả cấu hình có thể thay đổi

// WiFi Configuration
const char* WIFI_SSID = "YOUR_WIFI_SSID";
const char* WIFI_PASSWORD = "YOUR_WIFI_PASSWORD";

// Server Configuration
const char* SERVER_IP = "192.168.1.100";  // IP máy tính chạy Node.js server
const int SERVER_PORT = 3000;

// I2C Addresses
#define SLAVE1_ADDRESS 8  // Arduino Uno 1
#define SLAVE2_ADDRESS 9  // Arduino Uno 2

// Update Interval
const unsigned long UPDATE_INTERVAL = 2000;  // Gửi dữ liệu mỗi 2 giây (ms)

// RFID Valid Card UID (thay đổi theo thẻ của bạn)
// Quẹt thẻ và xem Serial Monitor để lấy UID
byte VALID_CARD_UID[4] = {0xDE, 0xAD, 0xBE, 0xEF};

// PIR Timeout (tắt LED sau bao lâu không có chuyển động)
const unsigned long PIR_TIMEOUT = 7000;  // 7 giây (ms)

// Intruder Detection Distance (cảnh báo đột nhập khi khoảng cách < threshold)
const float INTRUDER_DISTANCE_THRESHOLD = 50.0;  // 50 cm

// Servo Angles
const int DOOR_CLOSED_ANGLE = 0;   // Góc servo khi cửa đóng
const int DOOR_OPEN_ANGLE = 90;    // Góc servo khi cửa mở

// DHT Sensor Type
#define DHT_TYPE DHT11  // DHT11 hoặc DHT22

// ===== PIN CONFIGURATION =====

// Arduino Uno 1 Pins
#define UNO1_PIR_PIN 2
#define UNO1_DHT_PIN 3
#define UNO1_LED_PIR_PIN 11
#define UNO1_LED_BUTTON_PIN 10
#define UNO1_BUTTON_PIN 12

// Arduino Uno 2 Pins
#define UNO2_BUTTON_OPEN_PIN A0
#define UNO2_BUTTON_CLOSE_PIN A1
#define UNO2_SERVO_PIN A2
#define UNO2_TRIG_PIN 4
#define UNO2_ECHO_PIN 5
#define UNO2_RFID_RST_PIN 9
#define UNO2_RFID_SS_PIN 10

// ESP8266 I2C Pins
#define ESP_SDA_PIN 4  // D2
#define ESP_SCL_PIN 5  // D1
