import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/iot_data_model.dart';

class IoTService {
  final String baseUrl;
  final String wsUrl;
  
  WebSocketChannel? _channel;

  IoTService({
    this.baseUrl = 'http://10.137.147.176:3000', // Thay IP của PC
    this.wsUrl = 'ws://10.137.147.176:3001',
  });

  // Kết nối WebSocket
  WebSocketChannel connectWebSocket() {
    _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    return _channel!;
  }

  // Ngắt kết nối WebSocket
  void disconnectWebSocket() {
    _channel?.sink.close();
    _channel = null;
  }

  // Lấy dữ liệu hiện tại qua HTTP
  Future<IoTData?> getCurrentData() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/status'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return IoTData.fromJson(data);
      }
      return null;
    } catch (e) {
      print('Error getting current data: $e');
      return null;
    }
  }

  // Điều khiển LED 2
  Future<bool> controlLed2(String action) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/control'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'device': 'led2',
          'action': action,
        }),
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      print('Error controlling LED2: $e');
      return false;
    }
  }

  // Điều khiển cửa
  Future<bool> controlDoor(String action) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/control'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'device': 'door',
          'action': action,
        }),
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      print('Error controlling door: $e');
      return false;
    }
  }

  // Điều khiển quạt
  Future<bool> controlFan(String action) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/control'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'device': 'fan',
          'action': action,
        }),
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      print('Error controlling fan: $e');
      return false;
    }
  }

  // Kiểm tra kết nối
  Future<bool> checkConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/status'),
      ).timeout(const Duration(seconds: 3));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
