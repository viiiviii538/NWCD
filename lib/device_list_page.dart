import 'package:flutter/material.dart';
import 'package:nwc_densetsu/network_scan.dart';
import 'package:nwc_densetsu/diagnostics.dart';

class DeviceListPage extends StatelessWidget {
  final List<NetworkDevice> devices;
  final List<SecurityReport> reports;

  const DeviceListPage({
    super.key,
    required this.devices,
    required this.reports,
  });

  Color _scoreColor(int score) {
    if (score >= 8) return Colors.redAccent;
    if (score >= 5) return Colors.orange;
    return Colors.green;
  }

  String _riskState(int score) {
    if (score >= 8) return '危険';
    if (score >= 5) return '注意';
    return '安全';
  }

  @override
  Widget build(BuildContext context) {
    final rows = <DataRow>[];
    for (final d in devices) {
      final rep =
          reports.firstWhere((r) => r.ip == d.ip, orElse: () => const SecurityReport('', 0, [], [], '', openPorts: [], geoip: ''));
      final status = _riskState(rep.score);
      final comment = rep.risks.isNotEmpty ? rep.risks.first.description : '';
      rows.add(
        DataRow(
          color: MaterialStateProperty.all(
            _scoreColor(rep.score).withOpacity(0.2),
          ),
          cells: [
            DataCell(Text(d.ip)),
            DataCell(Text(d.mac)),
            DataCell(Text(d.vendor)),
            DataCell(Text(d.name)),
            DataCell(Text(status)),
            DataCell(Text(comment)),
          ],
        ),
      );
    }

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
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('IPアドレス')),
                    DataColumn(label: Text('MACアドレス')),
                    DataColumn(label: Text('ベンダー名')),
                    DataColumn(label: Text('機器名')),
                    DataColumn(label: Text('状態')),
                    DataColumn(label: Text('コメント')),
                  ],
                  rows: rows,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

