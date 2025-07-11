import 'package:flutter/material.dart';


const dangerCountries = {'CN', 'RU', 'KP'};
const safeCountries = {'JP', 'US', 'GB', 'DE', 'FR', 'CA', 'AU'};

Color _statusColor(String status) {
  switch (status) {
    case 'danger':
      return Colors.redAccent;
    case 'warning':
      return Colors.orange;
    default:
      return Colors.green;
  }
}

String _judgeStatus(String country) {
  final code = country.toUpperCase();
  if (dangerCountries.contains(code)) {
    return 'danger';
  }
  if (safeCountries.contains(code)) {
    return 'safe';
  }
  return 'warning';
}

class GeoipEntry {
  final String ip;
  final String domain;
  final String country;

  GeoipEntry(this.ip, this.domain, this.country);

  String get status => _judgeStatus(country);

  String get comment {
    switch (status) {
      case 'danger':
        return '危険国との通信';
      case 'warning':
        return '未知の国への通信';
      default:
        return '';
    }
  }
}

class CountryCount {
  final String country;
  final int count;
  CountryCount(this.country, this.count);

  String get status => _judgeStatus(country);
}

String _statusLabel(String status) {
  switch (status) {
    case 'danger':
      return '危険';
    case 'warning':
      return '注意';
    default:
      return '安全';
  }
}

String _countryName(String code) {
  const names = {
    'JP': '日本',
    'US': 'アメリカ',
    'CN': '中国',
    'RU': 'ロシア',
  };
  return names[code.toUpperCase()] ?? code;
}

class CountryCountTable extends StatelessWidget {
  final List<CountryCount> counts;
  const CountryCountTable({super.key, required this.counts});

  @override
  Widget build(BuildContext context) {
    return DataTable(
      columns: const [
        DataColumn(label: Text('国名')),
        DataColumn(label: Text('通信数')),
        DataColumn(label: Text('状態')),
      ],
      rows: [
        for (final c in counts)
          DataRow(
            color: MaterialStateProperty.all(
              _statusColor(c.status).withOpacity(0.1),
            ),
            cells: [
              DataCell(Text(_countryName(c.country))),
              DataCell(Text(c.count.toString())),
              DataCell(
                Text(
                  _statusLabel(c.status),
                  style: TextStyle(color: _statusColor(c.status)),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class GeoipResultPage extends StatelessWidget {
  final List<GeoipEntry> entries;
  const GeoipResultPage({super.key, required this.entries});

  List<CountryCount> _buildCounts() {
    final map = <String, int>{};
    for (final e in entries) {
      map[e.country] = (map[e.country] ?? 0) + 1;
    }
    final list = [for (final e in map.entries) CountryCount(e.key, e.value)];
    list.sort((a, b) => b.count.compareTo(a.count));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final counts = _buildCounts();
    return Scaffold(
      appBar: AppBar(title: const Text('GeoIP解析：通信先の国別リスクチェック')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '通信先の国を解析することで、不審な地域との通信を検知できます。ロシア・中国・北朝鮮などとの通信がある場合、マルウェア感染や情報漏洩の兆候である可能性があります。',
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: CountryCountTable(counts: counts),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: entries.length,
                itemBuilder: (context, idx) {
                  final e = entries[idx];
                  final color = _statusColor(e.status);
                  return Card(
                    color: color.withOpacity(0.2),
                    child: ListTile(
                      title: Text('${e.ip} (${e.domain})'),
                      subtitle: Text('${e.country} - ${e.comment}'),
                      leading: Icon(
                        e.status == 'danger'
                            ? Icons.error
                            : e.status == 'warning'
                                ? Icons.warning
                                : Icons.check_circle,
                        color: color,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

