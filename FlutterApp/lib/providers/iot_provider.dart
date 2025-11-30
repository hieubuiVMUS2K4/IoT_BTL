import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/iot_data_model.dart';
import '../services/iot_service.dart';

class IoTProvider with ChangeNotifier {
  final IoTService _iotService = IoTService();
  
  IoTData _data = IoTData.initial();
  bool _isConnected = false;
  bool _isLoading = false;
  StreamSubscription? _wsSubscription;

  IoTData get data => _data;
  bool get isConnected => _isConnected;
  bool get isLoading => _isLoading;

  // Kết nối WebSocket
  void connectWebSocket() {
    try {
      final channel = _iotService.connectWebSocket();
      
      _wsSubscription = channel.stream.listen(
        (message) {
          try {
            final jsonData = jsonDecode(message);
            if (jsonData['type'] == 'update' || jsonData['type'] == 'init') {
              _updateData(jsonData['data']);
            }
          } catch (e) {
            print('Error parsing WebSocket message: $e');
          }
        },
        onError: (error) {
          print('WebSocket error: $error');
          _isConnected = false;
          notifyListeners();
        },
        onDone: () {
          print('WebSocket disconnected');
          _isConnected = false;
          notifyListeners();
        },
      );

      _isConnected = true;
      notifyListeners();
    } catch (e) {
      print('Error connecting WebSocket: $e');
      _isConnected = false;
      notifyListeners();
    }
  }

  // Cập nhật dữ liệu
  void _updateData(Map<String, dynamic> jsonData) {
    try {
      _data = IoTData(
        temperature: (jsonData['temperature'] ?? 0).toDouble(),
        humidity: (jsonData['humidity'] ?? 0).toDouble(),
        pirActive: jsonData['pir'] ?? false,
        led1: jsonData['led1'] ?? false,
        led2: jsonData['led2'] ?? false,
        fan: jsonData['fan'] ?? false,
        fanAuto: jsonData['fanAuto'] ?? true,
        doorOpen: jsonData['door'] ?? false,
        autoOpen: jsonData['autoOpen'] ?? false,
        rfidAccess: jsonData['rfid'] ?? false,
        distance: (jsonData['distance'] ?? 0).toDouble(),
        securityMode: jsonData['securityMode'] ?? false,
        intruder: jsonData['intruder'] ?? false,
        timestamp: DateTime.now(),
        online: true,
      );
      notifyListeners();
    } catch (e) {
      print('Error updating data: $e');
    }
  }

  // Lấy dữ liệu hiện tại (fallback khi WebSocket lỗi)
  Future<void> fetchCurrentData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final newData = await _iotService.getCurrentData();
      if (newData != null) {
        _data = newData;
        _isConnected = true;
      }
    } catch (e) {
      print('Error fetching data: $e');
      _isConnected = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Điều khiển LED 2
  Future<bool> controlLed2(String action) async {
    try {
      return await _iotService.controlLed2(action);
    } catch (e) {
      print('Error controlling LED2: $e');
      return false;
    }
  }

  // Điều khiển cửa
  Future<bool> controlDoor(String action) async {
    try {
      return await _iotService.controlDoor(action);
    } catch (e) {
      print('Error controlling door: $e');
      return false;
    }
  }

  // Điều khiển quạt
  Future<bool> controlFan(String action) async {
    try {
      return await _iotService.controlFan(action);
    } catch (e) {
      print('Error controlling fan: $e');
      return false;
    }
  }

  // Điều khiển Security Mode
  Future<bool> toggleSecurityMode() async {
    try {
      final action = _data.securityMode ? 'off' : 'on';
      final success = await _iotService.controlDevice('security', action);
      if (success) {
        // Cập nhật local state ngay lập tức để UI responsive
        _data = _data.copyWith(
          securityMode: !_data.securityMode,
          intruder: false, // Reset intruder khi toggle
        );
        notifyListeners();
      }
      return success;
    } catch (e) {
      print('Error toggling security mode: $e');
      return false;
    }
  }

  // Kiểm tra kết nối
  Future<bool> checkConnection() async {
    try {
      final result = await _iotService.checkConnection();
      _isConnected = result;
      notifyListeners();
      return result;
    } catch (e) {
      _isConnected = false;
      notifyListeners();
      return false;
    }
  }

  // Ngắt kết nối
  void disconnect() {
    _wsSubscription?.cancel();
    _iotService.disconnectWebSocket();
    _isConnected = false;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
