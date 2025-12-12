import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/report_model.dart';

/// Service để cấu hình WiFi và OTA cho ESP8266
class WifiConfigService {
  String _espBaseUrl = 'http://192.168.4.1'; // AP mode default IP
  
  /// Đặt địa chỉ IP của ESP (khi đã kết nối vào mạng)
  void setEspAddress(String ipAddress) {
    _espBaseUrl = 'http://$ipAddress';
  }

  /// Lấy thông tin thiết bị ESP8266
  Future<EspDeviceInfo?> getDeviceInfo() async {
    try {
      final response = await http.get(
        Uri.parse('$_espBaseUrl/api/info'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return EspDeviceInfo.fromJson(json);
      }
      return null;
    } catch (e) {
      print('Error getting device info: $e');
      return null;
    }
  }

  /// Lấy danh sách WiFi networks
  Future<List<WifiNetwork>> scanWifiNetworks() async {
    try {
      final response = await http.get(
        Uri.parse('$_espBaseUrl/api/wifi/scan'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList.map((json) => WifiNetwork.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error scanning WiFi: $e');
      return [];
    }
  }

  /// Lấy cấu hình WiFi hiện tại
  Future<WifiConfig?> getCurrentConfig() async {
    try {
      final response = await http.get(
        Uri.parse('$_espBaseUrl/api/wifi/config'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return WifiConfig.fromJson(json);
      }
      return null;
    } catch (e) {
      print('Error getting config: $e');
      return null;
    }
  }

  /// Cập nhật cấu hình WiFi
  Future<bool> updateWifiConfig(WifiConfig config) async {
    try {
      final response = await http.post(
        Uri.parse('$_espBaseUrl/api/wifi/config'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(config.toJson()),
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      print('Error updating config: $e');
      return false;
    }
  }

  /// Cập nhật MQTT config
  Future<bool> updateMqttConfig({
    required String server,
    required int port,
    String? username,
    String? password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_espBaseUrl/api/mqtt/config'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'server': server,
          'port': port,
          'username': username,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      print('Error updating MQTT config: $e');
      return false;
    }
  }

  /// Restart ESP8266
  Future<bool> restartDevice() async {
    try {
      final response = await http.post(
        Uri.parse('$_espBaseUrl/api/restart'),
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      print('Error restarting device: $e');
      return false;
    }
  }

  /// Kiểm tra có firmware update không
  Future<OtaUpdateInfo?> checkForUpdate() async {
    try {
      final response = await http.get(
        Uri.parse('$_espBaseUrl/api/ota/check'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return OtaUpdateInfo.fromJson(json);
      }
      return null;
    } catch (e) {
      print('Error checking update: $e');
      return null;
    }
  }

  /// Bắt đầu OTA update
  Future<bool> startOtaUpdate(String firmwareUrl) async {
    try {
      final response = await http.post(
        Uri.parse('$_espBaseUrl/api/ota/update'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'url': firmwareUrl}),
      ).timeout(const Duration(seconds: 30));

      return response.statusCode == 200;
    } catch (e) {
      print('Error starting OTA: $e');
      return false;
    }
  }

  /// Lấy trạng thái OTA
  Future<OtaStatus?> getOtaStatus() async {
    try {
      final response = await http.get(
        Uri.parse('$_espBaseUrl/api/ota/status'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return OtaStatus.fromJson(json);
      }
      return null;
    } catch (e) {
      print('Error getting OTA status: $e');
      return null;
    }
  }

  /// Factory reset ESP8266
  Future<bool> factoryReset() async {
    try {
      final response = await http.post(
        Uri.parse('$_espBaseUrl/api/factory-reset'),
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      print('Error factory reset: $e');
      return false;
    }
  }
}

/// Model cho WiFi network khi scan
class WifiNetwork {
  final String ssid;
  final int rssi;
  final bool isSecured;
  final String encryptionType;

  WifiNetwork({
    required this.ssid,
    required this.rssi,
    required this.isSecured,
    required this.encryptionType,
  });

  factory WifiNetwork.fromJson(Map<String, dynamic> json) {
    return WifiNetwork(
      ssid: json['ssid'] ?? '',
      rssi: json['rssi'] ?? -100,
      isSecured: json['secured'] ?? false,
      encryptionType: json['encryption'] ?? 'OPEN',
    );
  }

  String get signalStrength {
    if (rssi >= -50) return 'Rất mạnh';
    if (rssi >= -60) return 'Mạnh';
    if (rssi >= -70) return 'Trung bình';
    return 'Yếu';
  }

  int get signalBars {
    if (rssi >= -50) return 4;
    if (rssi >= -60) return 3;
    if (rssi >= -70) return 2;
    if (rssi >= -80) return 1;
    return 0;
  }
}

/// Model cho OTA update info
class OtaUpdateInfo {
  final bool updateAvailable;
  final String currentVersion;
  final String latestVersion;
  final String? changeLog;
  final String? firmwareUrl;
  final int? firmwareSize;

  OtaUpdateInfo({
    required this.updateAvailable,
    required this.currentVersion,
    required this.latestVersion,
    this.changeLog,
    this.firmwareUrl,
    this.firmwareSize,
  });

  factory OtaUpdateInfo.fromJson(Map<String, dynamic> json) {
    return OtaUpdateInfo(
      updateAvailable: json['update_available'] ?? false,
      currentVersion: json['current_version'] ?? '0.0.0',
      latestVersion: json['latest_version'] ?? '0.0.0',
      changeLog: json['changelog'],
      firmwareUrl: json['firmware_url'],
      firmwareSize: json['firmware_size'],
    );
  }
}

/// Model cho OTA status
class OtaStatus {
  final String status; // idle, downloading, updating, success, failed
  final int progress; // 0-100
  final String? error;

  OtaStatus({
    required this.status,
    required this.progress,
    this.error,
  });

  factory OtaStatus.fromJson(Map<String, dynamic> json) {
    return OtaStatus(
      status: json['status'] ?? 'idle',
      progress: json['progress'] ?? 0,
      error: json['error'],
    );
  }

  bool get isInProgress =>
      status == 'downloading' || status == 'updating';
  
  bool get isSuccess => status == 'success';
  bool get isFailed => status == 'failed';
}
