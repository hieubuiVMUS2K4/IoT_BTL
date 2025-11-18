import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../models/iot_data_model.dart';

class IoTService {
   final String baseUrl;
   final String mqttUrl;
   final int mqttPort;

   // Network Configuration - Thay đổi IP này khi chuyển mạng WiFi
   static const String SERVER_IP = '10.137.147.176'; // IP của máy tính chạy server

   MqttServerClient? _mqttClient;
   Function(String topic, String payload)? _onMessageReceived;

   IoTService({
     String? serverIP,
     this.mqttPort = 1883,
   }) :
     baseUrl = 'http://${serverIP ?? SERVER_IP}:3000',
     mqttUrl = serverIP ?? SERVER_IP;

   // Factory constructor for default configuration
   factory IoTService.defaultConfig() {
     return IoTService(serverIP: SERVER_IP);
   }

  // Kết nối MQTT
  Future<bool> connectMQTT(Function(String topic, String payload) onMessageReceived) async {
    _onMessageReceived = onMessageReceived;

    _mqttClient = MqttServerClient(mqttUrl, 'flutter-client-${DateTime.now().millisecondsSinceEpoch}');
    _mqttClient!.port = mqttPort;
    _mqttClient!.logging(on: false);
    _mqttClient!.keepAlivePeriod = 20;
    _mqttClient!.onDisconnected = _onDisconnected;
    _mqttClient!.onConnected = _onConnected;
    _mqttClient!.onSubscribed = _onSubscribed;

    final connMessage = MqttConnectMessage()
        .withClientIdentifier('flutter-client-${DateTime.now().millisecondsSinceEpoch}')
        .startClean()
        .withWillQos(MqttQos.atMostOnce);

    _mqttClient!.connectionMessage = connMessage;

    try {
      await _mqttClient!.connect();
      return true;
    } catch (e) {
      print('MQTT connection failed: $e');
      return false;
    }
  }

  // Ngắt kết nối MQTT
  void disconnectMQTT() {
    _mqttClient?.disconnect();
    _mqttClient = null;
  }

  // MQTT event handlers
  void _onConnected() {
    print('MQTT Connected');
    _subscribeToTopics();
  }

  void _onDisconnected() {
    print('MQTT Disconnected');
  }

  void _onSubscribed(String topic) {
    print('Subscribed to $topic');
  }

  void _subscribeToTopics() {
    if (_mqttClient != null) {
      // Subscribe to sensor data topics
      _mqttClient!.subscribe('/iot/smarthome/sensors/#', MqttQos.atMostOnce);
      // Subscribe to system updates topic
      _mqttClient!.subscribe('/iot/smarthome/updates', MqttQos.atMostOnce);
      _mqttClient!.updates!.listen(_onMessage);
    }
  }

  void _onMessage(List<MqttReceivedMessage<MqttMessage>> event) {
    final MqttPublishMessage recMess = event[0].payload as MqttPublishMessage;
    final String topic = event[0].topic;
    final String payload = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

    if (_onMessageReceived != null) {
      _onMessageReceived!(topic, payload);
    }
  }

  // Publish MQTT message directly (for instant control commands)
  Future<bool> publishMessage(String topic, String payload) async {
    if (_mqttClient != null && _mqttClient!.connectionStatus!.state == MqttConnectionState.connected) {
      try {
        final builder = MqttClientPayloadBuilder();
        builder.addString(payload);
        _mqttClient!.publishMessage(
          topic,
          MqttQos.atMostOnce,
          builder.payload!,
        );
        return true;
      } catch (e) {
        print('Error publishing MQTT message: $e');
        return false;
      }
    }
    return false;
  }

}
