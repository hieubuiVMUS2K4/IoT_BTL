# Hướng dẫn cài đặt MQTT cho hệ thống IoT

## 1. Cài đặt Mosquitto MQTT Broker (Windows)

### Download:
https://mosquitto.org/download/

### Cài đặt:
1. Chọn file `mosquitto-x.x.x-install-windows-x64.exe`
2. Cài đặt vào `C:\Program Files\mosquitto`
3. Mở PowerShell as Administrator

### Chạy Mosquitto:
```powershell
cd "C:\Program Files\mosquitto"
.\mosquitto.exe -v
```

Hoặc cài như Windows Service:
```powershell
net start mosquitto
```

### Kiểm tra:
```powershell
netstat -an | findstr 1883
```
Phải thấy: `0.0.0.0:1883` hoặc `[::]:1883`

## 2. MQTT Topics

### ESP8266 → Server (Publish):
- `iot/sensors/data` - Dữ liệu cảm biến (JSON)

### Server → ESP8266 (Subscribe):
- `iot/control/led2` - Điều khiển LED2 (on/off/toggle)
- `iot/control/fan` - Điều khiển quạt (on/off/toggle)
- `iot/control/door` - Điều khiển cửa (open/close/toggle)

### Server → Flutter (Broadcast):
- `iot/status` - Trạng thái hệ thống real-time

## 3. Cấu hình

**MQTT Broker IP**: Thay `192.168.0.110` bằng IP máy chạy Mosquitto
**Port**: 1883 (mặc định)
**Username/Password**: Không (anonymous) hoặc cấu hình trong `mosquitto.conf`
