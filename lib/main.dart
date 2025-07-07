import 'package:flutter/material.dart';
import 'package:nwc_densetsu/diagnostics.dart' as diag;
import 'package:nwc_densetsu/diagnostics.dart'
    show PortScanSummary, SecurityReport, SslResult, SpfResult;
import 'package:nwc_densetsu/network_scan.dart' as net;
import 'package:nwc_densetsu/network_scan.dart'
    show NetworkDevice;
import 'package:fl_chart/fl_chart.dart';
import 'package:nwc_densetsu/utils/report_utils.dart' as report_utils;
import 'package:nwc_densetsu/progress_list.dart';
import 'package:nwc_densetsu/result_page.dart';
import 'package:nwc_densetsu/port_constants.dart';
import 'package:nwc_densetsu/device_list_page.dart';

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
  List<SpfResult> _spfResults = [];
  diag.NetworkSpeed? _speed;
  diag.DefenseStatus? _defense;
  bool _lanScanning = false;
  String _portPreset = 'default';
  final Map<String, int> _progress = {};
  static const int _taskCount = 5; // port, SSL, SPF, DKIM, DMARC
  double _overallProgress = 0.0;

  void _openGeoipPage() {
    final entries = [
      GeoipEntry('93.184.216.34', 'example.com', 'US'),
      GeoipEntry('203.0.113.1', 'mal.example', 'CN'),
      GeoipEntry('198.51.100.2', '', 'RU'),
    ];
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GeoipResultPage(entries: entries)),
    );
  }

  List<int> get _selectedPorts {
    switch (_portPreset) {
      case 'quick':
        return quickPorts;
      case 'full':
        return fullPorts;
      default:
        return defaultPortList;
    }
  }


  Future<void> _runLanScan() async {
    setState(() {
      _lanScanning = true;
      _devices = <NetworkDevice>[];
      _scanResults = [];
      _reports = [];
      _spfResults = [];
      _speed = null;
      _output = '診断中...\n';
      _progress.clear();
      _overallProgress = 0.0;
    });

    final speed = await diag.measureNetworkSpeed();
    setState(() => _speed = speed);
    final defense = await diag.checkDefenseStatus();
    setState(() => _defense = defense);
    final buffer = StringBuffer();
    if (speed != null) {
      buffer.writeln('--- Network Speed ---');
      buffer.writeln(
          'Download: ${speed.downloadMbps.toStringAsFixed(1)} Mbps');
      buffer.writeln(
          'Upload: ${speed.uploadMbps.toStringAsFixed(1)} Mbps');
      buffer.writeln('Ping: ${speed.pingMs.toStringAsFixed(1)} ms');
      buffer.writeln();
    } else {
      buffer.writeln('Network speed test failed');
      buffer.writeln();
    }

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
    final totalTasks = devices.length * _taskCount;
    var completedTasks = 0;

    for (final d in devices) {
      final ip = d.ip;
      buffer.writeln('--- $ip ---');
      final pingRes = await diag.runPing(ip);
      buffer.writeln(pingRes);

      final portFuture = diag.scanPorts(ip, _selectedPorts).then((value) {
        setState(() {
          _progress[ip] = (_progress[ip] ?? 0) + 1;
          completedTasks++;
          _overallProgress =
              totalTasks > 0 ? completedTasks / totalTasks : 1.0;
        });
        return value;
      });
      final sslFuture = diag.checkSslCertificate(ip).then((value) {
        setState(() {
          _progress[ip] = (_progress[ip] ?? 0) + 1;
          completedTasks++;
          _overallProgress =
              totalTasks > 0 ? completedTasks / totalTasks : 1.0;
        });
        return value;
      });
      final spfFuture = diag
          .checkSpfRecord(d.name.isNotEmpty ? d.name : ip)
          .then((value) {
        setState(() {
          _progress[ip] = (_progress[ip] ?? 0) + 1;
          completedTasks++;
          _overallProgress =
              totalTasks > 0 ? completedTasks / totalTasks : 1.0;
        });
        return value;
      });
      final dkimFuture = diag.checkDkimRecord(ip).then((value) {
        setState(() {
          _progress[ip] = (_progress[ip] ?? 0) + 1;
          completedTasks++;
          _overallProgress =
              totalTasks > 0 ? completedTasks / totalTasks : 1.0;
        });
        return value;
      });
      final dmarcFuture = diag.checkDmarcRecord(ip).then((value) {
        setState(() {
          _progress[ip] = (_progress[ip] ?? 0) + 1;
          completedTasks++;
          _overallProgress =
              totalTasks > 0 ? completedTasks / totalTasks : 1.0;
        });
        return value;
      });

      final results = await Future.wait([portFuture, sslFuture, spfFuture, dkimFuture, dmarcFuture]);

      final summary = results[0] as PortScanSummary;
      final sslRes = results[1] as SslResult;
      final spfRes = results[2] as SpfResult;
      final dkimValid = results[3] as bool;
      final dmarcValid = results[4] as bool;
      final spfResWithOthers = SpfResult(
        spfRes.domain,
        spfRes.record,
        spfRes.status,
        spfRes.comment,
        dkimValid: dkimValid,
        dmarcValid: dmarcValid,
      );

      _scanResults.add(summary);
      _spfResults.add(spfResWithOthers);
      for (final r in summary.results) {
        buffer.writeln('Port ${r.port}: ${r.state} ${r.service}');
      }

      buffer.writeln(sslRes.message);
      if (spfRes.record.isNotEmpty) {
        buffer.writeln('SPF record: ${spfRes.record}');
      } else {
        buffer.writeln(spfRes.comment);
      }
      buffer.writeln('DKIM: ${dkimValid ? 'valid' : 'missing'}');
      buffer.writeln('DMARC: ${dmarcValid ? 'valid' : 'missing'}');

      final report = await diag.runSecurityReport(
        ip: ip,
        openPorts: [
          for (final r in summary.results)
            if (r.state == 'open') r.port
        ],
        sslValid: sslRes.valid,
        spfValid: spfRes.status == 'safe',
        dkimValid: dkimValid,
        dmarcValid: dmarcValid,
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
      _overallProgress = 1.0;
    });
  }


  Future<void> _saveReportFile() async {
    try {
      await report_utils.savePdfReport(_reports);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('保存完了')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('保存失敗: $e')));
      }
    }
  }

  List<DiagnosticItem> _buildDiagnosticItems() {
    final items = <DiagnosticItem>[];

    if (_speed != null) {
      final s = _speed!;
      items.add(DiagnosticItem(
        name: 'ネットワーク速度',
        description:
            'Down ${s.downloadMbps.toStringAsFixed(1)} Mbps '
            'Up ${s.uploadMbps.toStringAsFixed(1)} Mbps '
            'Ping ${s.pingMs.toStringAsFixed(1)} ms',
        status: 'info',
        action: '',
      ));
    }

    for (final report in _reports) {
      final level = report.score >= 8
          ? 'danger'
          : report.score >= 5
              ? 'warning'
              : 'safe';
      for (final r in report.risks) {
        items.add(DiagnosticItem(
          name: 'ホスト ${report.ip}',
          description: r.description,
          status: level,
          action: r.countermeasure,
        ));
      }
    }
    return items;
  }

  void _openResultPage() {
    final items = _buildDiagnosticItems();
    final risk = _reports.isNotEmpty
        ? _reports.map((e) => e.score).reduce((a, b) => a + b) /
            _reports.length
        : 0.0;
    final securityScore = (10 - risk).round();
    final riskScore = risk.round();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DiagnosticResultPage(
          securityScore: securityScore,
          riskScore: riskScore,
          items: items,
          portSummaries: _scanResults,
          spfResults: _spfResults,
          defenderEnabled: _defense?.defenderEnabled,
          firewallEnabled: _defense?.firewallEnabled,
        ),
      ),
    );
  }

  void _openDeviceListPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DeviceListPage(
          devices: _devices,
          reports: _reports,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NWCD')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButton<String>(
              value: _portPreset,
              onChanged: (val) {
                if (val != null) {
                  setState(() => _portPreset = val);
                }
              },
              items: const [
                DropdownMenuItem(value: 'default', child: Text('Default')),
                DropdownMenuItem(value: 'quick', child: Text('Quick')),
                DropdownMenuItem(value: 'full', child: Text('Full')),
              ],
            ),
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
                overallProgress: _overallProgress,
              ),
            ],
            if (_speed != null) ...[
              const SizedBox(height: 8),
              Text(
                'Speed: '
                'Down ${_speed!.downloadMbps.toStringAsFixed(1)} Mbps '
                'Up ${_speed!.uploadMbps.toStringAsFixed(1)} Mbps '
                'Ping ${_speed!.pingMs.toStringAsFixed(1)} ms',
              ),
            ],
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _saveReportFile,
              child: const Text('レポート保存'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _openResultPage,
              child: const Text('診断結果ページ'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _devices.isEmpty && _reports.isEmpty
                  ? null
                  : _openDeviceListPage,
              child: const Text('LAN内デバイス一覧'),
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
                        color: MaterialStateProperty.all(
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
                        color: MaterialStateProperty.all(
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
            if (_spfResults.isNotEmpty) ...[
              const Text('SPFレコードの設定状況',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('メール送信ドメインのなりすまし防止のため、SPFレコードの有無を確認します。'),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('ドメイン')),
                    DataColumn(label: Text('SPFレコード')),
                    DataColumn(label: Text('DKIM')),
                    DataColumn(label: Text('DMARC')),
                    DataColumn(label: Text('状態')),
                    DataColumn(label: Text('コメント')),
                  ],
                  rows: [
                    for (final r in _spfResults)
                      DataRow(
                        color: MaterialStateProperty.all(
                          r.status == 'danger'
                              ? Colors.redAccent.withOpacity(0.2)
                              : r.status == 'warning'
                                  ? Colors.yellowAccent.withOpacity(0.2)
                                  : Colors.green.withOpacity(0.2),
                        ),
                        cells: [
                          DataCell(Text(r.domain)),
                          DataCell(Text(r.record)),
                          DataCell(Text(r.dkimValid ? 'OK' : 'NG')),
                          DataCell(Text(r.dmarcValid ? 'OK' : 'NG')),
                          DataCell(Text(r.status)),
                          DataCell(Text(r.comment)),
                        ],
                      ),
                  ],
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
