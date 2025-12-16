import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/iot_provider.dart';
import '../providers/auth_provider.dart';
import '../services/report_service.dart';
import '../models/report_model.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ReportService _reportService = ReportService();
  List<DailyStatistics> _weeklyStats = [];
  List<SensorRecord> _todayRecords = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    // Initialize counters từ server
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final iotProvider = Provider.of<IoTProvider>(context, listen: false);
      iotProvider.initializeCountersFromServer();
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      // Ưu tiên lấy data từ server PostgreSQL
      try {
        _weeklyStats = await _reportService.getWeeklyStatisticsFromServer();
        
        // Lấy records hôm nay từ server
        final today = DateTime.now();
        final startOfDay = DateTime(today.year, today.month, today.day);
        final endOfDay = startOfDay.add(const Duration(days: 1));
        _todayRecords = await _reportService.getServerRecordsByDateRange(startOfDay, endOfDay);
        
        print('✅ Loaded data from PostgreSQL server');
      } catch (serverError) {
        print('⚠️  Server unavailable, falling back to local: $serverError');
        // Fallback sang local nếu server không khả dụng
        _weeklyStats = await _reportService.getWeeklyStatistics();
        _todayRecords = await _reportService.getTodayRecords();
      }
    } catch (e) {
      print('Error loading dashboard data: $e');
    }
    
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final iotProvider = Provider.of<IoTProvider>(context);
    // final authProvider = Provider.of<AuthProvider>(context);
    // final user = authProvider.currentUser; // Unused

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ===== REAL-TIME STATUS =====
                    _buildSectionTitle('Trạng thái hiện tại'),
                    const SizedBox(height: 12),
                    _buildRealTimeStatus(iotProvider),
                    
                    const SizedBox(height: 24),
                    
                    // ===== TEMPERATURE CHART =====
                    _buildSectionTitle('Nhiệt độ 7 ngày qua'),
                    const SizedBox(height: 12),
                    _buildTemperatureChart(),
                    
                    const SizedBox(height: 24),
                    
                    // ===== HUMIDITY CHART =====
                    _buildSectionTitle('Độ ẩm 7 ngày qua'),
                    const SizedBox(height: 12),
                    _buildHumidityChart(),
                    
                    const SizedBox(height: 24),
                    
                    // ===== EVENTS SUMMARY =====
                    _buildSectionTitle('Thống kê sự kiện hôm nay'),
                    const SizedBox(height: 12),
                    _buildEventsSummary(),
                    
                    const SizedBox(height: 24),
                    
                    // ===== DEVICE USAGE =====
                    _buildSectionTitle('Thời gian sử dụng thiết bị'),
                    const SizedBox(height: 12),
                    _buildDeviceUsageChart(),
                    
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    ).animate().fadeIn();
  }

  Widget _buildRealTimeStatus(IoTProvider provider) {
    final data = provider.data;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _StatusTile(
                    icon: Icons.thermostat,
                    label: 'Nhiệt độ',
                    value: '${data.temperature.toStringAsFixed(1)}°C',
                    color: data.temperature > 30 ? Colors.red : Colors.green,
                  ),
                ),
                Expanded(
                  child: _StatusTile(
                    icon: Icons.water_drop,
                    label: 'Độ ẩm',
                    value: '${data.humidity.toStringAsFixed(1)}%',
                    color: data.humidity > 80 ? Colors.blue : Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatusTile(
                    icon: Icons.motion_photos_on,
                    label: 'PIR',
                    value: data.pirActive ? 'Phát hiện' : 'Không',
                    color: data.pirActive ? Colors.orange : Colors.grey,
                  ),
                ),
                Expanded(
                  child: _StatusTile(
                    icon: Icons.door_front_door,
                    label: 'Cửa',
                    value: data.doorOpen ? 'Mở' : 'Đóng',
                    color: data.doorOpen ? Colors.orange : Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatusTile(
                    icon: Icons.shield,
                    label: 'An ninh',
                    value: data.securityMode ? 'BẬT' : 'Tắt',
                    color: data.securityMode ? Colors.red : Colors.grey,
                  ),
                ),
                Expanded(
                  child: _StatusTile(
                    icon: Icons.wifi,
                    label: 'Kết nối',
                    value: provider.isConnected ? 'Online' : 'Offline',
                    color: provider.isConnected ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _buildTemperatureChart() {
    if (_weeklyStats.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: Text('Chưa có dữ liệu')),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(show: true),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      return Text('${value.toInt()}°');
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() >= 0 && value.toInt() < _weeklyStats.length) {
                        final date = _weeklyStats[value.toInt()].date;
                        return Text('${date.day}/${date.month}');
                      }
                      return const Text('');
                    },
                  ),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: true),
              lineBarsData: [
                // Avg temperature
                LineChartBarData(
                  spots: _weeklyStats.asMap().entries.map((e) {
                    return FlSpot(e.key.toDouble(), e.value.avgTemperature);
                  }).toList(),
                  isCurved: true,
                  color: Colors.orange,
                  barWidth: 3,
                  dotData: const FlDotData(show: true),
                ),
                // Max temperature
                LineChartBarData(
                  spots: _weeklyStats.asMap().entries.map((e) {
                    return FlSpot(e.key.toDouble(), e.value.maxTemperature);
                  }).toList(),
                  isCurved: true,
                  color: Colors.red.withOpacity(0.5),
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                  dashArray: [5, 5],
                ),
                // Min temperature
                LineChartBarData(
                  spots: _weeklyStats.asMap().entries.map((e) {
                    return FlSpot(e.key.toDouble(), e.value.minTemperature);
                  }).toList(),
                  isCurved: true,
                  color: Colors.blue.withOpacity(0.5),
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                  dashArray: [5, 5],
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1);
  }

  Widget _buildHumidityChart() {
    if (_weeklyStats.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: Text('Chưa có dữ liệu')),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: 100,
              barGroups: _weeklyStats.asMap().entries.map((e) {
                return BarChartGroupData(
                  x: e.key,
                  barRods: [
                    BarChartRodData(
                      toY: e.value.avgHumidity,
                      color: Colors.blue,
                      width: 16,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                  ],
                );
              }).toList(),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      return Text('${value.toInt()}%');
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() >= 0 && value.toInt() < _weeklyStats.length) {
                        final date = _weeklyStats[value.toInt()].date;
                        return Text('${date.day}/${date.month}');
                      }
                      return const Text('');
                    },
                  ),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(show: true),
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1);
  }

  Widget _buildEventsSummary() {
    // Sử dụng real-time counters từ IoTProvider
    final iotProvider = Provider.of<IoTProvider>(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: _EventCountTile(
                icon: Icons.motion_photos_on,
                label: 'Chuyển động',
                count: iotProvider.todayMotionCount,
                color: Colors.orange,
              ),
            ),
            Expanded(
              child: _EventCountTile(
                icon: Icons.door_front_door,
                label: 'Cửa mở',
                count: iotProvider.todayDoorOpenCount,
                color: Colors.blue,
              ),
            ),
            Expanded(
              child: _EventCountTile(
                icon: Icons.warning,
                label: 'Cảnh báo',
                count: iotProvider.todayIntruderCount,
                color: Colors.red,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1);
  }

  Widget _buildDeviceUsageChart() {
    final todayStat = _weeklyStats.isNotEmpty ? _weeklyStats.last : null;

    if (todayStat == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: Text('Chưa có dữ liệu')),
        ),
      );
    }

    final fanMinutes = todayStat.totalFanOnTime.inMinutes;
    final led1Minutes = todayStat.totalLed1OnTime.inMinutes;
    final led2Minutes = todayStat.totalLed2OnTime.inMinutes;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _UsageBar(
              label: 'Quạt',
              icon: Icons.air,
              value: fanMinutes,
              maxValue: 60 * 24,
              color: Colors.green,
            ),
            const SizedBox(height: 12),
            _UsageBar(
              label: 'LED 1 (PIR)',
              icon: Icons.lightbulb,
              value: led1Minutes,
              maxValue: 60 * 24,
              color: Colors.amber,
            ),
            const SizedBox(height: 12),
            _UsageBar(
              label: 'LED 2',
              icon: Icons.lightbulb_outline,
              value: led2Minutes,
              maxValue: 60 * 24,
              color: Colors.orange,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1);
  }
}

// ===== HELPER WIDGETS =====

class _StatusTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatusTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 32, color: color),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
      ],
    );
  }
}

class _EventCountTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;

  const _EventCountTile({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(height: 8),
        Text(
          count.toString(),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _UsageBar extends StatelessWidget {
  final String label;
  final IconData icon;
  final int value;
  final int maxValue;
  final Color color;

  const _UsageBar({
    required this.label,
    required this.icon,
    required this.value,
    required this.maxValue,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = (value / maxValue).clamp(0.0, 1.0);
    final hours = value ~/ 60;
    final minutes = value % 60;

    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label),
                  Text('${hours}h ${minutes}m'),
                ],
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: percentage,
                backgroundColor: color.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
