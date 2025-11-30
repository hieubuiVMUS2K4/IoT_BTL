import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SecurityCard extends StatelessWidget {
  final bool securityMode;
  final bool intruderDetected;
  final VoidCallback onToggle;

  const SecurityCard({
    super.key,
    required this.securityMode,
    required this.intruderDetected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: securityMode ? 8 : 2,
      color: intruderDetected
          ? Colors.red.shade50
          : securityMode
              ? Colors.orange.shade50
              : null,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: intruderDetected
                          ? Colors.red.shade100
                          : securityMode
                              ? Colors.orange.shade100
                              : Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      intruderDetected
                          ? Icons.warning_rounded
                          : securityMode
                              ? Icons.shield
                              : Icons.shield_outlined,
                      color: intruderDetected
                          ? Colors.red.shade700
                          : securityMode
                              ? Colors.orange.shade700
                              : Colors.blue.shade700,
                      size: 28,
                    ),
                  )
                      .animate(
                        onPlay: (controller) =>
                            intruderDetected ? controller.repeat() : null,
                      )
                      .shake(
                        duration: 500.ms,
                        hz: 4,
                      ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chế độ an ninh',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          intruderDetected
                              ? 'Phát hiện xâm nhập!'
                              : securityMode
                                  ? 'Đang bảo vệ'
                                  : 'Không hoạt động',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: intruderDetected
                                        ? Colors.red.shade700
                                        : securityMode
                                            ? Colors.orange.shade700
                                            : Colors.grey.shade600,
                                    fontWeight: intruderDetected
                                        ? FontWeight.bold
                                        : null,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  // Toggle Switch
                  Switch(
                    value: securityMode,
                    onChanged: (_) => onToggle(),
                    activeColor: Colors.orange.shade700,
                  ),
                ],
              ),

              if (intruderDetected) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.red.shade300,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.emergency,
                        color: Colors.red.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '🚨 CẢNH BÁO: Phát hiện chuyển động hoặc có vật thể gần!',
                          style: TextStyle(
                            color: Colors.red.shade900,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
                    .animate(
                      onPlay: (controller) => controller.repeat(),
                    )
                    .shimmer(
                      duration: 1000.ms,
                      color: Colors.red.shade200,
                    ),
              ],

              if (securityMode && !intruderDetected) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.security,
                        color: Colors.orange.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Hệ thống đang giám sát - LED nhấp nháy',
                          style: TextStyle(
                            color: Colors.orange.shade900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (!securityMode) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.grey.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Nhấn để bật chế độ bảo vệ',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
