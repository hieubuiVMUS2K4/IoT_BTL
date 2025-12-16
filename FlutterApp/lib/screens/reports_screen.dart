import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../providers/auth_provider.dart';
import '../services/report_service.dart';
import '../models/report_model.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ReportService _reportService = ReportService();
  
  List<SystemEvent> _events = [];
  List<DailyStatistics> _statistics = [];
  bool _isLoading = true;
  
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      // Ưu tiên lấy data từ server PostgreSQL
      try {
        _events = await _reportService.getServerEvents(limit: 100);
        _statistics = await _reportService.getWeeklyStatisticsFromServer();
        print('✅ Loaded reports from PostgreSQL server');
      } catch (serverError) {
        print('⚠️  Server unavailable, falling back to local: $serverError');
        // Fallback sang local storage
        _events = await _reportService.getEventsByDateRange(_startDate, _endDate);
        _statistics = await _reportService.getWeeklyStatistics();
      }
    } catch (e) {
      print('Error loading reports: $e');
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );
    
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadData();
    }
  }

  Future<void> _exportSensorData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.currentUser!.permissions.canExportReports) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn không có quyền xuất báo cáo'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final csv = await _reportService.exportToCsv(_startDate, _endDate);
      final fileName = 'sensor_data_${DateFormat('yyyyMMdd').format(_startDate)}_${DateFormat('yyyyMMdd').format(_endDate)}.csv';
      final file = await _reportService.saveCsvToFile(csv, fileName);
      
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'IoT Sensor Data Report',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi xuất file: $e')),
      );
    }
  }

  Future<void> _exportEvents() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.currentUser!.permissions.canExportReports) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn không có quyền xuất báo cáo'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final csv = await _reportService.exportEventsToCsv(_startDate, _endDate);
      final fileName = 'events_${DateFormat('yyyyMMdd').format(_startDate)}_${DateFormat('yyyyMMdd').format(_endDate)}.csv';
      final file = await _reportService.saveCsvToFile(csv, fileName);
      
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'IoT Events Report',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi xuất file: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final canExport = authProvider.currentUser?.permissions.canExportReports ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Báo cáo'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.history), text: 'Sự kiện'),
            Tab(icon: Icon(Icons.analytics), text: 'Thống kê'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
            tooltip: 'Chọn khoảng thời gian',
          ),
          if (canExport)
            PopupMenuButton<String>(
              icon: const Icon(Icons.download),
              onSelected: (value) {
                if (value == 'sensors') {
                  _exportSensorData();
                } else if (value == 'events') {
                  _exportEvents();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'sensors',
                  child: Row(
                    children: [
                      Icon(Icons.sensors),
                      SizedBox(width: 8),
                      Text('Xuất dữ liệu sensor'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'events',
                  child: Row(
                    children: [
                      Icon(Icons.event_note),
                      SizedBox(width: 8),
                      Text('Xuất sự kiện'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          // Date range indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.calendar_today, size: 16),
                const SizedBox(width: 8),
                Text(
                  '${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildEventsTab(),
                      _buildStatisticsTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsTab() {
    if (_events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'Không có sự kiện trong khoảng thời gian này',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      );
    }

    // Group events by date
    final groupedEvents = <String, List<SystemEvent>>{};
    for (final event in _events) {
      final dateKey = DateFormat('dd/MM/yyyy').format(event.timestamp);
      groupedEvents.putIfAbsent(dateKey, () => []);
      groupedEvents[dateKey]!.add(event);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groupedEvents.length,
      itemBuilder: (context, index) {
        final dateKey = groupedEvents.keys.elementAt(index);
        final dayEvents = groupedEvents[dateKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                dateKey,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            ...dayEvents.map((event) => _EventTile(event: event)),
            const Divider(),
          ],
        ).animate().fadeIn(delay: (index * 50).ms);
      },
    );
  }

  Widget _buildStatisticsTab() {
    if (_statistics.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'Chưa có dữ liệu thống kê',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _statistics.length,
      itemBuilder: (context, index) {
        final stat = _statistics[index];
        return _StatisticsCard(statistics: stat)
            .animate()
            .fadeIn(delay: (index * 100).ms)
            .slideX(begin: 0.1);
      },
    );
  }
}

class _EventTile extends StatelessWidget {
  final SystemEvent event;

  const _EventTile({required this.event});

  IconData _getEventIcon() {
    switch (event.type) {
      case EventType.motionDetected:
        return Icons.motion_photos_on;
      case EventType.doorOpened:
      case EventType.doorClosed:
        return Icons.door_front_door;
      case EventType.intruderAlert:
        return Icons.warning;
      case EventType.securityModeOn:
      case EventType.securityModeOff:
        return Icons.shield;
      case EventType.led2On:
      case EventType.led2Off:
        return Icons.lightbulb;
      case EventType.fanOn:
      case EventType.fanOff:
        return Icons.air;
      case EventType.rfidAccess:
        return Icons.credit_card;
      case EventType.temperatureHigh:
        return Icons.thermostat;
      case EventType.humidityHigh:
        return Icons.water_drop;
    }
  }

  Color _getEventColor(BuildContext context) {
    switch (event.type) {
      case EventType.intruderAlert:
      case EventType.temperatureHigh:
      case EventType.humidityHigh:
        return Colors.red;
      case EventType.securityModeOn:
        return Colors.orange;
      case EventType.doorOpened:
      case EventType.motionDetected:
        return Colors.blue;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getEventColor(context).withOpacity(0.2),
          child: Icon(_getEventIcon(), color: _getEventColor(context)),
        ),
        title: Text(event.typeDisplayName),
        subtitle: Text(event.description),
        trailing: Text(
          DateFormat('HH:mm').format(event.timestamp),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}

class _StatisticsCard extends StatelessWidget {
  final DailyStatistics statistics;

  const _StatisticsCard({required this.statistics});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 20),
                const SizedBox(width: 8),
                Text(
                  DateFormat('EEEE, dd/MM/yyyy', 'vi').format(statistics.date),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const Divider(height: 24),
            
            // Temperature row
            _StatRow(
              icon: Icons.thermostat,
              label: 'Nhiệt độ',
              value: 'TB: ${statistics.avgTemperature.toStringAsFixed(1)}°C',
              detail: 'Min: ${statistics.minTemperature.toStringAsFixed(1)}° / Max: ${statistics.maxTemperature.toStringAsFixed(1)}°',
              color: Colors.orange,
            ),
            const SizedBox(height: 12),
            
            // Humidity row
            _StatRow(
              icon: Icons.water_drop,
              label: 'Độ ẩm',
              value: 'TB: ${statistics.avgHumidity.toStringAsFixed(1)}%',
              detail: 'Min: ${statistics.minHumidity.toStringAsFixed(1)}% / Max: ${statistics.maxHumidity.toStringAsFixed(1)}%',
              color: Colors.blue,
            ),
            const SizedBox(height: 12),
            
            // Events row
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    icon: Icons.motion_photos_on,
                    label: 'Chuyển động',
                    value: statistics.motionDetectionCount.toString(),
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    icon: Icons.door_front_door,
                    label: 'Cửa mở',
                    value: statistics.doorOpenCount.toString(),
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    icon: Icons.warning,
                    label: 'Cảnh báo',
                    value: statistics.intruderAlertCount.toString(),
                    color: statistics.intruderAlertCount > 0 ? Colors.red : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String detail;
  final Color color;

  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              Text(value, style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
        ),
        Text(
          detail,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color ?? Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
