import 'package:flutter/material.dart';
import 'package:nwc_densetsu/network_scan.dart';
import 'package:nwc_densetsu/diagnostics.dart';
import 'package:nwc_densetsu/device_table.dart';

class DeviceListPage extends StatelessWidget {
  final List<NetworkDevice> devices;
  final List<SecurityReport> reports;

  const DeviceListPage({
    super.key,
    required this.devices,
    required this.reports,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('LAN内デバイス一覧とリスクチェック')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'LAN内に接続されているすべての機器を可視化することで、不審なデバイスの存在に気付きやすくなります。知らない機器が接続されたまま放置されると、内部侵入や情報流出の温床になる可能性があります。',
            ),
            const SizedBox(height: 16),
            Expanded(
              child: DeviceTable(devices: devices, reports: reports),
            ),
          ],
        ),
      ),
    );
  }
}

