import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/iot_provider.dart';

class ConnectionStatusWidget extends StatelessWidget {
  const ConnectionStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final iotProvider = Provider.of<IoTProvider>(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iotProvider.isConnected ? Colors.green : Colors.red,
              boxShadow: [
                if (iotProvider.isConnected)
                  BoxShadow(
                    color: Colors.green.withOpacity(0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            iotProvider.isConnected ? 'Online' : 'Offline',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
