# 📱 IoT SMART HOME - FLUTTER MOBILE APP

## 🚀 HƯỚNG DẪN CÀI ĐẶT

### **Yêu cầu:**
- Flutter SDK >= 3.0.0
- Dart SDK >= 3.0.0
- Android Studio / VS Code
- Android device hoặc Emulator

---

## 📦 BƯỚC 1: CÀI ĐẶT DEPENDENCIES

```bash
cd FlutterApp
flutter pub get
```

---

## 🔧 BƯỚC 2: CẤU HÌNH SERVER IP

Mở file `lib/services/iot_service.dart` và sửa IP:

```dart
IoTService({
  this.baseUrl = 'http://192.168.1.100:3000', // ← Thay IP máy tính của bạn
  this.wsUrl = 'ws://192.168.1.100:3001',
});
```

---

## ⚙️ BƯỚC 3: GENERATE CODE (Nếu cần)

Nếu sử dụng JSON serialization:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

---

## 📱 BƯỚC 4: CHẠY ỨNG DỤNG

### **Android:**
```bash
flutter run
```

### **Build APK:**
```bash
flutter build apk --release
```

APK sẽ nằm tại: `build/app/outputs/flutter-apk/app-release.apk`

---

## 👤 TÀI KHOẢN MẶC ĐỊNH

```
Username: admin
Password: admin123
```

**Lưu ý:** Database được lưu dưới dạng JSON trong thư mục app data.

---

## 🎨 TÍNH NĂNG

### **Authentication:**
- ✅ Đăng nhập với username/password
- ✅ Đăng ký tài khoản mới
- ✅ Lưu session (auto-login)
- ✅ Database JSON local

### **IoT Control:**
- ✅ Xem nhiệt độ, độ ẩm real-time
- ✅ Xem trạng thái PIR, LED, cửa
- ✅ Điều khiển LED 2 (Bật/Tắt/Toggle)
- ✅ Điều khiển cửa (Mở/Đóng/Toggle)
- ✅ Hiển thị khoảng cách HC-SR04
- ✅ Thông báo tự động mở cửa
- ✅ WebSocket real-time updates

### **UI/UX:**
- ✅ Material Design 3
- ✅ Dark/Light theme
- ✅ Animation & transitions
- ✅ Responsive layout
- ✅ Custom fonts (Google Fonts)

---

## 📂 CẤU TRÚC PROJECT

```
FlutterApp/
├── lib/
│   ├── main.dart                 # Entry point
│   ├── models/
│   │   ├── user_model.dart       # User model
│   │   └── iot_data_model.dart   # IoT data model
│   ├── services/
│   │   ├── auth_service.dart     # Authentication logic
│   │   ├── database_service.dart # JSON database
│   │   └── iot_service.dart      # IoT API & WebSocket
│   ├── providers/
│   │   ├── auth_provider.dart    # Auth state management
│   │   └── iot_provider.dart     # IoT state management
│   ├── screens/
│   │   ├── splash_screen.dart    # Splash screen
│   │   ├── login_screen.dart     # Login page
│   │   ├── register_screen.dart  # Register page
│   │   └── home_screen.dart      # Main dashboard
│   └── widgets/
│       ├── sensor_card.dart      # Sensor display card
│       └── control_button.dart   # Control buttons
├── pubspec.yaml                  # Dependencies
└── README_FLUTTER.md             # Hướng dẫn này
```

---

## 🗄️ DATABASE JSON

### **users.json** - Danh sách người dùng
```json
[
  {
    "id": "1",
    "username": "admin",
    "email": "admin@smarthome.com",
    "fullName": "Administrator",
    "role": "admin",
    "createdAt": "2025-11-17T10:00:00.000Z",
    "lastLogin": "2025-11-17T16:47:00.000Z"
  }
]
```

### **credentials.json** - Mật khẩu
```json
{
  "1": {
    "username": "admin",
    "password": "admin123"
  }
}
```

**Vị trí file:** `/data/data/com.example.iot_smart_home/app_flutter/`

---

## 🔌 KẾT NỐI VỚI SERVER

App sử dụng:
- **HTTP REST API** (port 3000) - Điều khiển thiết bị
- **WebSocket** (port 3001) - Nhận dữ liệu real-time

### **API Endpoints:**
```
GET  /api/status         # Lấy trạng thái hiện tại
POST /api/led2/on        # Bật LED 2
POST /api/led2/off       # Tắt LED 2
POST /api/led2/toggle    # Toggle LED 2
POST /api/door/open      # Mở cửa
POST /api/door/close     # Đóng cửa
POST /api/door/toggle    # Toggle cửa
```

---

## 🛠️ TROUBLESHOOTING

### **Lỗi: "Connection refused"**
- Kiểm tra IP server trong `iot_service.dart`
- Đảm bảo điện thoại và PC cùng mạng WiFi
- Tắt Firewall hoặc cho phép port 3000, 3001

### **Lỗi: "WebSocket connection failed"**
- Kiểm tra Node.js server đang chạy
- Xem log: `flutter run --verbose`

### **Lỗi: "Build failed"**
- Chạy: `flutter clean`
- Chạy: `flutter pub get`
- Build lại

---

## 📸 SCREENSHOTS

### **Login Screen:**
- Username/password input
- Remember me checkbox
- Register link

### **Home Screen:**
- Temperature & Humidity cards
- PIR sensor status
- LED control buttons
- Door control buttons
- Distance sensor
- Auto-open notification

---

## 🎯 TƯƠNG LAI

- [ ] Push notification
- [ ] History log
- [ ] Charts & graphs
- [ ] Multi-user management
- [ ] Voice control
- [ ] Widget Android

---

**Developed with ❤️ using Flutter**
