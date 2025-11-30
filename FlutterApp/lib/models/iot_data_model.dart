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
    // Convert any numeric values to strings to avoid type errors
    final cleanedJson = Map<String, dynamic>.from(json);
    
    // Ensure distance and temperature are strings
    if (cleanedJson['distance'] != null && cleanedJson['distance'] is! String) {
      cleanedJson['distance'] = cleanedJson['distance'].toString();
    }
    if (cleanedJson['temperature'] != null && cleanedJson['temperature'] is! String) {
      cleanedJson['temperature'] = cleanedJson['temperature'].toString();
    }
    if (cleanedJson['humidity'] != null && cleanedJson['humidity'] is! String) {
      cleanedJson['humidity'] = cleanedJson['humidity'].toString();
    }
    
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
