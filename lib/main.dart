import 'package:flutter/material.dart';
import 'package:nwc_densetsu/diagnostics.dart' as diag;
import 'package:nwc_densetsu/network_scan.dart' as net;
// The diagnostics and network_scan libraries are imported with aliases only.
// Avoid using `show`/`hide` so that all named parameters like `utmActive`
// remain available during development.
import 'package:fl_chart/fl_chart.dart';
import 'package:nwc_densetsu/utils/report_utils.dart' as report_utils;
import 'package:nwc_densetsu/progress_list.dart';
import 'package:nwc_densetsu/result_page.dart';
import 'package:nwc_densetsu/extended_results.dart';
import 'config.dart';

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
  List<diag.PortScanSummary> _scanResults = [];
  List<net.NetworkDevice> _devices = <net.NetworkDevice>[];
  List<diag.SecurityReport> _reports = [];
  final Map<String, diag.SslResult> _sslResults = {};
  final Map<String, String> _spfResults = {};
  diag.NetworkSpeed? _speed;
  bool _lanScanning = false;
  final Map<String, int> _progress = {};
  static const int _taskCount = 3; // port, SSL, SPF
  bool hasUtm = false;


  Future<void> _runLanScan() async {
    setState(() {
      _lanScanning = true;
      _devices = <net.NetworkDevice>[];
      _scanResults = [];
      _reports = [];
      _sslResults.clear();
      _spfResults.clear();
      _speed = null;
      _output = '診断中...\n';
      _progress.clear();
    });

    final speed = await diag.measureNetworkSpeed(onError: (msg) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('速度計測失敗: $msg')));
      }
    });
    setState(() => _speed = speed);
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

    for (final d in devices) {
      final ip = d.ip;
      buffer.writeln('--- $ip ---');
      final pingRes = await diag.runPing(ip);
      buffer.writeln(pingRes);

      final portFuture = diag
          .scanPorts(ip, onError: (msg) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('ポートスキャン失敗: $msg')));
        }
      }).then((value) {
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

      final summary = results[0] as diag.PortScanSummary;
      final sslRes = results[1] as diag.SslResult;
      final spfRes = results[2] as String;

      _scanResults.add(summary);
      _sslResults[ip] = sslRes;
      _spfResults[ip] = spfRes;
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
        utmActive: hasUtm,
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

  Future<void> _openResultPage() async {
    final version = await diag.getWindowsVersion(onError: (msg) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Windows情報取得失敗: $msg')));
      }
    });
    if (!mounted) return;
    final items = <DiagnosticItem>[];

    final sslChecks = <SslCheck>[];
    _sslResults.forEach((host, res) {
      final issuer =
          RegExp(r'issued by ([^,]+)').firstMatch(res.message)?.group(1) ?? '';
      final expiry =
          RegExp(r'expires on ([^,]+)').firstMatch(res.message)?.group(1) ?? '';
      sslChecks.add(SslCheck(
        domain: host,
        issuer: issuer,
        expiry: expiry,
        status: res.valid ? 'ok' : 'warning',
        comment: res.valid ? '' : 'invalid',
      ));
    });


    final domainAuths = <DomainAuthCheck>[];
    _spfResults.forEach((host, res) {
      final ok = res.startsWith('SPF record');
      domainAuths.add(DomainAuthCheck(
        domain: host,
        spf: ok,
        dkim: false,
        dmarc: false,
        status: ok ? 'ok' : 'warning',
        comment: ok ? '' : 'SPF missing',
      ));
    });

    final geoipStats = <GeoIpStat>[];
    final geoCount = <String, int>{};
    for (final r in _reports) {
      final c = r.geoip.toUpperCase();
      if (c.isEmpty) continue;
      geoCount[c] = (geoCount[c] ?? 0) + 1;
    }
    const danger = {'RU', 'CN', 'KP'};
    geoCount.forEach((c, cnt) {
      geoipStats.add(
        GeoIpStat(
            country: c, count: cnt, status: danger.contains(c) ? 'danger' : 'ok'),
      );
    });

    final lanDevices = <LanDeviceRisk>[];
    for (final dev in _devices) {
      final summary = _scanResults.firstWhere((s) => s.host == dev.ip,
          orElse: () => const diag.PortScanSummary('', []));
      final open = [for (final p in summary.results) if (p.state == 'open') p.port];
      lanDevices.add(LanDeviceRisk(
        ip: dev.ip,
        mac: dev.mac,
        vendor: dev.vendor,
        name: dev.vendor,
        status: open.isEmpty ? 'ok' : 'warning',
        comment: open.isEmpty ? '' : 'open: ${open.join(',')}',
      ));
    }

    final externalComms = <ExternalCommInfo>[
      const ExternalCommInfo(
        domain: 'example.com',
        protocol: 'HTTPS',
        encryption: '暗号化',
        status: 'ok',
        comment: '',
      ),
    ];

    final defenseStatus = <DefenseFeatureStatus>[];
    final features = <String>{};
    for (final r in _reports) {
      features.addAll(r.utmItems);
    }
    for (final f in features) {
      defenseStatus.add(DefenseFeatureStatus(
        feature: f,
        status: 'recommended',
        comment: '',
      ));
    }

    final avgScore = _reports.isNotEmpty
        ? _reports.map((r) => r.score).reduce((a, b) => a + b) / _reports.length
        : 0.0;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DiagnosticResultPage(
          securityScore: avgScore,
          items: items,
          portSummaries: _scanResults,
          sslChecks: sslChecks,
          domainAuths: domainAuths,
          geoipStats: geoipStats,
          lanDevices: lanDevices,
          externalComms: externalComms,
          defenseStatus: defenseStatus,
          windowsVersion: version ?? '',
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
                overallProgress: _progress.isEmpty
                    ? 1.0
                    : _progress.values.fold(0, (a, b) => a + b) /
                        (_progress.length * _taskCount),
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
            SwitchListTile(
              title: const Text('セキュリティ機器'),
              value: hasUtm,
              onChanged: (value) {
                setState(() {
                  hasUtm = value;
                });
              },
            ),
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
                          useColor
                              ? (r.state == 'open'
                                  ? ([23, 445].contains(r.port)
                                      ? Colors.redAccent
                                      : Colors.green)
                                  : Colors.grey)
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
                          useColor ? _scoreColor(r.score.toInt()) : Colors.grey,
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
                                '${_riskState(r.score.toInt())} → '
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
                    for (final net.NetworkDevice d in _devices)
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
                            .map((net.NetworkDevice? d) => DataRow(cells: [
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
  if (!useColor) return Colors.black;
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
  final List<diag.SecurityReport> reports;
  const ScoreChart({super.key, required this.reports});

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty) return const SizedBox.shrink();
    final groups = <BarChartGroupData>[];
    for (var i = 0; i < reports.length; i++) {
      final r = reports[i];
      groups.add(
        BarChartGroupData(x: i, barRods: [
          BarChartRodData(toY: r.score.toDouble(), color: _scoreColor(r.score.toInt()))
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
