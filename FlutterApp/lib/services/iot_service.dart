import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/iot_data_model.dart';

class IoTService {
  final String baseUrl;
  final String wsUrl;
  
  WebSocketChannel? _channel;

  IoTService({
    this.baseUrl = 'https://iot-btl-9tr7.onrender.com', // Cloud server URL
    this.wsUrl = 'wss://iot-btl-9tr7.onrender.com',     // Cloud WebSocket (same port as HTTP)
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

  // Điều khiển thiết bị chung (generic control)
  Future<bool> controlDevice(String device, String action) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/control'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'device': device,
          'action': action,
        }),
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      print('Error controlling $device: $e');
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

  // ===== NEW POSTGRESQL APIs =====
  
  // Lấy lịch sử sensor data từ database
  Future<List<Map<String, dynamic>>> getSensorHistory({int limit = 100, int offset = 0}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/sensor/history?limit=$limit&offset=$offset'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('Error getting sensor history: $e');
      return [];
    }
  }

  // Lấy sensor data theo khoảng thời gian
  Future<List<Map<String, dynamic>>> getSensorDataByRange(DateTime start, DateTime end) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/sensor/range?start=${start.toIso8601String()}&end=${end.toIso8601String()}'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('Error getting sensor data by range: $e');
      return [];
    }
  }

  // Lấy thống kê
  Future<Map<String, dynamic>?> getStatistics({int hours = 24}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/sensor/statistics?hours=$hours'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Error getting statistics: $e');
      return null;
    }
  }

  // Lấy event logs
  Future<List<Map<String, dynamic>>> getEvents({int limit = 50, String? type, String? severity}) async {
    try {
      var url = '$baseUrl/api/events?limit=$limit';
      if (type != null) url += '&type=$type';
      if (severity != null) url += '&severity=$severity';
      
      final response = await http.get(
        Uri.parse(url),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('Error getting events: $e');
      return [];
    }
  }

  // Lấy trạng thái tất cả thiết bị
  Future<List<Map<String, dynamic>>> getDeviceStatuses() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/devices/status'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('Error getting device statuses: $e');
      return [];
    }
  }
}
