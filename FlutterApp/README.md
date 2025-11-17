# 📱 IoT Smart Home - Flutter Mobile App

Ứng dụng di động điều khiển hệ thống IoT Smart Home với ESP8266 và Arduino.

## ✨ TÍNH NĂNG

### 🔐 Authentication
- ✅ Đăng nhập với username/password
- ✅ Session management (auto-login)
- ✅ Database JSON local
- ✅ Tài khoản mặc định: `admin / admin123`

### 🏠 Dashboard
- ✅ **Nhiệt độ & Độ ẩm** - Hiển thị real-time từ DHT sensor
- ✅ **PIR Sensor** - Phát hiện chuyển động
- ✅ **LED 1** - Tự động điều khiển bởi PIR (chỉ xem)
- ✅ **LED 2** - Điều khiển: Bật/Tắt/Toggle
- ✅ **Cửa** - Điều khiển: Mở/Đóng/Toggle, hiển thị trạng thái
- ✅ **HC-SR04** - Khoảng cách, thông báo tự động mở cửa < 10cm
- ✅ **RFID** - Trạng thái truy cập thẻ

### 🌐 Real-time
- ✅ WebSocket connection
- ✅ Auto-update khi có dữ liệu mới
- ✅ Connection status indicator
- ✅ Pull-to-refresh
- ✅ Auto-reconnect

## 🚀 HƯỚNG DẪN NHANH

### 1. Cài dependencies
```bash
cd FlutterApp
flutter pub get
```

### 2. Sửa IP server
File: `lib/services/iot_service.dart`
```dart
baseUrl = 'http://192.168.1.100:3000' // IP máy tính của bạn
```

### 3. Chạy app
```bash
flutter run
```

### 4. Build APK
```bash
flutter build apk --release
```

📦 APK: `build/app/outputs/flutter-apk/app-release.apk`

## 📖 TÀI LIỆU

- **[BUILD_GUIDE.md](BUILD_GUIDE.md)** - Hướng dẫn build & troubleshooting chi tiết
- **[SETUP.md](SETUP.md)** - Cấu hình & chức năng
- **[TODO.md](TODO.md)** - Checklist development

## 🎨 SCREENSHOTS

### Login Screen
- Material Design 3
- Gradient background
- Form validation
- Loading state

### Home Dashboard
- Temperature & Humidity cards
- Sensor status cards với active states
- Control buttons cho LED và cửa
- Real-time connection indicator
- Pull-to-refresh

## 🛠️ TECH STACK

- **Flutter** 3.0+
- **Provider** - State management
- **HTTP** - REST API
- **WebSocket** - Real-time communication
- **SharedPreferences** - Local storage
- **JSON** - Database format
- **Material Design 3** - UI/UX
- **Flutter Animate** - Animations

## 📂 CẤU TRÚC

```
lib/
├── main.dart                    # App entry
├── models/
│   ├── user_model.dart          # User data
│   ├── user_model.g.dart        # Generated JSON
│   ├── iot_data_model.dart      # IoT data
│   └── iot_data_model.g.dart    # Generated JSON
├── services/
│   ├── auth_service.dart        # Authentication
│   ├── database_service.dart    # JSON database
│   └── iot_service.dart         # API & WebSocket
├── providers/
│   ├── auth_provider.dart       # Auth state
│   └── iot_provider.dart        # IoT state
├── screens/
│   ├── splash_screen.dart       # Loading
│   ├── login_screen.dart        # Login
│   └── home_screen.dart         # Dashboard
└── widgets/
    ├── sensor_card.dart         # Sensor display
    ├── control_card.dart        # Control panel
    └── connection_status.dart   # Status indicator
```

## 🔌 API ENDPOINTS

```
GET  /api/status         # Lấy trạng thái
POST /api/led2/on        # Bật LED 2
POST /api/led2/off       # Tắt LED 2
POST /api/led2/toggle    # Toggle LED 2
POST /api/door/open      # Mở cửa
POST /api/door/close     # Đóng cửa
POST /api/door/toggle    # Toggle cửa

WebSocket: ws://IP:3001  # Real-time data
```

## ⚠️ LƯU Ý

1. **Cùng mạng WiFi**: Điện thoại và PC phải cùng mạng
2. **Server chạy**: Node.js server phải đang chạy
3. **Firewall**: Cho phép port 3000, 3001
4. **IP đúng**: Kiểm tra IP trong `iot_service.dart`

## 🐛 TROUBLESHOOTING

### Connection refused
```bash
# Kiểm tra IP
ipconfig

# Cho phép port
netsh advfirewall firewall add rule name="NodeJS" dir=in action=allow protocol=TCP localport=3000
```

### Package not found
```bash
flutter clean
flutter pub get
```

### Build lỗi
```bash
flutter clean
flutter pub cache repair
flutter pub get
flutter run
```

## 👨‍💻 DEVELOPMENT

```bash
# Run với hot-reload
flutter run

# Build APK debug
flutter build apk --debug

# Build APK release
flutter build apk --release

# Clean project
flutter clean
```

## 📝 DATABASE

Database lưu dưới dạng JSON:
- `users.json` - Danh sách user
- `credentials.json` - Mật khẩu

Vị trí: `/data/data/com.example.iot_smart_home/app_flutter/`

## 🎯 ROADMAP

- [ ] Biểu đồ nhiệt độ/độ ẩm
- [ ] Lịch sử log
- [ ] Push notification
- [ ] Quản lý nhiều user
- [ ] Dark mode toggle
- [ ] Widget Android

---

**Developed with ❤️ using Flutter**
