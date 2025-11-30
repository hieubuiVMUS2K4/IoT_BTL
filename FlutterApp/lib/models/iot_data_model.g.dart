// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'iot_data_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

IoTData _$IoTDataFromJson(Map<String, dynamic> json) => IoTData(
      temperature: (json['temperature'] as num).toDouble(),
      humidity: (json['humidity'] as num).toDouble(),
      pirActive: json['pirActive'] as bool,
      led1: json['led1'] as bool,
      led2: json['led2'] as bool,
      fan: json['fan'] as bool,
      fanAuto: json['fanAuto'] as bool,
      doorOpen: json['doorOpen'] as bool,
      autoOpen: json['autoOpen'] as bool,
      rfidAccess: json['rfidAccess'] as bool,
      distance: (json['distance'] as num).toDouble(),
      securityMode: json['securityMode'] as bool? ?? false,
      intruder: json['intruder'] as bool? ?? false,
      timestamp: DateTime.parse(json['timestamp'] as String),
      online: json['online'] as bool? ?? true,
    );

Map<String, dynamic> _$IoTDataToJson(IoTData instance) => <String, dynamic>{
      'temperature': instance.temperature,
      'humidity': instance.humidity,
      'pirActive': instance.pirActive,
      'led1': instance.led1,
      'led2': instance.led2,
      'fan': instance.fan,
      'fanAuto': instance.fanAuto,
      'doorOpen': instance.doorOpen,
      'autoOpen': instance.autoOpen,
      'rfidAccess': instance.rfidAccess,
      'distance': instance.distance,
      'securityMode': instance.securityMode,
      'intruder': instance.intruder,
      'timestamp': instance.timestamp.toIso8601String(),
      'online': instance.online,
    };
