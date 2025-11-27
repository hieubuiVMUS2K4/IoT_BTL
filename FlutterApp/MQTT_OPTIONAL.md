# Hướng dẫn: Flutter kết nối trực tiếp MQTT (tùy chọn)

## Nếu muốn Flutter → MQTT trực tiếp (không qua server):

### 1. Thêm vào pubspec.yaml:
```yaml
dependencies:
  mqtt_client: ^10.2.0
```

### 2. Tạo file `lib/services/mqtt_service.dart`:
```dart
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'dart:convert';

class MqttService {
  late MqttServerClient client;
  
  Future<void> connect(String broker, int port) async {
    client = MqttServerClient(broker, 'FlutterApp_${DateTime.now().millisecondsSinceEpoch}');
    client.port = port;
    client.keepAlivePeriod = 20;
    
    try {
      await client.connect();
      print('✓ MQTT Connected');
    } catch (e) {
      print('✗ MQTT Error: $e');
      client.disconnect();
    }
  }
  
  Stream<Map<String, dynamic>> subscribeData() {
    client.subscribe('iot/sensors/data', MqttQos.atLeastOnce);
    
    return client.updates!.map((List<MqttReceivedMessage<MqttMessage>> messages) {
      final payload = messages[0].payload as MqttPublishMessage;
      final message = MqttPublishPayload.bytesToStringAsString(payload.payload.message);
      return jsonDecode(message);
    });
  }
  
  void publishControl(String device, String action) {
    final topic = 'iot/control/$device';
    final builder = MqttClientPayloadBuilder();
    builder.addString(action);
    client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
  }
}
```

## ⚠️ LƯU Ý:

**Khuyến nghị: GIỮ NGUYÊN** cấu trúc hiện tại (Flutter ↔ WebSocket ↔ Server ↔ MQTT ↔ ESP8266)

**Lý do:**
- Server làm bridge, quản lý kết nối MQTT tập trung
- Flutter không cần thư viện MQTT phức tạp
- Dễ debug và maintain hơn
- WebSocket đã hoạt động tốt

**Chỉ dùng MQTT trực tiếp nếu:**
- Không muốn chạy Node.js server
- Cần giảm độ trễ tối đa
- Có nhiều Flutter client cần kết nối
