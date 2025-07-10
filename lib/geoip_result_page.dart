import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'geoip_entry.dart';

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



class CountryCount {
  final String country;
  final int count;
  CountryCount(this.country, this.count);

  String get status => judgeGeoipStatus(country);
}

class CountryCountChart extends StatelessWidget {
  final List<CountryCount> counts;
  const CountryCountChart({super.key, required this.counts});

  @override
  Widget build(BuildContext context) {
    if (counts.isEmpty) return const SizedBox.shrink();
    final groups = <BarChartGroupData>[];
    for (var i = 0; i < counts.length; i++) {
      final c = counts[i];
      groups.add(
        BarChartGroupData(x: i, barRods: [
          BarChartRodData(toY: c.count.toDouble(), color: _statusColor(c.status))
        ]),
      );
    }
    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          barGroups: groups,
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 1)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx >= 0 && idx < counts.length) {
                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      child: Text(counts[idx].country),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      ),
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
            CountryCountChart(counts: counts),
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

