import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../models/report_model.dart';
import '../models/iot_data_model.dart';
import 'iot_service.dart';

class ReportService {
  static const String _recordsFile = 'sensor_records.json';
  static const String _eventsFile = 'system_events.json';
  static const int _maxRecords = 10000; // Giới hạn số bản ghi lưu trữ
  
  final IoTService _iotService = IoTService();

  // ===== PATH HELPERS =====
  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _recordsDbFile async {
    final path = await _localPath;
    return File('$path/$_recordsFile');
  }

  Future<File> get _eventsDbFile async {
    final path = await _localPath;
    return File('$path/$_eventsFile');
  }

  // ===== LƯU DỮ LIỆU SENSOR =====
  
  /// Lưu một bản ghi sensor data (gọi mỗi khi nhận data từ WebSocket)
  Future<void> saveSensorRecord(IoTData data) async {
    try {
      final record = SensorRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        temperature: data.temperature,
        humidity: data.humidity,
        pirActive: data.pirActive,
        led1: data.led1,
        led2: data.led2,
        fan: data.fan,
        doorOpen: data.doorOpen,
        distance: data.distance,
        securityMode: data.securityMode,
        intruder: data.intruder,
        timestamp: data.timestamp,
      );

      final records = await getSensorRecords();
      records.add(record);

      // Giới hạn số lượng records
      if (records.length > _maxRecords) {
        records.removeRange(0, records.length - _maxRecords);
      }

      final file = await _recordsDbFile;
      await file.writeAsString(
        jsonEncode(records.map((r) => r.toJson()).toList()),
      );
    } catch (e) {
      print('Error saving sensor record: $e');
    }
  }

  /// Lấy tất cả sensor records
  Future<List<SensorRecord>> getSensorRecords() async {
    try {
      final file = await _recordsDbFile;
      if (!await file.exists()) return [];

      final contents = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(contents);
      return jsonList.map((json) => SensorRecord.fromJson(json)).toList();
    } catch (e) {
      print('Error getting sensor records: $e');
      return [];
    }
  }

  /// Lấy records trong khoảng thời gian
  Future<List<SensorRecord>> getRecordsByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final records = await getSensorRecords();
    return records
        .where((r) => r.timestamp.isAfter(start) && r.timestamp.isBefore(end))
        .toList();
  }

  /// Lấy records của ngày hôm nay
  Future<List<SensorRecord>> getTodayRecords() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return getRecordsByDateRange(startOfDay, endOfDay);
  }

  // ===== LƯU SỰ KIỆN HỆ THỐNG =====

  /// Lưu một sự kiện hệ thống
  Future<void> saveSystemEvent(SystemEvent event) async {
    try {
      final events = await getSystemEvents();
      events.add(event);

      // Giới hạn số lượng events
      if (events.length > _maxRecords) {
        events.removeRange(0, events.length - _maxRecords);
      }

      final file = await _eventsDbFile;
      await file.writeAsString(
        jsonEncode(events.map((e) => e.toJson()).toList()),
      );
    } catch (e) {
      print('Error saving system event: $e');
    }
  }

  /// Tạo và lưu sự kiện nhanh
  Future<void> logEvent(
    EventType type,
    String description, {
    String? userId,
    Map<String, dynamic>? metadata,
  }) async {
    final event = SystemEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      description: description,
      timestamp: DateTime.now(),
      userId: userId,
      metadata: metadata,
    );
    await saveSystemEvent(event);
  }

  /// Lấy tất cả system events
  Future<List<SystemEvent>> getSystemEvents() async {
    try {
      final file = await _eventsDbFile;
      if (!await file.exists()) return [];

      final contents = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(contents);
      return jsonList.map((json) => SystemEvent.fromJson(json)).toList();
    } catch (e) {
      print('Error getting system events: $e');
      return [];
    }
  }

  /// Lấy events theo loại
  Future<List<SystemEvent>> getEventsByType(EventType type) async {
    final events = await getSystemEvents();
    return events.where((e) => e.type == type).toList();
  }

  /// Lấy events trong khoảng thời gian
  Future<List<SystemEvent>> getEventsByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final events = await getSystemEvents();
    return events
        .where((e) => e.timestamp.isAfter(start) && e.timestamp.isBefore(end))
        .toList();
  }

  // ===== THỐNG KÊ =====

  /// Tính thống kê cho một ngày
  Future<DailyStatistics> calculateDailyStatistics(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final records = await getRecordsByDateRange(startOfDay, endOfDay);

    if (records.isEmpty) {
      return DailyStatistics.empty(date);
    }

    // Tính toán temperature
    final temps = records.map((r) => r.temperature).toList();
    final avgTemp = temps.reduce((a, b) => a + b) / temps.length;
    final maxTemp = temps.reduce((a, b) => a > b ? a : b);
    final minTemp = temps.reduce((a, b) => a < b ? a : b);

    // Tính toán humidity
    final hums = records.map((r) => r.humidity).toList();
    final avgHum = hums.reduce((a, b) => a + b) / hums.length;
    final maxHum = hums.reduce((a, b) => a > b ? a : b);
    final minHum = hums.reduce((a, b) => a < b ? a : b);

    // Đếm sự kiện
    int motionCount = 0;
    int doorCount = 0;
    int intruderCount = 0;
    
    bool lastPir = false;
    bool lastDoor = false;
    bool lastIntruder = false;

    for (final record in records) {
      if (record.pirActive && !lastPir) motionCount++;
      if (record.doorOpen && !lastDoor) doorCount++;
      if (record.intruder && !lastIntruder) intruderCount++;
      
      lastPir = record.pirActive;
      lastDoor = record.doorOpen;
      lastIntruder = record.intruder;
    }

    // Tính thời gian bật (giả sử mỗi record cách nhau 2 giây)
    const recordInterval = Duration(seconds: 2);
    int fanOnCount = records.where((r) => r.fan).length;
    int led1OnCount = records.where((r) => r.led1).length;
    int led2OnCount = records.where((r) => r.led2).length;

    return DailyStatistics(
      date: date,
      avgTemperature: avgTemp,
      maxTemperature: maxTemp,
      minTemperature: minTemp,
      avgHumidity: avgHum,
      maxHumidity: maxHum,
      minHumidity: minHum,
      motionDetectionCount: motionCount,
      doorOpenCount: doorCount,
      intruderAlertCount: intruderCount,
      totalFanOnTime: recordInterval * fanOnCount,
      totalLed1OnTime: recordInterval * led1OnCount,
      totalLed2OnTime: recordInterval * led2OnCount,
    );
  }

  /// Lấy thống kê 7 ngày gần nhất
  Future<List<DailyStatistics>> getWeeklyStatistics() async {
    final stats = <DailyStatistics>[];
    final today = DateTime.now();

    for (int i = 6; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      final dailyStat = await calculateDailyStatistics(date);
      stats.add(dailyStat);
    }

    return stats;
  }

  // ===== EXPORT =====

  /// Xuất báo cáo dạng CSV
  Future<String> exportToCsv(DateTime start, DateTime end) async {
    final records = await getRecordsByDateRange(start, end);
    
    final buffer = StringBuffer();
    buffer.writeln(
      'Timestamp,Temperature,Humidity,PIR,LED1,LED2,Fan,Door,Distance,Security,Intruder',
    );

    for (final record in records) {
      buffer.writeln(
        '${record.timestamp.toIso8601String()},'
        '${record.temperature},'
        '${record.humidity},'
        '${record.pirActive},'
        '${record.led1},'
        '${record.led2},'
        '${record.fan},'
        '${record.doorOpen},'
        '${record.distance},'
        '${record.securityMode},'
        '${record.intruder}',
      );
    }

    return buffer.toString();
  }

  /// Xuất sự kiện dạng CSV
  Future<String> exportEventsToCsv(DateTime start, DateTime end) async {
    final events = await getEventsByDateRange(start, end);
    
    final buffer = StringBuffer();
    buffer.writeln('Timestamp,Type,Description,UserId');

    for (final event in events) {
      buffer.writeln(
        '${event.timestamp.toIso8601String()},'
        '${event.type.name},'
        '"${event.description}",'
        '${event.userId ?? ""}',
      );
    }

    return buffer.toString();
  }

  /// Lưu CSV vào file
  Future<File> saveCsvToFile(String csvContent, String fileName) async {
    final path = await _localPath;
    final file = File('$path/$fileName');
    return file.writeAsString(csvContent);
  }

  // ===== CLEANUP =====

  /// Xóa records cũ hơn số ngày chỉ định
  Future<void> cleanupOldRecords(int daysToKeep) async {
    final cutoff = DateTime.now().subtract(Duration(days: daysToKeep));
    
    // Cleanup sensor records
    final records = await getSensorRecords();
    final filteredRecords = records.where((r) => r.timestamp.isAfter(cutoff)).toList();
    final recordsFile = await _recordsDbFile;
    await recordsFile.writeAsString(
      jsonEncode(filteredRecords.map((r) => r.toJson()).toList()),
    );

    // Cleanup events
    final events = await getSystemEvents();
    final filteredEvents = events.where((e) => e.timestamp.isAfter(cutoff)).toList();
    final eventsFile = await _eventsDbFile;
    await eventsFile.writeAsString(
      jsonEncode(filteredEvents.map((e) => e.toJson()).toList()),
    );
  }
  
  // ===== NEW POSTGRESQL METHODS =====
  
  /// Lấy thống kê từ PostgreSQL server
  Future<Map<String, dynamic>?> getServerStatistics({int hours = 24}) async {
    return await _iotService.getStatistics(hours: hours);
  }
  
  /// Lấy sensor records từ PostgreSQL server
  Future<List<SensorRecord>> getServerSensorRecords({int limit = 100}) async {
    final data = await _iotService.getSensorHistory(limit: limit);
    return data.map((json) => _sensorRecordFromServerJson(json)).toList();
  }
  
  /// Lấy sensor records theo range từ server
  Future<List<SensorRecord>> getServerRecordsByDateRange(DateTime start, DateTime end) async {
    final data = await _iotService.getSensorDataByRange(start, end);
    return data.map((json) => _sensorRecordFromServerJson(json)).toList();
  }
  
  /// Lấy events từ PostgreSQL server
  Future<List<SystemEvent>> getServerEvents({int limit = 50, String? type, String? severity}) async {
    final data = await _iotService.getEvents(limit: limit, type: type, severity: severity);
    return data.map((json) => _systemEventFromServerJson(json)).toList();
  }
  
  /// Tính thống kê hàng ngày từ server data
  Future<DailyStatistics> calculateDailyStatisticsFromServer(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final records = await getServerRecordsByDateRange(startOfDay, endOfDay);

    if (records.isEmpty) {
      return DailyStatistics.empty(date);
    }

    // Tính toán giống local
    final temps = records.map((r) => r.temperature).toList();
    final avgTemp = temps.reduce((a, b) => a + b) / temps.length;
    final maxTemp = temps.reduce((a, b) => a > b ? a : b);
    final minTemp = temps.reduce((a, b) => a < b ? a : b);

    final hums = records.map((r) => r.humidity).toList();
    final avgHum = hums.reduce((a, b) => a + b) / hums.length;
    final maxHum = hums.reduce((a, b) => a > b ? a : b);
    final minHum = hums.reduce((a, b) => a < b ? a : b);

    int motionCount = 0;
    int doorCount = 0;
    int intruderCount = 0;
    
    bool lastPir = false;
    bool lastDoor = false;
    bool lastIntruder = false;

    for (final record in records) {
      if (record.pirActive && !lastPir) motionCount++;
      if (record.doorOpen && !lastDoor) doorCount++;
      if (record.intruder && !lastIntruder) intruderCount++;
      
      lastPir = record.pirActive;
      lastDoor = record.doorOpen;
      lastIntruder = record.intruder;
    }

    const recordInterval = Duration(seconds: 2);
    int fanOnCount = records.where((r) => r.fan).length;
    int led1OnCount = records.where((r) => r.led1).length;
    int led2OnCount = records.where((r) => r.led2).length;

    return DailyStatistics(
      date: date,
      avgTemperature: avgTemp,
      maxTemperature: maxTemp,
      minTemperature: minTemp,
      avgHumidity: avgHum,
      maxHumidity: maxHum,
      minHumidity: minHum,
      motionDetectionCount: motionCount,
      doorOpenCount: doorCount,
      intruderAlertCount: intruderCount,
      totalFanOnTime: recordInterval * fanOnCount,
      totalLed1OnTime: recordInterval * led1OnCount,
      totalLed2OnTime: recordInterval * led2OnCount,
    );
  }
  
  /// Lấy thống kê tuần từ server (ưu tiên dùng thay vì local)
  Future<List<DailyStatistics>> getWeeklyStatisticsFromServer() async {
    final stats = <DailyStatistics>[];
    final today = DateTime.now();

    for (int i = 6; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      final dailyStat = await calculateDailyStatisticsFromServer(date);
      stats.add(dailyStat);
    }

    return stats;
  }
  
  // Helper methods để convert server JSON sang models
  SensorRecord _sensorRecordFromServerJson(Map<String, dynamic> json) {
    return SensorRecord(
      id: json['id'].toString(),
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.0,
      humidity: (json['humidity'] as num?)?.toDouble() ?? 0.0,
      pirActive: json['pir'] ?? false,
      led1: false, // Server không lưu LED status trong sensor_data
      led2: false,
      fan: false,
      doorOpen: false,
      distance: json['distance'] ?? 0,
      securityMode: false,
      intruder: json['intruder'] ?? false,
      timestamp: DateTime.parse(json['created_at']),
    );
  }
  
  SystemEvent _systemEventFromServerJson(Map<String, dynamic> json) {
    EventType type;
    switch (json['event_type']) {
      case 'INTRUSION':
        type = EventType.security;
        break;
      case 'MOTION':
        type = EventType.motion;
        break;
      case 'CONTROL':
        type = EventType.deviceControl;
        break;
      default:
        type = EventType.system;
    }
    
    return SystemEvent(
      id: json['id'].toString(),
      type: type,
      description: json['description'] ?? '',
      timestamp: DateTime.parse(json['created_at']),
      userId: null,
      metadata: {'severity': json['severity']},
    );
  }
}
