import 'dart:io';
import 'package:flutter/material.dart';
import 'config.dart';
import 'package:nwc_densetsu/diagnostics.dart';
import 'package:nwc_densetsu/utils/report_utils.dart' as report_utils;
import 'extended_results.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:xml/xml.dart' as xml;

class _SvgNode {
  final String label;
  final Rect rect;
  _SvgNode(this.label, this.rect);
}

class DiagnosticItem {
  final String name;
  final String description;
  final String status;
  final String action;

  const DiagnosticItem({
    required this.name,
    required this.description,
    required this.status,
    required this.action,
  });
}

class DiagnosticResultPage extends StatelessWidget {
  final double securityScore;
  final List<PortScanSummary> portSummaries;
  final List<DiagnosticItem> items;
  final Future<String> Function()? onGenerateTopology;
  final List<SslCheck> sslChecks;
  final List<SpfCheck> spfChecks;
  final List<DomainAuthCheck> domainAuths;
  final List<GeoIpStat> geoipStats;
  final List<LanDeviceRisk> lanDevices;
  final List<ExternalCommInfo> externalComms;
  final List<DefenseFeatureStatus> defenseStatus;
  final String windowsVersion;

  const DiagnosticResultPage({
    super.key,
    required this.securityScore,
    required this.items,
    required this.portSummaries,
    this.onGenerateTopology,
    this.sslChecks = const [],
    this.spfChecks = const [],
    this.domainAuths = const [],
    this.geoipStats = const [],
    this.lanDevices = const [],
    this.externalComms = const [],
    this.defenseStatus = const [],
    this.windowsVersion = '',
  });

  Color _scoreColor(int score) {
    if (!useColor) return Colors.black;
    if (score >= 8) return Colors.green;
    if (score >= 5) return Colors.orange;
    return Colors.redAccent;
  }

  String _scoreMessage(int score) {
    if (score >= 8) return '社内ネットワークは安全です';
    if (score >= 5) return '注意が必要です';
    return '危険な状態です';
  }

  Widget _scoreSection(String label, int score) {
    final color = _scoreColor(score);
    IconData icon;
    if (score >= 8) {
      icon = Icons.check_circle;
    } else if (score >= 5) {
      icon = Icons.warning;
    } else {
      icon = Icons.error;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            // ignore: deprecated_member_use
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(width: 8),
              Text(
                score.toString(),
                style: TextStyle(fontSize: 48, color: color),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(_scoreMessage(score)),
      ],
    );
  }

  Future<List<_SvgNode>> _parseSvgNodes(String path) async {
    final svgStr = await File(path).readAsString();
    final document = xml.XmlDocument.parse(svgStr);
    final nodes = <_SvgNode>[];
    for (final g in document.findAllElements('g')) {
      if (g.getAttribute('class') == 'node') {
        final title = g.getElement('title')?.innerText ?? '';
        final ellipse = g.getElement('ellipse');
        if (ellipse != null) {
          final cx = double.tryParse(ellipse.getAttribute('cx') ?? '');
          final cy = double.tryParse(ellipse.getAttribute('cy') ?? '');
          final rx = double.tryParse(ellipse.getAttribute('rx') ?? '');
          final ry = double.tryParse(ellipse.getAttribute('ry') ?? '');
          if (cx != null && cy != null && rx != null && ry != null) {
            nodes.add(
              _SvgNode(
                title,
                Rect.fromCenter(
                    center: Offset(cx, cy), width: rx * 2, height: ry * 2),
              ),
            );
          }
        } else {
          final polygon = g.getElement('polygon');
          final pointsStr = polygon?.getAttribute('points');
          if (pointsStr != null && pointsStr.isNotEmpty) {
            final points = pointsStr
                .trim()
                .split(RegExp(r'\s+'))
                .map((p) => p.split(','))
                .where((pair) => pair.length == 2)
                .map((pair) => Offset(
                      double.tryParse(pair[0]) ?? 0,
                      double.tryParse(pair[1]) ?? 0,
                    ))
                .toList();
            if (points.isNotEmpty) {
              final minX =
                  points.map((p) => p.dx).reduce((a, b) => a < b ? a : b);
              final maxX =
                  points.map((p) => p.dx).reduce((a, b) => a > b ? a : b);
              final minY =
                  points.map((p) => p.dy).reduce((a, b) => a < b ? a : b);
              final maxY =
                  points.map((p) => p.dy).reduce((a, b) => a > b ? a : b);
              nodes.add(
                _SvgNode(
                  title,
                  Rect.fromLTRB(minX, minY, maxX, maxY),
                ),
              );
            }
          }
        }
      }
    }
    return nodes;
  }

  Widget _portSection() {
    if (portSummaries.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ポート開放状況'),
        const SizedBox(height: 4),
        for (final s in portSummaries)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.host),
              DataTable(columns: const [
                DataColumn(label: Text('Port')),
                DataColumn(label: Text('State')),
                DataColumn(label: Text('Service')),
              ], rows: [
                for (final p in s.results)
                  DataRow(cells: [
                    DataCell(Text(p.port.toString())),
                    DataCell(Text(p.state)),
                    DataCell(Text(p.service)),
                  ]),
              ]),
            ],
          ),
      ],
    );
  }

  Widget _sslSection() {
    if (sslChecks.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('SSL証明書の安全性チェック'),
        const SizedBox(height: 4),
        DataTable(columns: const [
          DataColumn(label: Text('ドメイン')),
          DataColumn(label: Text('発行者')),
          DataColumn(label: Text('有効期限')),
          DataColumn(label: Text('状態')),
          DataColumn(label: Text('コメント')),
        ], rows: [
          for (final c in sslChecks)
            DataRow(cells: [
              DataCell(Text(c.domain)),
              DataCell(Text(c.issuer)),
              DataCell(Text(c.expiry)),
              DataCell(Text(c.status)),
              DataCell(Text(c.comment)),
            ]),
        ]),
      ],
    );
  }

  Widget _spfSection() {
    if (spfChecks.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('SPFレコードの設定状況'),
        const SizedBox(height: 4),
        DataTable(columns: const [
          DataColumn(label: Text('ドメイン')),
          DataColumn(label: Text('SPF')),
          DataColumn(label: Text('状態')),
          DataColumn(label: Text('コメント')),
        ], rows: [
          for (final c in spfChecks)
            DataRow(cells: [
              DataCell(Text(c.domain)),
              DataCell(Text(c.spf)),
              DataCell(Text(c.status)),
              DataCell(Text(c.comment)),
            ]),
        ]),
      ],
    );
  }

  Widget _domainAuthSection() {
    if (domainAuths.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ドメインの送信元検証設定'),
        const SizedBox(height: 4),
        DataTable(columns: const [
          DataColumn(label: Text('ドメイン')),
          DataColumn(label: Text('SPF')),
          DataColumn(label: Text('DKIM')),
          DataColumn(label: Text('DMARC')),
          DataColumn(label: Text('状態')),
          DataColumn(label: Text('コメント')),
        ], rows: [
          for (final c in domainAuths)
            DataRow(cells: [
              DataCell(Text(c.domain)),
              DataCell(Text(c.spf ? '✅' : '❌')),
              DataCell(Text(c.dkim ? '✅' : '❌')),
              DataCell(Text(c.dmarc ? '✅' : '❌')),
              DataCell(Text(c.status)),
              DataCell(Text(c.comment)),
            ]),
        ]),
      ],
    );
  }

  Widget _geoipSection() {
    if (geoipStats.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('GeoIP解析：通信先の国別リスクチェック'),
        const SizedBox(height: 4),
        DataTable(columns: const [
          DataColumn(label: Text('国名')),
          DataColumn(label: Text('通信数')),
          DataColumn(label: Text('状態')),
        ], rows: [
          for (final g in geoipStats)
            DataRow(cells: [
              DataCell(Text(g.country)),
              DataCell(Text(g.count.toString())),
              DataCell(Text(g.status)),
            ]),
        ]),
      ],
    );
  }

  Widget _lanSection() {
    if (lanDevices.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('LAN内デバイス一覧とリスクチェック'),
        const SizedBox(height: 4),
        DataTable(columns: const [
          DataColumn(label: Text('IPアドレス')),
          DataColumn(label: Text('MACアドレス')),
          DataColumn(label: Text('ベンダー名')),
          DataColumn(label: Text('機器名')),
          DataColumn(label: Text('状態')),
          DataColumn(label: Text('コメント')),
        ], rows: [
          for (final d in lanDevices)
            DataRow(cells: [
              DataCell(Text(d.ip)),
              DataCell(Text(d.mac)),
              DataCell(Text(d.vendor)),
              DataCell(Text(d.name)),
              DataCell(Text(d.status)),
              DataCell(Text(d.comment)),
            ]),
        ]),
      ],
    );
  }

  Widget _externalCommSection() {
    if (externalComms.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('外部通信の暗号化状況'),
        const SizedBox(height: 4),
        DataTable(columns: const [
          DataColumn(label: Text('宛先ドメイン')),
          DataColumn(label: Text('通信プロトコル')),
          DataColumn(label: Text('暗号化状況')),
          DataColumn(label: Text('状態')),
          DataColumn(label: Text('コメント')),
        ], rows: [
          for (final c in externalComms)
            DataRow(cells: [
              DataCell(Text(c.domain)),
              DataCell(Text(c.protocol)),
              DataCell(Text(c.encryption)),
              DataCell(Text(c.status)),
              DataCell(Text(c.comment)),
            ]),
        ]),
      ],
    );
  }

  Widget _defenseSection() {
    if (defenseStatus.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('端末の防御機能の有効性チェック'),
        const SizedBox(height: 4),
        DataTable(columns: const [
          DataColumn(label: Text('保護機能')),
          DataColumn(label: Text('状態')),
          DataColumn(label: Text('コメント')),
        ], rows: [
          for (final d in defenseStatus)
            DataRow(cells: [
              DataCell(Text(d.feature)),
              DataCell(Text(d.status)),
              DataCell(Text(d.comment)),
            ]),
        ]),
      ],
    );
  }

  Widget _windowsVersionSection() {
    if (windowsVersion.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Windows バージョン'),
        const SizedBox(height: 4),
        Text(windowsVersion),
      ],
    );
  }

  Future<void> _saveReport(BuildContext context) async {
    try {
      final result = await Process.run(
        'python',
        ['generate_html_report.py', 'sample_devices.json', '--pdf'],
      );
      final out = result.stdout.toString();
      final match = RegExp(r'PDF written to (.+\.pdf)').firstMatch(out);
      final path = match?.group(1) ?? 'scan_report.pdf';
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('PDF 保存: $path')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('生成失敗: $e')));
      }
    }
  }

  Future<void> _showTopology(BuildContext context) async {
    try {
      final generator =
          onGenerateTopology ?? () => report_utils.generateTopologyDiagram(lanDevices);
      final path = await generator();
      if (!context.mounted) return;

      final nodes = await _parseSvgNodes(path);
      final controller = TransformationController();

      await showDialog(
        // ignore: use_build_context_synchronously
        context: context,
        builder: (_) => Dialog(
          child: SizedBox(
            width: 400,
            height: 400,
            child: GestureDetector(
              onTapUp: (details) {
                final scenePoint = controller.toScene(details.localPosition);
                for (final node in nodes) {
                  if (node.rect.contains(scenePoint)) {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(content: Text(node.label)),
                    );
                    break;
                  }
                }
              },
              child: InteractiveViewer(
                transformationController: controller,
                child: Stack(
                  children: [
                    SvgPicture.file(File(path)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('生成失敗: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('診断結果')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _scoreSection('セキュリティスコア', securityScore.toInt()),
              const SizedBox(height: 16),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(item.description),
                          const SizedBox(height: 4),
                          Text('現状: ${item.status}'),
                          const SizedBox(height: 4),
                          Text('推奨対策: ${item.action}'),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              _portSection(),
              const SizedBox(height: 16),
              _sslSection(),
              const SizedBox(height: 16),
              _spfSection(),
              const SizedBox(height: 16),
              _domainAuthSection(),
              const SizedBox(height: 16),
              _geoipSection(),
              const SizedBox(height: 16),
              _lanSection(),
              const SizedBox(height: 16),
              _externalCommSection(),
              const SizedBox(height: 16),
              _defenseSection(),
              const SizedBox(height: 16),
              _windowsVersionSection(),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.center,
                child: Column(
                  children: [
                    ElevatedButton(
                      onPressed: () => _saveReport(context),
                      child: const Text('レポート保存'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => _showTopology(context),
                      child: const Text('トポロジ表示'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ResultPage extends StatelessWidget {
  final List<SecurityReport> reports;
  final VoidCallback onSave;

  const ResultPage({super.key, required this.reports, required this.onSave});

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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Scores'),
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
              for (final r in reports)
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
                for (final r in reports)
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
            ),
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.center,
          child: ElevatedButton(
            onPressed: onSave,
            child: const Text('レポート保存'),
          ),
        ),
      ],
    );
  }
}
