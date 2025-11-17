# 📱 HƯỚNG DẪN BUILD & CHẠY APP

## 🔧 YÊU CẦU

- Flutter SDK >= 3.0.0
- Android SDK (nếu build Android)
- VS Code hoặc Android Studio

## 📦 BƯỚC 1: CÀI ĐẶT

### 1.1. Cài Flutter dependencies
```bash
cd c:\Users\hieuu\OneDrive\Desktop\btlIOT\FlutterApp
flutter pub get
```

### 1.2. Kiểm tra Flutter
```bash
flutter doctor
```

## ⚙️ BƯỚC 2: CẤU HÌNH

### 2.1. Sửa IP Server
Mở file `lib\services\iot_service.dart` (dòng 11-12):

```dart
IoTService({
  this.baseUrl = 'http://192.168.1.100:3000', // ← Thay IP PC của bạn
  this.wsUrl = 'ws://192.168.1.100:3001',
});
```

**Cách tìm IP:**
```cmd
ipconfig
```
Tìm dòng **IPv4 Address** (ví dụ: 192.168.1.100)

## 📱 BƯỚC 3: CHẠY APP

### 3.1. Kết nối thiết bị

**Android Phone:**
1. Bật Developer Options
2. Bật USB Debugging
3. Kết nối USB với PC
4. Chấp nhận USB Debugging

**Hoặc dùng Emulator:**
```bash
flutter emulators --launch <emulator_id>
```

### 3.2. Kiểm tra device
```bash
flutter devices
```

### 3.3. Chạy app
```bash
flutter run
```

Hoặc chọn device cụ thể:
```bash
flutter run -d <device_id>
```

## 📦 BƯỚC 4: BUILD APK

### 4.1. Build APK Release
```bash
flutter build apk --release
```

### 4.2. Vị trí file APK
```
build\app\outputs\flutter-apk\app-release.apk
```

### 4.3. Cài APK vào điện thoại
- Copy file `app-release.apk` vào điện thoại
- Mở file và cài đặt
- Cho phép "Install from Unknown Sources"

## 🎯 BƯỚC 5: SỬ DỤNG

### 5.1. Đảm bảo server chạy
```bash
cd c:\Users\hieuu\OneDrive\Desktop\btlIOT\NodeJS_Server
npm start
```

### 5.2. Kết nối WiFi
- Đảm bảo điện thoại và PC **cùng mạng WiFi**
- Kiểm tra IP trong `iot_service.dart` đúng với IP PC

### 5.3. Đăng nhập
```
Username: admin
Password: admin123
```

## 🐛 TROUBLESHOOTING

### Lỗi: "Connection refused"
**Nguyên nhân:** App không kết nối được server

**Giải pháp:**
1. Kiểm tra Node.js server đang chạy
2. Kiểm tra IP trong `iot_service.dart`
3. Ping IP từ điện thoại:
   - Android: Dùng app "Ping & Net"
   - Nếu ping không được → Firewall đang chặn

4. Tắt Firewall Windows hoặc cho phép port:
   ```
   netsh advfirewall firewall add rule name="NodeJS Port 3000" dir=in action=allow protocol=TCP localport=3000
   netsh advfirewall firewall add rule name="NodeJS Port 3001" dir=in action=allow protocol=TCP localport=3001
   ```

### Lỗi: "WebSocket connection failed"
1. Kiểm tra WebSocket server chạy (port 3001)
2. Xem log: `flutter run --verbose`

### Lỗi: "Package not found"
```bash
flutter clean
flutter pub get
flutter run
```

### Lỗi compile
```bash
flutter clean
flutter pub cache repair
flutter pub get
```

## 📊 CẤU TRÚC APP

```
FlutterApp/
├── lib/
│   ├── main.dart              # Entry point
│   ├── models/                # Data models
│   ├── services/              # API & Database
│   ├── providers/             # State management
│   ├── screens/               # UI screens
│   └── widgets/               # Reusable components
├── android/                   # Android config
├── pubspec.yaml              # Dependencies
└── SETUP.md                  # Hướng dẫn này
```

## 🎨 TÍNH NĂNG ĐÃ CÓ

✅ Login với authentication
✅ Real-time data qua WebSocket
✅ Hiển thị nhiệt độ, độ ẩm
✅ Hiển thị PIR sensor
✅ Điều khiển LED 2 (On/Off/Toggle)
✅ Điều khiển cửa (Open/Close/Toggle)
✅ Hiển thị khoảng cách HC-SR04
✅ Thông báo tự động mở cửa
✅ Connection status indicator
✅ Pull-to-refresh
✅ Logout

## 🚀 BUILD THÀNH CÔNG!

Nếu làm đúng các bước trên, bạn sẽ có:
1. App chạy được trên điện thoại
2. Kết nối real-time với server
3. Điều khiển LED và cửa từ app
4. Xem dữ liệu sensor real-time

**Chúc bạn thành công!** 🎉
