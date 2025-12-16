import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/iot_data_model.dart';
import '../models/report_model.dart';
import '../services/iot_service.dart';
import '../services/report_service.dart';

class IoTProvider with ChangeNotifier {
  final IoTService _iotService = IoTService();
  final ReportService _reportService = ReportService();
  
  IoTData _data = IoTData.initial();
  IoTData? _previousData; // Để so sánh và phát hiện sự kiện
  bool _isConnected = false;
  bool _isLoading = false;
  StreamSubscription? _wsSubscription;
  Timer? _recordTimer; // Timer để lưu sensor data định kỳ

  // Real-time event counters (reset mỗi ngày)
  int _todayMotionCount = 0;
  int _todayDoorOpenCount = 0;
  int _todayIntruderCount = 0;
  DateTime _lastCountResetDate = DateTime.now();

  IoTData get data => _data;
  bool get isConnected => _isConnected;
  bool get isLoading => _isLoading;
  ReportService get reportService => _reportService;
  
  // Getters for real-time counters
  int get todayMotionCount => _todayMotionCount;
  int get todayDoorOpenCount => _todayDoorOpenCount;
  int get todayIntruderCount => _todayIntruderCount;

  // Reset counters nếu sang ngày mới
  void _checkAndResetDailyCounters() {
    final today = DateTime.now();
    if (today.day != _lastCountResetDate.day || 
        today.month != _lastCountResetDate.month ||
        today.year != _lastCountResetDate.year) {
      _todayMotionCount = 0;
      _todayDoorOpenCount = 0;
      _todayIntruderCount = 0;
      _lastCountResetDate = today;
    }
  }

  // Initialize counters từ server data
  Future<void> initializeCountersFromServer() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      
      // Reset counters trước khi đếm lại
      int motionCount = 0;
      int doorOpenCount = 0;
      int intruderCount = 0;
      
      // Đếm từ sensor_data cho motion và intruder
      final records = await _reportService.getServerRecordsByDateRange(startOfDay, endOfDay);
      
      if (records.isNotEmpty) {
        // Sắp xếp theo thời gian
        records.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        
        bool lastPir = false;
        bool lastIntruder = false;
        
        for (final record in records) {
          if (record.pirActive && !lastPir) motionCount++;
          if (record.intruder && !lastIntruder) intruderCount++;
          
          lastPir = record.pirActive;
          lastIntruder = record.intruder;
        }
      }
      
      // Đếm door events từ event_logs (vì sensor_data không lưu doorOpen)
      try {
        final events = await _reportService.getServerEvents(limit: 500);
        for (final event in events) {
          // Chỉ đếm events hôm nay
          if (event.timestamp.isAfter(startOfDay) && event.timestamp.isBefore(endOfDay)) {
            if (event.type == EventType.doorOpened) {
              doorOpenCount++;
            }
          }
        }
      } catch (e) {
        print('⚠️  Could not count door events: $e');
      }
      
      // Gán giá trị đã tính
      _todayMotionCount = motionCount;
      _todayDoorOpenCount = doorOpenCount;
      _todayIntruderCount = intruderCount;
      _lastCountResetDate = today;
      
      print('✅ Initialized counters from server: motion=$_todayMotionCount, door=$_todayDoorOpenCount, intruder=$_todayIntruderCount');
    } catch (e) {
      print('⚠️  Could not initialize counters from server: $e');
    }
    notifyListeners();
  }

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
          _stopRecordTimer();
          notifyListeners();
        },
        onDone: () {
          print('WebSocket disconnected');
          _isConnected = false;
          _stopRecordTimer();
          notifyListeners();
        },
      );

      _isConnected = true;
      _startRecordTimer(); // Bắt đầu lưu sensor data định kỳ
      notifyListeners();
    } catch (e) {
      print('Error connecting WebSocket: $e');
      _isConnected = false;
      notifyListeners();
    }
  }

  // Bắt đầu timer lưu sensor data (mỗi 5 phút)
  void _startRecordTimer() {
    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _saveSensorRecord();
    });
    // Lưu ngay lần đầu khi kết nối
    _saveSensorRecord();
  }

  // Dừng timer
  void _stopRecordTimer() {
    _recordTimer?.cancel();
    _recordTimer = null;
  }

  // Lưu sensor record
  Future<void> _saveSensorRecord() async {
    if (!_isConnected || !_data.online) return;
    
    // ReportService sẽ tự convert IoTData thành SensorRecord
    await _reportService.saveSensorRecord(_data);
  }

  // Phát hiện và lưu sự kiện
  Future<void> _detectAndSaveEvents(IoTData newData) async {
    // Check và reset counters nếu sang ngày mới
    _checkAndResetDailyCounters();
    
    if (_previousData == null) {
      _previousData = newData;
      return;
    }

    final prev = _previousData!;
    final now = DateTime.now();
    final eventId = () => now.millisecondsSinceEpoch.toString();

    // PIR motion detected
    if (!prev.pirActive && newData.pirActive) {
      _todayMotionCount++; // Tăng counter real-time
      await _reportService.saveSystemEvent(SystemEvent(
        id: eventId(),
        timestamp: now,
        type: EventType.motionDetected,
        description: 'Phát hiện chuyển động từ cảm biến PIR',
        metadata: {'distance': newData.distance},
      ));
    }

    // Door opened/closed
    if (!prev.doorOpen && newData.doorOpen) {
      _todayDoorOpenCount++; // Tăng counter real-time
      await _reportService.saveSystemEvent(SystemEvent(
        id: eventId(),
        timestamp: now,
        type: EventType.doorOpened,
        description: 'Cửa đã được mở',
      ));
    } else if (prev.doorOpen && !newData.doorOpen) {
      await _reportService.saveSystemEvent(SystemEvent(
        id: eventId(),
        timestamp: now,
        type: EventType.doorClosed,
        description: 'Cửa đã đóng',
      ));
    }

    // Intruder alert
    if (!prev.intruder && newData.intruder) {
      _todayIntruderCount++; // Tăng counter real-time
      await _reportService.saveSystemEvent(SystemEvent(
        id: eventId(),
        timestamp: now,
        type: EventType.intruderAlert,
        description: 'CẢNH BÁO: Phát hiện xâm nhập!',
        metadata: {'securityMode': newData.securityMode},
      ));
    }

    // Security mode changed
    if (prev.securityMode != newData.securityMode) {
      await _reportService.saveSystemEvent(SystemEvent(
        id: eventId(),
        timestamp: now,
        type: newData.securityMode 
            ? EventType.securityModeOn 
            : EventType.securityModeOff,
        description: newData.securityMode 
            ? 'Chế độ bảo mật đã được BẬT'
            : 'Chế độ bảo mật đã được TẮT',
      ));
    }

    // RFID access
    if (!prev.rfidAccess && newData.rfidAccess) {
      await _reportService.saveSystemEvent(SystemEvent(
        id: eventId(),
        timestamp: now,
        type: EventType.rfidAccess,
        description: 'Truy cập bằng thẻ RFID',
      ));
    }

    _previousData = newData;
  }

  // Cập nhật dữ liệu
  void _updateData(Map<String, dynamic> jsonData) {
    try {
      final newData = IoTData(
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
      
      // Phát hiện và lưu sự kiện trước khi cập nhật data
      _detectAndSaveEvents(newData);
      
      _data = newData;
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
    _stopRecordTimer();
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
