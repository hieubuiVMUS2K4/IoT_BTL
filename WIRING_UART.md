# Hướng Dẫn Kết Nối Phần Cứng (Giao Thức UART)

Do hệ thống I2C hoạt động không ổn định, chúng ta đã chuyển sang giao thức UART (SoftwareSerial).
Dưới đây là sơ đồ kết nối chi tiết cho hệ thống mới.

## 1. Kết Nối ESP8266 (Master) với Arduino Uno 1 (Slave 1)

**Chức năng:** Điều khiển Đèn, Quạt, Cảm biến Nhiệt độ/Độ ẩm.

| ESP8266 (Master) | Arduino Uno 1 (Slave) | Chức năng |
| :--- | :--- | :--- |
| **D1 (GPIO 5)** | **Pin 5** | ESP RX <--- Uno TX |
| **D2 (GPIO 4)** | **Pin 4** | ESP TX ---> Uno RX |
| GND | GND | Chung Mass (Bắt buộc) |

*Lưu ý: Cấp nguồn riêng cho Arduino Uno nếu dùng nhiều thiết bị tải (Quạt, Đèn).*

## 2. Kết Nối ESP8266 (Master) với Arduino Uno 2 (Slave 2)

**Chức năng:** Điều khiển Cửa, RFID, Cảm biến Siêu âm.

| ESP8266 (Master) | Arduino Uno 2 (Slave) | Chức năng |
| :--- | :--- | :--- |
| **D5 (GPIO 14)** | **Pin 3** | ESP RX <--- Uno TX |
| **D6 (GPIO 12)** | **Pin 2** | ESP TX ---> Uno RX |
| GND | GND | Chung Mass (Bắt buộc) |

## 3. Cấu Hình Chân Trên Arduino Uno

### Arduino Uno 1 (Slave 1)
- **Pin 4:** RX (Nhận lệnh từ ESP)
- **Pin 5:** TX (Gửi dữ liệu sang ESP)
- **Pin 2:** PIR Sensor
- **Pin 3:** DHT Sensor
- **Pin 6, 7, 8:** L298N (Quạt)
- **Pin 10:** LED 2 (Button)
- **Pin 11:** LED 1 (PIR)
- **Pin 12:** Button

### Arduino Uno 2 (Slave 2)
- **Pin 2:** RX (Nhận lệnh từ ESP)
- **Pin 3:** TX (Gửi dữ liệu sang ESP)
- **Pin 4:** Trig (HC-SR04 - Siêu âm)
- **Pin 5:** Echo (HC-SR04 - Siêu âm)
- **Pin 6:** Servo (Cửa)
- **Pin 9:** RST (RFID)
- **Pin 10 (SDA):** RFID SS/SDA
- **Pin 11 (MOSI):** RFID MOSI
- **Pin 12 (MISO):** RFID MISO
- **Pin 13 (SCK):** RFID SCK
- **A0:** Button Mở
- **A1:** Button Đóng

## 4. Lưu Ý Quan Trọng
1. **Nạp Code:** Khi nạp code cho Arduino Uno, **KHÔNG CẦN** rút dây UART (Pin 2,3,4,5) vì chúng ta dùng SoftwareSerial, không trùng với Hardware Serial (Pin 0,1) dùng để nạp code.
2. **Nguồn:** Đảm bảo GND của tất cả các board (ESP8266, Uno 1, Uno 2) được nối chung với nhau.
3. **Baudrate:** Tất cả các kết nối UART đều chạy ở tốc độ **9600 baud**.
