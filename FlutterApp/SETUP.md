# Flutter App - HƯỚNG DẪN CHẠY

## 🚀 CÀI ĐẶT & CHẠY

### Bước 1: Cài dependencies
```bash
cd FlutterApp
flutter pub get
```

### Bước 2: Sửa IP server
Mở file `lib/services/iot_service.dart` và thay IP:
```dart
IoTService({
  this.baseUrl = 'http://192.168.1.100:3000', // ← IP máy tính của bạn
  this.wsUrl = 'ws://192.168.1.100:3001',
});
```

### Bước 3: Chạy app
```bash
flutter run
```

hoặc build APK:
```bash
flutter build apk --release
```

## 👤 ĐĂNG NHẬP

Tài khoản mặc định:
- **Username:** admin
- **Password:** admin123

## 📱 CHỨC NĂNG

1. **Login Screen**
   - Đăng nhập với username/password
   - Validation form
   - Loading state
   - Error handling

2. **Home Dashboard**
   - Nhiệt độ & Độ ẩm real-time
   - Trạng thái PIR sensor
   - Trạng thái LED 1 (tự động) & LED 2 (điều khiển)
   - Điều khiển LED 2: Bật/Tắt/Toggle
   - Trạng thái cửa
   - Điều khiển cửa: Mở/Đóng/Toggle
   - Khoảng cách HC-SR04
   - Thông báo tự động mở cửa
   - Trạng thái RFID access
   - Connection status indicator
   - Refresh data
   - Logout

3. **Real-time Updates**
   - WebSocket connection
   - Auto-update khi có dữ liệu mới
   - Reconnect khi mất kết nối

## 🎨 UI/UX

- Material Design 3
- Gradient backgrounds
- Card-based layout
- Smooth animations (flutter_animate)
- Active state indicators
- Loading states
- Error snackbars
- Pull-to-refresh

## 📊 CẤU TRÚC FILE

```
lib/
├── main.dart
├── models/
│   ├── user_model.dart
│   └── iot_data_model.dart
├── services/
│   ├── auth_service.dart
│   ├── database_service.dart
│   └── iot_service.dart
├── providers/
│   ├── auth_provider.dart
│   └── iot_provider.dart
├── screens/
│   ├── splash_screen.dart
│   ├── login_screen.dart
│   └── home_screen.dart
└── widgets/
    ├── sensor_card.dart
    ├── control_card.dart
    └── connection_status.dart
```

## ⚠️ LƯU Ý

- Đảm bảo Node.js server đang chạy
- Điện thoại và PC phải cùng mạng WiFi
- Tắt Firewall hoặc cho phép port 3000, 3001
- Database JSON tự động tạo khi chạy lần đầu
