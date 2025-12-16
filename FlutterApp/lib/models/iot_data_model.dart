import 'package:json_annotation/json_annotation.dart';

part 'iot_data_model.g.dart';

@JsonSerializable()
class IoTData {
  final double temperature;
  final double humidity;
  final bool pirActive;
  final bool led1;
  final bool led2;
  final bool fan;
  final bool fanAuto;
  final bool doorOpen;
  final bool autoOpen;
  final bool rfidAccess;
  final double distance;
  final bool securityMode;
  final bool intruder;
  final DateTime timestamp;
  final bool online;

  IoTData({
    required this.temperature,
    required this.humidity,
    required this.pirActive,
    required this.led1,
    required this.led2,
    required this.fan,
    required this.fanAuto,
    required this.doorOpen,
    required this.autoOpen,
    required this.rfidAccess,
    required this.distance,
    this.securityMode = false,
    this.intruder = false,
    required this.timestamp,
    this.online = true,
  });

  factory IoTData.fromJson(Map<String, dynamic> json) {
    // Helper function to convert String to num
    num parseNum(dynamic value, [num defaultValue = 0]) {
      if (value == null) return defaultValue;
      if (value is num) return value;
      if (value is String) return num.tryParse(value) ?? defaultValue;
      return defaultValue;
    }
    
    // Helper function to parse bool safely
    bool parseBool(dynamic value, [bool defaultValue = false]) {
      if (value == null) return defaultValue;
      if (value is bool) return value;
      if (value is String) return value.toLowerCase() == 'true';
      if (value is num) return value != 0;
      return defaultValue;
    }
    
    // Helper function to parse timestamp
    String parseTimestamp(dynamic value) {
      if (value == null) return DateTime.now().toIso8601String();
      if (value is String) return value;
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value).toIso8601String();
      if (value is DateTime) return value.toIso8601String();
      return DateTime.now().toIso8601String();
    }
    
    // Convert values and map server field names to Flutter field names
    final cleanedJson = Map<String, dynamic>.from(json);
    
    // Numeric fields
    cleanedJson['temperature'] = parseNum(json['temperature']);
    cleanedJson['humidity'] = parseNum(json['humidity']);
    cleanedJson['distance'] = parseNum(json['distance']);
    
    // Boolean fields with null safety (server uses 'door', Flutter expects 'doorOpen')
    cleanedJson['pirActive'] = parseBool(json['pirActive'] ?? json['pir']);
    cleanedJson['led1'] = parseBool(json['led1']);
    cleanedJson['led2'] = parseBool(json['led2']);
    cleanedJson['fan'] = parseBool(json['fan']);
    cleanedJson['fanAuto'] = parseBool(json['fanAuto'], true);
    cleanedJson['doorOpen'] = parseBool(json['doorOpen'] ?? json['door']);
    cleanedJson['autoOpen'] = parseBool(json['autoOpen']);
    cleanedJson['rfidAccess'] = parseBool(json['rfidAccess'] ?? json['rfid']);
    cleanedJson['securityMode'] = parseBool(json['securityMode']);
    cleanedJson['intruder'] = parseBool(json['intruder']);
    cleanedJson['online'] = parseBool(json['online'], true);
    
    // Timestamp - handle both string and int/milliseconds
    cleanedJson['timestamp'] = parseTimestamp(json['timestamp'] ?? json['lastUpdate']);
    
    return _$IoTDataFromJson(cleanedJson);
  }
  Map<String, dynamic> toJson() => _$IoTDataToJson(this);

  factory IoTData.initial() {
    return IoTData(
      temperature: 0.0,
      humidity: 0.0,
      pirActive: false,
      led1: false,
      led2: false,
      fan: false,
      fanAuto: true,
      doorOpen: false,
      autoOpen: false,
      rfidAccess: false,
      distance: 0.0,
      securityMode: false,
      intruder: false,
      timestamp: DateTime.now(),
      online: false,
    );
  }

  IoTData copyWith({
    double? temperature,
    double? humidity,
    bool? pirActive,
    bool? led1,
    bool? led2,
    bool? fan,
    bool? fanAuto,
    bool? doorOpen,
    bool? autoOpen,
    bool? rfidAccess,
    double? distance,
    bool? securityMode,
    bool? intruder,
    DateTime? timestamp,
    bool? online,
  }) {
    return IoTData(
      temperature: temperature ?? this.temperature,
      humidity: humidity ?? this.humidity,
      pirActive: pirActive ?? this.pirActive,
      led1: led1 ?? this.led1,
      led2: led2 ?? this.led2,
      fan: fan ?? this.fan,
      fanAuto: fanAuto ?? this.fanAuto,
      doorOpen: doorOpen ?? this.doorOpen,
      autoOpen: autoOpen ?? this.autoOpen,
      rfidAccess: rfidAccess ?? this.rfidAccess,
      distance: distance ?? this.distance,
      securityMode: securityMode ?? this.securityMode,
      intruder: intruder ?? this.intruder,
      timestamp: timestamp ?? this.timestamp,
      online: online ?? this.online,
    );
  }
}
