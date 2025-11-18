import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../models/iot_data_model.dart';

class IoTService {
   final String baseUrl;
   final String mqttUrl;
   final int mqttPort;

   MqttServerClient? _mqttClient;
   Function(String topic, String payload)? _onMessageReceived;

   IoTService({
     this.baseUrl = 'http://10.137.147.176:3000', // Thay IP của PC
     this.mqttUrl = '10.137.147.176', // MQTT broker IP
     this.mqttPort = 1883,
   });

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
      _mqttClient!.subscribe('/iot/smarthome/sensors/#', MqttQos.atMostOnce);
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

  // Lấy dữ liệu hiện tại qua HTTP
  Future<IoTData?> getCurrentData() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/status'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return IoTData.fromJson(data);
      }
      return null;
    } catch (e) {
      print('Error getting current data: $e');
      return null;
    }
  }

  // Điều khiển LED 2
  Future<bool> controlLed2(String action) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/control'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'device': 'led2',
          'action': action,
        }),
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      print('Error controlling LED2: $e');
      return false;
    }
  }

  // Điều khiển cửa
  Future<bool> controlDoor(String action) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/control'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'device': 'door',
          'action': action,
        }),
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      print('Error controlling door: $e');
      return false;
    }
  }

  // Kiểm tra kết nối
  Future<bool> checkConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/status'),
      ).timeout(const Duration(seconds: 3));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
