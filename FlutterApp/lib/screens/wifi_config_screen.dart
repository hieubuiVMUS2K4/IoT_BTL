import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/auth_provider.dart';
import '../services/wifi_config_service.dart';
import '../models/report_model.dart';

class WifiConfigScreen extends StatefulWidget {
  const WifiConfigScreen({super.key});

  @override
  State<WifiConfigScreen> createState() => _WifiConfigScreenState();
}

class _WifiConfigScreenState extends State<WifiConfigScreen> {
  final WifiConfigService _wifiService = WifiConfigService();
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();
  final _espIpController = TextEditingController(text: '192.168.4.1');
  
  // State
  bool _isLoading = false;
  bool _obscurePassword = true;
  EspDeviceInfo? _deviceInfo;
  List<WifiNetwork> _networks = [];
  WifiConfig? _currentConfig;
  OtaUpdateInfo? _otaInfo;
  OtaStatus? _otaStatus;

  @override
  void initState() {
    super.initState();
    _loadDeviceInfo();
  }

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    _espIpController.dispose();
    super.dispose();
  }

  Future<void> _loadDeviceInfo() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    _wifiService.setEspAddress(_espIpController.text);
    
    try {
      _deviceInfo = await _wifiService.getDeviceInfo();
      _currentConfig = await _wifiService.getCurrentConfig();
      _otaInfo = await _wifiService.checkForUpdate();
      
      if (_currentConfig != null && mounted) {
        _ssidController.text = _currentConfig!.ssid;
      }
    } catch (e) {
      if (mounted) {
        _showError('Không thể kết nối đến ESP8266: $e');
      }
    }
    
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _scanNetworks() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      _networks = await _wifiService.scanWifiNetworks();
      if (_networks.isEmpty && mounted) {
        _showError('Không tìm thấy mạng WiFi nào');
      }
    } catch (e) {
      if (mounted) {
        _showError('Lỗi quét WiFi: $e');
      }
    }
    
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _saveWifiConfig() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final config = WifiConfig(
        ssid: _ssidController.text,
        password: _passwordController.text,
        mqttServer: null,
        mqttPort: null,
        mqttUsername: null,
        mqttPassword: null,
      );
      
      final success = await _wifiService.updateWifiConfig(config);
      
      if (success) {
        _showSuccess('Cấu hình đã được lưu. ESP sẽ khởi động lại...');
        await Future.delayed(const Duration(seconds: 2));
        await _wifiService.restartDevice();
      } else {
        _showError('Không thể lưu cấu hình');
      }
    } catch (e) {
      _showError('Lỗi: $e');
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _startOtaUpdate() async {
    if (_otaInfo == null || !_otaInfo!.updateAvailable) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cập nhật Firmware'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Phiên bản hiện tại: ${_otaInfo!.currentVersion}'),
            Text('Phiên bản mới: ${_otaInfo!.latestVersion}'),
            if (_otaInfo!.changeLog != null) ...[
              const SizedBox(height: 12),
              const Text('Thay đổi:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(_otaInfo!.changeLog!),
            ],
            const SizedBox(height: 12),
            const Text(
              'Lưu ý: Không tắt nguồn ESP trong quá trình cập nhật!',
              style: TextStyle(color: Colors.red),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cập nhật'),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    setState(() => _isLoading = true);
    
    try {
      final success = await _wifiService.startOtaUpdate(_otaInfo!.firmwareUrl!);
      
      if (success) {
        // Poll for OTA status
        _pollOtaStatus();
      } else {
        _showError('Không thể bắt đầu cập nhật');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      _showError('Lỗi: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pollOtaStatus() async {
    while (true) {
      await Future.delayed(const Duration(seconds: 1));
      
      _otaStatus = await _wifiService.getOtaStatus();
      setState(() {});
      
      if (_otaStatus == null || _otaStatus!.isSuccess || _otaStatus!.isFailed) {
        break;
      }
    }
    
    setState(() => _isLoading = false);
    
    if (_otaStatus?.isSuccess == true) {
      _showSuccess('Cập nhật thành công! ESP đang khởi động lại...');
    } else if (_otaStatus?.isFailed == true) {
      _showError('Cập nhật thất bại: ${_otaStatus?.error}');
    }
  }

  Future<void> _factoryReset() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Factory Reset'),
        content: const Text(
          'Tất cả cài đặt sẽ bị xóa và ESP sẽ trở về chế độ AP. '
          'Bạn có chắc chắn muốn tiếp tục?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    setState(() => _isLoading = true);
    
    try {
      final success = await _wifiService.factoryReset();
      if (success) {
        _showSuccess('Factory reset thành công. ESP đang khởi động lại...');
      } else {
        _showError('Không thể thực hiện factory reset');
      }
    } catch (e) {
      _showError('Lỗi: $e');
    }
    
    setState(() => _isLoading = false);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final canConfigure = authProvider.currentUser?.permissions.canConfigureWifi ?? false;

    if (!canConfigure) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cấu hình WiFi')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('Bạn không có quyền truy cập tính năng này'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cấu hình ESP8266'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadDeviceInfo,
          ),
        ],
      ),
      body: _isLoading && _otaStatus == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ===== ESP IP INPUT =====
                    _buildSectionTitle('Địa chỉ ESP'),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _espIpController,
                                decoration: const InputDecoration(
                                  labelText: 'IP Address',
                                  hintText: '192.168.4.1',
                                  prefixIcon: Icon(Icons.router),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: _isLoading ? null : _loadDeviceInfo,
                              child: const Text('Kết nối'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // ===== DEVICE INFO =====
                    if (_deviceInfo != null) ...[
                      _buildSectionTitle('Thông tin thiết bị'),
                      _buildDeviceInfoCard(),
                      const SizedBox(height: 24),
                    ],
                    
                    // ===== OTA UPDATE =====
                    if (_otaInfo != null) ...[
                      _buildSectionTitle('Cập nhật Firmware'),
                      _buildOtaCard(),
                      const SizedBox(height: 24),
                    ],
                    
                    // ===== WIFI CONFIG =====
                    _buildSectionTitle('Cấu hình WiFi'),
                    _buildWifiConfigCard(),
                    
                    const SizedBox(height: 24),
                    
                    // ===== ACTIONS =====
                    FilledButton.icon(
                      onPressed: _isLoading ? null : _saveWifiConfig,
                      icon: const Icon(Icons.save),
                      label: const Text('Lưu cấu hình'),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    OutlinedButton.icon(
                      onPressed: _isLoading ? null : _factoryReset,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      icon: const Icon(Icons.restore),
                      label: const Text('Factory Reset'),
                    ),
                    
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _buildDeviceInfoCard() {
    final info = _deviceInfo!;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _InfoRow(label: 'Device ID', value: info.deviceId),
            _InfoRow(label: 'Firmware', value: info.firmwareVersion),
            _InfoRow(label: 'IP Address', value: info.ipAddress),
            _InfoRow(label: 'MAC', value: info.macAddress),
            _InfoRow(label: 'WiFi SSID', value: info.wifiSsid),
            _InfoRow(
              label: 'Tín hiệu',
              value: '${info.wifiRssi} dBm (${info.signalStrength})',
            ),
            _InfoRow(label: 'Uptime', value: info.uptimeFormatted),
            _InfoRow(label: 'Free RAM', value: '${info.freeHeap} bytes'),
            _InfoRow(
              label: 'MQTT',
              value: info.mqttConnected ? 'Đã kết nối' : 'Chưa kết nối',
              valueColor: info.mqttConnected ? Colors.green : Colors.red,
            ),
          ],
        ),
      ),
    ).animate().fadeIn();
  }

  Widget _buildOtaCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  _otaInfo!.updateAvailable 
                      ? Icons.system_update 
                      : Icons.check_circle,
                  color: _otaInfo!.updateAvailable 
                      ? Colors.orange 
                      : Colors.green,
                  size: 48,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _otaInfo!.updateAvailable 
                            ? 'Có bản cập nhật mới!' 
                            : 'Đã cập nhật mới nhất',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text('Hiện tại: ${_otaInfo!.currentVersion}'),
                      if (_otaInfo!.updateAvailable)
                        Text('Mới nhất: ${_otaInfo!.latestVersion}'),
                    ],
                  ),
                ),
              ],
            ),
            if (_otaStatus != null && _otaStatus!.isInProgress) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _otaStatus!.progress / 100),
              const SizedBox(height: 8),
              Text('Đang cập nhật: ${_otaStatus!.progress}%'),
            ],
            if (_otaInfo!.updateAvailable && 
                (_otaStatus == null || !_otaStatus!.isInProgress)) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _startOtaUpdate,
                icon: const Icon(Icons.download),
                label: const Text('Cập nhật ngay'),
              ),
            ],
          ],
        ),
      ),
    ).animate().fadeIn();
  }

  Widget _buildWifiConfigCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _ssidController,
                    decoration: const InputDecoration(
                      labelText: 'SSID',
                      prefixIcon: Icon(Icons.wifi),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Vui lòng nhập SSID';
                      }
                      return null;
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _scanNetworks,
                  tooltip: 'Quét mạng WiFi',
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
              ),
            ),
            
            // Network list
            if (_networks.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Mạng WiFi tìm thấy:',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              ...List.generate(_networks.length, (index) {
                final network = _networks[index];
                return ListTile(
                  leading: Icon(
                    _getSignalIcon(network.signalBars),
                    color: network.signalBars >= 2 ? Colors.green : Colors.orange,
                  ),
                  title: Text(network.ssid),
                  subtitle: Text('${network.rssi} dBm - ${network.signalStrength}'),
                  trailing: network.isSecured 
                      ? const Icon(Icons.lock, size: 16) 
                      : null,
                  onTap: () {
                    _ssidController.text = network.ssid;
                    setState(() => _networks = []);
                  },
                );
              }),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(delay: 100.ms);
  }

  IconData _getSignalIcon(int bars) {
    switch (bars) {
      case 4:
        return Icons.signal_wifi_4_bar;
      case 3:
        return Icons.network_wifi_3_bar;
      case 2:
        return Icons.network_wifi_2_bar;
      case 1:
        return Icons.network_wifi_1_bar;
      default:
        return Icons.signal_wifi_0_bar;
    }
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: valueColor,
                ),
          ),
        ],
      ),
    );
  }
}
