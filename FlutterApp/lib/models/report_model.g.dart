// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'report_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SensorRecord _$SensorRecordFromJson(Map<String, dynamic> json) => SensorRecord(
      id: json['id'] as String,
      temperature: (json['temperature'] as num).toDouble(),
      humidity: (json['humidity'] as num).toDouble(),
      pirActive: json['pirActive'] as bool,
      led1: json['led1'] as bool,
      led2: json['led2'] as bool,
      fan: json['fan'] as bool,
      doorOpen: json['doorOpen'] as bool,
      distance: (json['distance'] as num).toDouble(),
      securityMode: json['securityMode'] as bool,
      intruder: json['intruder'] as bool,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );

Map<String, dynamic> _$SensorRecordToJson(SensorRecord instance) =>
    <String, dynamic>{
      'id': instance.id,
      'temperature': instance.temperature,
      'humidity': instance.humidity,
      'pirActive': instance.pirActive,
      'led1': instance.led1,
      'led2': instance.led2,
      'fan': instance.fan,
      'doorOpen': instance.doorOpen,
      'distance': instance.distance,
      'securityMode': instance.securityMode,
      'intruder': instance.intruder,
      'timestamp': instance.timestamp.toIso8601String(),
    };

DailyStatistics _$DailyStatisticsFromJson(Map<String, dynamic> json) =>
    DailyStatistics(
      date: DateTime.parse(json['date'] as String),
      avgTemperature: (json['avgTemperature'] as num).toDouble(),
      maxTemperature: (json['maxTemperature'] as num).toDouble(),
      minTemperature: (json['minTemperature'] as num).toDouble(),
      avgHumidity: (json['avgHumidity'] as num).toDouble(),
      maxHumidity: (json['maxHumidity'] as num).toDouble(),
      minHumidity: (json['minHumidity'] as num).toDouble(),
      motionDetectionCount: (json['motionDetectionCount'] as num).toInt(),
      doorOpenCount: (json['doorOpenCount'] as num).toInt(),
      intruderAlertCount: (json['intruderAlertCount'] as num).toInt(),
      totalFanOnTime:
          Duration(microseconds: (json['totalFanOnTime'] as num).toInt()),
      totalLed1OnTime:
          Duration(microseconds: (json['totalLed1OnTime'] as num).toInt()),
      totalLed2OnTime:
          Duration(microseconds: (json['totalLed2OnTime'] as num).toInt()),
    );

Map<String, dynamic> _$DailyStatisticsToJson(DailyStatistics instance) =>
    <String, dynamic>{
      'date': instance.date.toIso8601String(),
      'avgTemperature': instance.avgTemperature,
      'maxTemperature': instance.maxTemperature,
      'minTemperature': instance.minTemperature,
      'avgHumidity': instance.avgHumidity,
      'maxHumidity': instance.maxHumidity,
      'minHumidity': instance.minHumidity,
      'motionDetectionCount': instance.motionDetectionCount,
      'doorOpenCount': instance.doorOpenCount,
      'intruderAlertCount': instance.intruderAlertCount,
      'totalFanOnTime': instance.totalFanOnTime.inMicroseconds,
      'totalLed1OnTime': instance.totalLed1OnTime.inMicroseconds,
      'totalLed2OnTime': instance.totalLed2OnTime.inMicroseconds,
    };

SystemEvent _$SystemEventFromJson(Map<String, dynamic> json) => SystemEvent(
      id: json['id'] as String,
      type: $enumDecode(_$EventTypeEnumMap, json['type']),
      description: json['description'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      userId: json['userId'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$SystemEventToJson(SystemEvent instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': _$EventTypeEnumMap[instance.type]!,
      'description': instance.description,
      'timestamp': instance.timestamp.toIso8601String(),
      'userId': instance.userId,
      'metadata': instance.metadata,
    };

const _$EventTypeEnumMap = {
  EventType.motionDetected: 'motionDetected',
  EventType.doorOpened: 'doorOpened',
  EventType.doorClosed: 'doorClosed',
  EventType.intruderAlert: 'intruderAlert',
  EventType.securityModeOn: 'securityModeOn',
  EventType.securityModeOff: 'securityModeOff',
  EventType.led2On: 'led2On',
  EventType.led2Off: 'led2Off',
  EventType.fanOn: 'fanOn',
  EventType.fanOff: 'fanOff',
  EventType.rfidAccess: 'rfidAccess',
  EventType.temperatureHigh: 'temperatureHigh',
  EventType.humidityHigh: 'humidityHigh',
};

WifiConfig _$WifiConfigFromJson(Map<String, dynamic> json) => WifiConfig(
      ssid: json['ssid'] as String,
      password: json['password'] as String,
      staticIp: json['staticIp'] as String?,
      gateway: json['gateway'] as String?,
      subnet: json['subnet'] as String?,
      mqttServer: json['mqttServer'] as String?,
      mqttPort: (json['mqttPort'] as num?)?.toInt(),
      mqttUsername: json['mqttUsername'] as String?,
      mqttPassword: json['mqttPassword'] as String?,
    );

Map<String, dynamic> _$WifiConfigToJson(WifiConfig instance) =>
    <String, dynamic>{
      'ssid': instance.ssid,
      'password': instance.password,
      'staticIp': instance.staticIp,
      'gateway': instance.gateway,
      'subnet': instance.subnet,
      'mqttServer': instance.mqttServer,
      'mqttPort': instance.mqttPort,
      'mqttUsername': instance.mqttUsername,
      'mqttPassword': instance.mqttPassword,
    };

EspDeviceInfo _$EspDeviceInfoFromJson(Map<String, dynamic> json) =>
    EspDeviceInfo(
      deviceId: json['deviceId'] as String,
      firmwareVersion: json['firmwareVersion'] as String,
      ipAddress: json['ipAddress'] as String,
      macAddress: json['macAddress'] as String,
      freeHeap: (json['freeHeap'] as num).toInt(),
      uptime: (json['uptime'] as num).toInt(),
      wifiSsid: json['wifiSsid'] as String,
      wifiRssi: (json['wifiRssi'] as num).toInt(),
      mqttConnected: json['mqttConnected'] as bool,
      lastSeen: DateTime.parse(json['lastSeen'] as String),
    );

Map<String, dynamic> _$EspDeviceInfoToJson(EspDeviceInfo instance) =>
    <String, dynamic>{
      'deviceId': instance.deviceId,
      'firmwareVersion': instance.firmwareVersion,
      'ipAddress': instance.ipAddress,
      'macAddress': instance.macAddress,
      'freeHeap': instance.freeHeap,
      'uptime': instance.uptime,
      'wifiSsid': instance.wifiSsid,
      'wifiRssi': instance.wifiRssi,
      'mqttConnected': instance.mqttConnected,
      'lastSeen': instance.lastSeen.toIso8601String(),
    };
