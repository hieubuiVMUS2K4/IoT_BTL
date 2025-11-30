import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/auth_provider.dart';
import '../providers/iot_provider.dart';
import '../widgets/sensor_card.dart';
import '../widgets/control_card.dart';
import '../widgets/connection_status.dart';
import '../widgets/security_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  IoTProvider? _iotProvider;

  @override
  void initState() {
    super.initState();
    // Use post-frame callback to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeConnection();
    });
  }

  Future<void> _initializeConnection() async {
    _iotProvider = Provider.of<IoTProvider>(context, listen: false);
    
    // Kết nối WebSocket
    _iotProvider!.connectWebSocket();
    
    // Fetch dữ liệu ban đầu
    await _iotProvider!.fetchCurrentData();
  }

  @override
  void dispose() {
    _iotProvider?.disconnect();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    final iotProvider = Provider.of<IoTProvider>(context, listen: false);
    await iotProvider.fetchCurrentData();
  }

  void _handleLogout() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc muốn đăng xuất?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await authProvider.logout();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final iotProvider = Provider.of<IoTProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Smart Home'),
            Text(
              'Xin chào, ${authProvider.currentUser?.fullName ?? "User"}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white70,
              ),
            ),
          ],
        ),
        actions: [
          // Connection Status
          const ConnectionStatusWidget(),
          
          // Refresh Button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _handleRefresh,
          ),
          
          // Logout Button
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: iotProvider.isLoading && !iotProvider.isConnected
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Temperature & Humidity Section
                    Text(
                      'Nhiệt độ & Độ ẩm',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    Row(
                      children: [
                        Expanded(
                          child: SensorCard(
                            icon: Icons.thermostat,
                            iconColor: Colors.orange,
                            title: 'Nhiệt độ',
                            value: '${iotProvider.data.temperature.toStringAsFixed(1)}°C',
                            trend: iotProvider.data.temperature > 30 ? 'Cao' : 'Bình thường',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SensorCard(
                            icon: Icons.water_drop,
                            iconColor: Colors.blue,
                            title: 'Độ ẩm',
                            value: '${iotProvider.data.humidity.toStringAsFixed(1)}%',
                            trend: iotProvider.data.humidity > 80 ? 'Cao' : 'Bình thường',
                          ),
                        ),
                      ],
                    ).animate().fadeIn(duration: 400.ms),
                    
                    const SizedBox(height: 24),
                    
                    // Motion & Lights Section
                    Text(
                      'Cảm biến & Đèn',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    SensorCard(
                      icon: Icons.motion_photos_on,
                      iconColor: iotProvider.data.pirActive ? Colors.green : Colors.grey,
                      title: 'Cảm biến chuyển động (PIR)',
                      value: iotProvider.data.pirActive ? 'Phát hiện' : 'Không có',
                      isActive: iotProvider.data.pirActive,
                    ).animate().fadeIn(delay: 100.ms),
                    
                    const SizedBox(height: 12),
                    
                    Row(
                      children: [
                        Expanded(
                          child: SensorCard(
                            icon: Icons.lightbulb,
                            iconColor: iotProvider.data.led1 ? Colors.amber : Colors.grey,
                            title: 'LED 1 (PIR)',
                            value: iotProvider.data.led1 ? 'Bật' : 'Tắt',
                            subtitle: 'Tự động',
                            isActive: iotProvider.data.led1,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SensorCard(
                            icon: Icons.lightbulb,
                            iconColor: iotProvider.data.led2 ? Colors.amber : Colors.grey,
                            title: 'LED 2',
                            value: iotProvider.data.led2 ? 'Bật' : 'Tắt',
                            subtitle: 'Điều khiển',
                            isActive: iotProvider.data.led2,
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 200.ms),
                    
                    const SizedBox(height: 24),
                    
                    // Security Mode Section
                    Text(
                      'An ninh',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    SecurityCard(
                      securityMode: iotProvider.data.securityMode,
                      intruderDetected: iotProvider.data.intruder,
                      onToggle: () => _toggleSecurityMode(iotProvider),
                    ).animate().fadeIn(delay: 250.ms),
                    
                    const SizedBox(height: 24),
                    
                    // LED 2 Controls
                    ControlCard(
                      title: 'Điều khiển LED 2',
                      icon: Icons.lightbulb_outline,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildControlButton(
                                context,
                                'Bật',
                                Icons.power_settings_new,
                                Colors.green,
                                () => _controlLed2('on'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildControlButton(
                                context,
                                'Tắt',
                                Icons.power_off,
                                Colors.red,
                                () => _controlLed2('off'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildControlButton(
                                context,
                                'Toggle',
                                Icons.toggle_on,
                                Colors.orange,
                                () => _controlLed2('toggle'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ).animate().fadeIn(delay: 300.ms),
                    
                    const SizedBox(height: 24),
                    
                    // Fan Controls
                    ControlCard(
                      title: 'Điều khiển quạt',
                      icon: Icons.air,
                      children: [
                        // Trạng thái quạt
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: iotProvider.data.fan 
                                ? Colors.blue.withOpacity(0.1)
                                : Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                iotProvider.data.fan ? Icons.toys : Icons.toys_outlined,
                                color: iotProvider.data.fan ? Colors.blue : Colors.grey,
                                size: 32,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      iotProvider.data.fan ? 'Đang bật' : 'Đang tắt',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      iotProvider.data.fanAuto 
                                          ? '🤖 Chế độ tự động (>30°C)'
                                          : '👤 Chế độ thủ công',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Buttons điều khiển
                        Row(
                          children: [
                            Expanded(
                              child: _buildControlButton(
                                context,
                                'Bật',
                                Icons.power_settings_new,
                                Colors.blue,
                                () => _controlFan('on'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildControlButton(
                                context,
                                'Tắt',
                                Icons.power_off,
                                Colors.grey,
                                () => _controlFan('off'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildControlButton(
                                context,
                                'Toggle',
                                Icons.cached,
                                Colors.teal,
                                () => _controlFan('toggle'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ).animate().fadeIn(delay: 350.ms),
                    
                    const SizedBox(height: 24),
                    
                    // Door Section
                    Text(
                      'Điều khiển cửa',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    SensorCard(
                      icon: Icons.door_sliding,
                      iconColor: iotProvider.data.doorOpen ? Colors.green : Colors.grey,
                      title: 'Trạng thái cửa',
                      value: iotProvider.data.doorOpen ? 'Mở' : 'Đóng',
                      isActive: iotProvider.data.doorOpen,
                    ).animate().fadeIn(delay: 400.ms),
                    
                    const SizedBox(height: 12),
                    
                    ControlCard(
                      title: 'Điều khiển cửa',
                      icon: Icons.door_front_door,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildControlButton(
                                context,
                                'Mở',
                                Icons.lock_open,
                                Colors.green,
                                () => _controlDoor('open'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildControlButton(
                                context,
                                'Đóng',
                                Icons.lock,
                                Colors.red,
                                () => _controlDoor('close'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildControlButton(
                                context,
                                'Toggle',
                                Icons.swap_horiz,
                                Colors.blue,
                                () => _controlDoor('toggle'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ).animate().fadeIn(delay: 500.ms),
                    
                    const SizedBox(height: 24),
                    
                    // Distance & RFID Section
                    Text(
                      'Cảm biến khác',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    SensorCard(
                      icon: Icons.radar,
                      iconColor: Colors.orange,
                      title: 'Khoảng cách (HC-SR04)',
                      value: '${iotProvider.data.distance.toStringAsFixed(1)} cm',
                      subtitle: iotProvider.data.autoOpen 
                          ? '🚶 Tự động mở cửa kích hoạt' 
                          : 'Chờ phát hiện (< 10cm)',
                      isActive: iotProvider.data.autoOpen,
                    ).animate().fadeIn(delay: 600.ms),
                    
                    const SizedBox(height: 12),
                    
                    SensorCard(
                      icon: Icons.credit_card,
                      iconColor: iotProvider.data.rfidAccess ? Colors.green : Colors.grey,
                      title: 'RFID Access',
                      value: iotProvider.data.rfidAccess ? 'Thẻ hợp lệ' : 'Sẵn sàng',
                      subtitle: iotProvider.data.rfidAccess ? '🔓 Cửa đã mở tự động' : 'Chờ quẹt thẻ...',
                      isActive: iotProvider.data.rfidAccess,
                    ).animate().fadeIn(delay: 700.ms),
                    
                    const SizedBox(height: 16),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildControlButton(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Future<void> _controlLed2(String action) async {
    final iotProvider = Provider.of<IoTProvider>(context, listen: false);
    final success = await iotProvider.controlLed2(action);
    
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Đã gửi lệnh $action LED 2' : 'Lỗi kết nối'),
        backgroundColor: success ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _controlDoor(String action) async {
    final iotProvider = Provider.of<IoTProvider>(context, listen: false);
    final success = await iotProvider.controlDoor(action);
    
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Đã gửi lệnh $action cửa' : 'Lỗi kết nối'),
        backgroundColor: success ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _controlFan(String action) async {
    final iotProvider = Provider.of<IoTProvider>(context, listen: false);
    final success = await iotProvider.controlFan(action);
    
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Đã gửi lệnh $action quạt' : 'Lỗi kết nối'),
        backgroundColor: success ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _toggleSecurityMode(IoTProvider iotProvider) async {
    final success = await iotProvider.toggleSecurityMode();
    
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? iotProvider.data.securityMode
                  ? '🛡️ Chế độ an ninh đã BẬT'
                  : '🔓 Chế độ an ninh đã TẮT'
              : 'Lỗi kết nối',
        ),
        backgroundColor: success ? Colors.orange : Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
