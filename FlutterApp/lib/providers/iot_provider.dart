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

  IoTData get data => _data;
  bool get isConnected => _isConnected;
  bool get isLoading => _isLoading;

  // Kết nối MQTT
  Future<void> connectMQTT() async {
    try {
      final success = await _iotService.connectMQTT(_onMQTTMessage);
      if (success) {
        _isConnected = true;
        print('MQTT connected successfully');
      } else {
        _isConnected = false;
        print('MQTT connection failed');
      }
      notifyListeners();
    } catch (e) {
      print('Error connecting MQTT: $e');
      _isConnected = false;
      notifyListeners();
    }
  }

  // Xử lý MQTT message
  void _onMQTTMessage(String topic, String payload) {
    try {
      final jsonData = jsonDecode(payload);

      if (topic.startsWith('/iot/smarthome/sensors/')) {
        _updateDataFromMQTT(topic, jsonData);
      }
    } catch (e) {
      print('Error parsing MQTT message: $e');
    }
  }

  // Cập nhật dữ liệu từ MQTT
  void _updateDataFromMQTT(String topic, Map<String, dynamic> jsonData) {
    try {
      switch (topic.split('/').last) {
        case 'temperature':
          _data = _data.copyWith(
            temperature: (jsonData['temperature'] ?? 0).toDouble(),
            humidity: (jsonData['humidity'] ?? 0).toDouble(),
          );
          break;
        case 'motion':
          _data = _data.copyWith(
            pirActive: jsonData['motion'] ?? false,
          );
          break;
        case 'door':
          _data = _data.copyWith(
            doorOpen: jsonData['door'] ?? false,
            autoOpen: jsonData['autoOpen'] ?? false,
            rfidAccess: jsonData['rfid'] ?? false,
          );
          break;
        case 'distance':
          _data = _data.copyWith(
            distance: (jsonData['distance'] ?? 0).toDouble(),
          );
          break;
      }

      _data = _data.copyWith(
        timestamp: DateTime.now(),
        online: true,
      );

      notifyListeners();
    } catch (e) {
      print('Error updating data from MQTT: $e');
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
        doorOpen: jsonData['door'] ?? false,
        autoOpen: jsonData['autoOpen'] ?? false,
        rfidAccess: jsonData['rfid'] ?? false,
        distance: (jsonData['distance'] ?? 0).toDouble(),
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
    _iotService.disconnectMQTT();
    _isConnected = false;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
