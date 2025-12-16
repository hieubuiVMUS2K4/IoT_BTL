import 'package:json_annotation/json_annotation.dart';

part 'report_model.g.dart';

/// Model cho một bản ghi dữ liệu sensor (lưu lịch sử)
@JsonSerializable()
class SensorRecord {
  final String id;
  final double temperature;
  final double humidity;
  final bool pirActive;
  final bool led1;
  final bool led2;
  final bool fan;
  final bool doorOpen;
  final double distance;
  final bool securityMode;
  final bool intruder;
  final DateTime timestamp;

  SensorRecord({
    required this.id,
    required this.temperature,
    required this.humidity,
    required this.pirActive,
    required this.led1,
    required this.led2,
    required this.fan,
    required this.doorOpen,
    required this.distance,
    required this.securityMode,
    required this.intruder,
    required this.timestamp,
  });

  // Helper function to convert String to num
  static num _parseNum(dynamic value, [num defaultValue = 0]) {
    if (value == null) return defaultValue;
    if (value is num) return value;
    if (value is String) return num.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  factory SensorRecord.fromJson(Map<String, dynamic> json) {
    // Clean numeric fields that might come as strings from PostgreSQL
    final cleanedJson = Map<String, dynamic>.from(json);
    cleanedJson['temperature'] = _parseNum(json['temperature']);
    cleanedJson['humidity'] = _parseNum(json['humidity']);
    cleanedJson['distance'] = _parseNum(json['distance']);
    return _$SensorRecordFromJson(cleanedJson);
  }
  Map<String, dynamic> toJson() => _$SensorRecordToJson(this);
}

/// Model cho thống kê theo ngày/tuần/tháng
@JsonSerializable()
class DailyStatistics {
  final DateTime date;
  final double avgTemperature;
  final double maxTemperature;
  final double minTemperature;
  final double avgHumidity;
  final double maxHumidity;
  final double minHumidity;
  final int motionDetectionCount;
  final int doorOpenCount;
  final int intruderAlertCount;
  final Duration totalFanOnTime;
  final Duration totalLed1OnTime;
  final Duration totalLed2OnTime;

  DailyStatistics({
    required this.date,
    required this.avgTemperature,
    required this.maxTemperature,
    required this.minTemperature,
    required this.avgHumidity,
    required this.maxHumidity,
    required this.minHumidity,
    required this.motionDetectionCount,
    required this.doorOpenCount,
    required this.intruderAlertCount,
    required this.totalFanOnTime,
    required this.totalLed1OnTime,
    required this.totalLed2OnTime,
  });

  // Helper function to convert String to num
  static num _parseNum(dynamic value, [num defaultValue = 0]) {
    if (value == null) return defaultValue;
    if (value is num) return value;
    if (value is String) return num.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  factory DailyStatistics.fromJson(Map<String, dynamic> json) {
    // Clean numeric fields that might come as strings from PostgreSQL
    final cleanedJson = Map<String, dynamic>.from(json);
    cleanedJson['avgTemperature'] = _parseNum(json['avgTemperature']);
    cleanedJson['maxTemperature'] = _parseNum(json['maxTemperature']);
    cleanedJson['minTemperature'] = _parseNum(json['minTemperature']);
    cleanedJson['avgHumidity'] = _parseNum(json['avgHumidity']);
    cleanedJson['maxHumidity'] = _parseNum(json['maxHumidity']);
    cleanedJson['minHumidity'] = _parseNum(json['minHumidity']);
    cleanedJson['motionDetectionCount'] = _parseNum(json['motionDetectionCount']);
    cleanedJson['doorOpenCount'] = _parseNum(json['doorOpenCount']);
    cleanedJson['intruderAlertCount'] = _parseNum(json['intruderAlertCount']);
    cleanedJson['totalFanOnTime'] = _parseNum(json['totalFanOnTime']);
    cleanedJson['totalLed1OnTime'] = _parseNum(json['totalLed1OnTime']);
    cleanedJson['totalLed2OnTime'] = _parseNum(json['totalLed2OnTime']);
    return _$DailyStatisticsFromJson(cleanedJson);
  }
  Map<String, dynamic> toJson() => _$DailyStatisticsToJson(this);

  factory DailyStatistics.empty(DateTime date) {
    return DailyStatistics(
      date: date,
      avgTemperature: 0,
      maxTemperature: 0,
      minTemperature: 0,
      avgHumidity: 0,
      maxHumidity: 0,
      minHumidity: 0,
      motionDetectionCount: 0,
      doorOpenCount: 0,
      intruderAlertCount: 0,
      totalFanOnTime: Duration.zero,
      totalLed1OnTime: Duration.zero,
      totalLed2OnTime: Duration.zero,
    );
  }
}

/// Enum cho loại báo cáo
enum ReportType {
  daily,
  weekly,
  monthly,
  custom,
}

/// Enum cho loại sự kiện
enum EventType {
  motionDetected,
  doorOpened,
  doorClosed,
  intruderAlert,
  securityModeOn,
  securityModeOff,
  led2On,
  led2Off,
  fanOn,
  fanOff,
  rfidAccess,
  temperatureHigh,
  humidityHigh,
}

/// Model cho sự kiện hệ thống (activity log)
@JsonSerializable()
class SystemEvent {
  final String id;
  final EventType type;
  final String description;
  final DateTime timestamp;
  final String? userId; // Null nếu là sự kiện tự động
  final Map<String, dynamic>? metadata;

  SystemEvent({
    required this.id,
    required this.type,
    required this.description,
    required this.timestamp,
    this.userId,
    this.metadata,
  });

  factory SystemEvent.fromJson(Map<String, dynamic> json) =>
      _$SystemEventFromJson(json);
  Map<String, dynamic> toJson() => _$SystemEventToJson(this);

  String get typeDisplayName {
    switch (type) {
      case EventType.motionDetected:
        return 'Phát hiện chuyển động';
      case EventType.doorOpened:
        return 'Cửa mở';
      case EventType.doorClosed:
        return 'Cửa đóng';
      case EventType.intruderAlert:
        return '⚠️ Cảnh báo xâm nhập';
      case EventType.securityModeOn:
        return 'Bật chế độ an ninh';
      case EventType.securityModeOff:
        return 'Tắt chế độ an ninh';
      case EventType.led2On:
        return 'Bật LED 2';
      case EventType.led2Off:
        return 'Tắt LED 2';
      case EventType.fanOn:
        return 'Bật quạt';
      case EventType.fanOff:
        return 'Tắt quạt';
      case EventType.rfidAccess:
        return 'Quẹt thẻ RFID';
      case EventType.temperatureHigh:
        return '⚠️ Nhiệt độ cao';
      case EventType.humidityHigh:
        return '⚠️ Độ ẩm cao';
    }
  }
}

/// Model cho cấu hình WiFi ESP8266
@JsonSerializable()
class WifiConfig {
  final String ssid;
  final String password;
  final String? staticIp;
  final String? gateway;
  final String? subnet;
  final String? mqttServer;
  final int? mqttPort;
  final String? mqttUsername;
  final String? mqttPassword;

  WifiConfig({
    required this.ssid,
    required this.password,
    this.staticIp,
    this.gateway,
    this.subnet,
    this.mqttServer,
    this.mqttPort,
    this.mqttUsername,
    this.mqttPassword,
  });

  factory WifiConfig.fromJson(Map<String, dynamic> json) =>
      _$WifiConfigFromJson(json);
  Map<String, dynamic> toJson() => _$WifiConfigToJson(this);
}

/// Model cho thông tin ESP8266
@JsonSerializable()
class EspDeviceInfo {
  final String deviceId;
  final String firmwareVersion;
  final String ipAddress;
  final String macAddress;
  final int freeHeap;
  final int uptime;
  final String wifiSsid;
  final int wifiRssi;
  final bool mqttConnected;
  final DateTime lastSeen;

  EspDeviceInfo({
    required this.deviceId,
    required this.firmwareVersion,
    required this.ipAddress,
    required this.macAddress,
    required this.freeHeap,
    required this.uptime,
    required this.wifiSsid,
    required this.wifiRssi,
    required this.mqttConnected,
    required this.lastSeen,
  });

  factory EspDeviceInfo.fromJson(Map<String, dynamic> json) =>
      _$EspDeviceInfoFromJson(json);
  Map<String, dynamic> toJson() => _$EspDeviceInfoToJson(this);

  String get uptimeFormatted {
    final hours = uptime ~/ 3600;
    final minutes = (uptime % 3600) ~/ 60;
    final seconds = uptime % 60;
    return '${hours}h ${minutes}m ${seconds}s';
  }

  String get signalStrength {
    if (wifiRssi >= -50) return 'Rất mạnh';
    if (wifiRssi >= -60) return 'Mạnh';
    if (wifiRssi >= -70) return 'Trung bình';
    return 'Yếu';
  }
}
