// Generated file - Tạo bằng build_runner
part of 'iot_data_model.dart';

IoTData _$IoTDataFromJson(Map<String, dynamic> json) => IoTData(
      temperature: (json['temperature'] as num).toDouble(),
      humidity: (json['humidity'] as num).toDouble(),
      pirActive: json['pir'] as bool,
      led1: json['led1'] as bool,
      led2: json['led2'] as bool,
      fan: json['fan'] as bool? ?? false,
      fanAuto: json['fanAuto'] as bool? ?? true,
      doorOpen: json['door'] as bool,
      autoOpen: json['autoOpen'] as bool,
      rfidAccess: json['rfid'] as bool,
      distance: (json['distance'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      online: json['online'] as bool? ?? true,
    );

Map<String, dynamic> _$IoTDataToJson(IoTData instance) => <String, dynamic>{
      'temperature': instance.temperature,
      'humidity': instance.humidity,
      'pir': instance.pirActive,
      'led1': instance.led1,
      'led2': instance.led2,
      'fan': instance.fan,
      'fanAuto': instance.fanAuto,
      'door': instance.doorOpen,
      'autoOpen': instance.autoOpen,
      'rfid': instance.rfidAccess,
      'distance': instance.distance,
      'timestamp': instance.timestamp.toIso8601String(),
      'online': instance.online,
    };
