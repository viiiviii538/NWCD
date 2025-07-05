import 'package:flutter/material.dart';
import 'dart:io';

import 'package:nwc_densetsu/diagnostics.dart' as diag;
import 'package:nwc_densetsu/diagnostics.dart'
    show PortScanSummary, SecurityReport, SslResult;
import 'package:nwc_densetsu/network_scan.dart' as net;
import 'package:nwc_densetsu/network_scan.dart'
    show NetworkDevice;
import 'package:fl_chart/fl_chart.dart';
import 'package:nwc_densetsu/utils/file_utils.dart' as utils;
import 'package:nwc_densetsu/progress_list.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'NWCD',
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _output = '';
  List<PortScanSummary> _scanResults = [];
  List<NetworkDevice> _devices = <NetworkDevice>[];
  List<SecurityReport> _reports = [];
  bool _lanScanning = false;
  final Map<String, int> _progress = {};
  static const int _taskCount = 3; // port, SSL, SPF


  Future<void> _runLanScan() async {
    setState(() {
      _lanScanning = true;
      _devices = <NetworkDevice>[];
      _scanResults = [];
      _reports = [];
      _output = '診断中...\n';
      _progress.clear();
    });

    final devices = await net.scanNetwork(onError: (msg) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('LANスキャン失敗: $msg')));
      }
    });
    setState(() {
      _devices = devices;
      for (final d in devices) {
        _progress[d.ip] = 0;
      }
    });

    final buffer = StringBuffer();
    for (final d in devices) {
      final ip = d.ip;
      buffer.writeln('--- $ip ---');
      final pingRes = await diag.runPing(ip);
      buffer.writeln(pingRes);

      final portFuture = diag.scanPorts(ip).then((value) {
        setState(() => _progress[ip] = (_progress[ip] ?? 0) + 1);
        return value;
      });
      final sslFuture = diag.checkSslCertificate(ip).then((value) {
        setState(() => _progress[ip] = (_progress[ip] ?? 0) + 1);
        return value;
      });
      final spfFuture = diag.checkSpfRecord(ip).then((value) {
        setState(() => _progress[ip] = (_progress[ip] ?? 0) + 1);
        return value;
      });

      final results = await Future.wait([portFuture, sslFuture, spfFuture]);

      final summary = results[0] as PortScanSummary;
      final sslRes = results[1] as SslResult;
      final spfRes = results[2] as String;

      _scanResults.add(summary);
      for (final r in summary.results) {
        buffer.writeln('Port ${r.port}: ${r.state} ${r.service}');
      }

      buffer.writeln(sslRes.message);
      buffer.writeln(spfRes);

      final report = await diag.runSecurityReport(
        ip: ip,
        openPorts: [
          for (final r in summary.results)
            if (r.state == 'open') r.port
        ],
        sslValid: sslRes.valid,
        spfValid: spfRes.startsWith('SPF record'),
      );
      _reports.add(report);
      buffer.writeln('Score: ${report.score}');
      for (final r in report.risks) {
        buffer.writeln('- ${r.description} => ${r.countermeasure}');
      }
      if (report.score <= 5) {
        buffer.writeln('UTM導入を推奨します');
      }

      setState(() => _progress.remove(ip));
    }

    setState(() {
      _output = buffer.toString();
      _lanScanning = false;
      _devices = devices;
    });
  }


  Future<void> _saveReportFile() async {
    final now = DateTime.now();
    final stamp =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}';
    final path = await utils.getSavePath(suggestedName: 'report_$stamp.txt');
    if (path == null) return;
    final file = File(path);
    await file.writeAsString(_output);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('保存完了')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NWCD')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Tooltip(
              message: 'LAN 内のデバイスをスキャンして診断を実行します',
              child: ElevatedButton(
                onPressed: _lanScanning ? null : _runLanScan,
                child: const Text('LANスキャン'),
              ),
            ),
            if (_lanScanning) ...[
              const SizedBox(height: 8),
              const CircularProgressIndicator(),
              ScanningProgressList(
                progress: _progress,
                taskCount: _taskCount,
              ),
            ],
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _saveReportFile,
              child: const Text('レポート保存'),
            ),
            const SizedBox(height: 16),
            for (final summary in _scanResults) ...[
              Text('Port scan for ${summary.host}'),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Port')),
                    DataColumn(label: Text('State')),
                    DataColumn(label: Text('Service')),
                  ],
                  rows: [
                    for (final r in summary.results)
                      DataRow(
                        color: WidgetStateProperty.all(
                          r.state == 'open'
                              ? ([23, 445].contains(r.port)
                                  ? Colors.redAccent
                                  : Colors.green)
                              : Colors.grey,
                        ),
                        cells: [
                          DataCell(Text(r.port.toString())),
                          DataCell(Text(r.state)),
                          DataCell(Text(r.service)),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_reports.isNotEmpty) ...[
              const Text('Scores'),
              SizedBox(height: 200, child: ScoreChart(reports: _reports)),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('IP')),
                    DataColumn(label: Text('Score')),
                    DataColumn(label: Text('Ports')),
                    DataColumn(label: Text('Country')),
                  ],
                  rows: [
                    for (final r in _reports)
                      DataRow(
                        color: WidgetStateProperty.all(
                          _scoreColor(r.score),
                        ),
                        cells: [
                          DataCell(Text(r.ip)),
                          DataCell(Text(r.score.toString())),
                          DataCell(Text(r.openPorts.join(','))),
                          DataCell(Text(r.geoip)),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final r in _reports) ...[
                        for (final risk in r.risks)
                          Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                '${_riskState(r.score)} → '
                                '${risk.description} → ${risk.countermeasure}',
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_devices.isNotEmpty) ...[
              const Text('LAN Devices'),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('IP')),
                    DataColumn(label: Text('MAC')),
                    DataColumn(label: Text('Vendor')),
                  ],
                  rows: [
                    for (final NetworkDevice d in _devices)
                      DataRow(cells: [
                        DataCell(Text(d.ip)),
                        DataCell(Text(d.mac)),
                        DataCell(Text(d.vendor)),
                      ]),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(_output),
                    if (_devices.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      DataTable(
                        columns: const [
                          DataColumn(label: Text('IP')),
                          DataColumn(label: Text('MAC')),
                          DataColumn(label: Text('Vendor')),
                        ],
                        rows: _devices
                            .map((NetworkDevice? d) => DataRow(cells: [
                                  DataCell(Text(d?.ip ?? '')),
                                  DataCell(Text(d?.mac ?? '')),
                                  DataCell(Text(d?.vendor ?? '')),
                                ]))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _scoreColor(int score) {
  if (score >= 8) return Colors.green;
  if (score >= 5) return Colors.orange;
  return Colors.redAccent;
}

String _riskState(int score) {
  if (score >= 8) return '安全';
  if (score >= 5) return '注意';
  return '危険';
}

class ScoreChart extends StatelessWidget {
  final List<SecurityReport> reports;
  const ScoreChart({super.key, required this.reports});

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty) return const SizedBox.shrink();
    final groups = <BarChartGroupData>[];
    for (var i = 0; i < reports.length; i++) {
      final r = reports[i];
      groups.add(
        BarChartGroupData(x: i, barRods: [
          BarChartRodData(toY: r.score.toDouble(), color: _scoreColor(r.score))
        ]),
      );
    }
    return BarChart(
      BarChartData(
        maxY: 10,
        barGroups: groups,
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx >= 0 && idx < reports.length) {
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(reports[idx].ip, style: const TextStyle(fontSize: 10)),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true, interval: 2),
          ),
        ),
      ),
    );
  }
}
