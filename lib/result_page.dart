import 'dart:io';
import 'package:flutter/material.dart';
import 'config.dart';
import 'package:nwc_densetsu/diagnostics.dart';
import 'package:nwc_densetsu/ssl_check_section.dart';
import 'package:nwc_densetsu/device_list_page.dart';
import 'package:nwc_densetsu/network_scan.dart' show NetworkDevice;
import 'package:nwc_densetsu/utils/report_utils.dart'
    show generateTopologyDiagram;
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
  final int securityScore;
  final int riskScore;
  final List<DiagnosticItem> items;
  final List<SslCheckEntry> sslEntries;
  final List<PortScanSummary> portSummaries;
  final List<SpfResult> spfResults;
  final List<ExternalCommEntry> externalComms;
  final List<NetworkDevice> devices;
  final List<SecurityReport> reports;
  final bool? defenderEnabled;
  final bool? firewallEnabled;
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
    this.sslEntries = const [],
    this.portSummaries = const [],
    this.spfResults = const [],
    this.externalComms = const [],
    this.devices = const [],
    this.reports = const [],
    this.defenderEnabled,
    this.firewallEnabled,
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

  String _statusText(String status) {
    switch (status) {
      case 'safe':
        return '安全';
      case 'warning':
        return '注意';
      case 'danger':
        return '危険';
      default:
        return status;
    }
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
        const Text(
          '特定のポートが開いていると、攻撃対象となる範囲が広がり、不正アクセスやマルウェア侵入の経路になる恐れがあります。',
        ),
        const SizedBox(height: 8),
        for (final s in portSummaries) ...[
          Text(s.host, style: const TextStyle(fontWeight: FontWeight.bold)),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('ポート')),
                DataColumn(label: Text('状態')),
                DataColumn(label: Text('補足')),
              ],
              rows: [
                for (final r in s.results)
                  DataRow(
                    color: MaterialStateProperty.all(
                      r.state == 'open' && _dangerPortNotes.containsKey(r.port)
                          ? Colors.redAccent.withOpacity(0.2)
                          : r.state == 'open'
                              ? Colors.green.withOpacity(0.2)
                              : Colors.grey.withOpacity(0.2),
                    ),
                    cells: [
                      DataCell(Text(r.port.toString())),
                      DataCell(Text(
                        r.state == 'open'
                            ? (_dangerPortNotes.containsKey(r.port)
                                ? '危険（開いている）'
                                : '安全（開いている）')
                            : '安全（閉じている）',
                      )),
                      DataCell(
                        _dangerPortNotes[r.port] != null
                            ? Text(_dangerPortNotes[r.port]!)
                            : const Text('-'),
                      ),
                    ],
                  ),
              ],
            ),
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

  Color _deviceScoreColor(int score) {
    if (score >= 8) return Colors.redAccent;
    if (score >= 5) return Colors.orange;
    return Colors.green;
  }

  String _deviceRiskState(int score) {
    if (score >= 8) return '危険';
    if (score >= 5) return '注意';
    return '安全';
  }

  Widget _lanDevicesSection(BuildContext context) {
    if (devices.isEmpty) return const SizedBox.shrink();
    final rows = <DataRow>[];
    for (final d in devices) {
      final rep = reports.firstWhere((r) => r.ip == d.ip,
          orElse: () => const SecurityReport('', 0, [], [], '',
              openPorts: [], geoip: ''));
      rows.add(
        DataRow(
          color: MaterialStateProperty.all(
            _deviceScoreColor(rep.score).withOpacity(0.2),
          ),
          cells: [
            DataCell(Text(d.ip)),
            DataCell(Text(d.mac)),
            DataCell(Text(d.vendor)),
            DataCell(Text(d.name)),
            DataCell(Text(_deviceRiskState(rep.score))),
            DataCell(Text(rep.risks.isNotEmpty ? rep.risks.first.description : '')),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('LAN内デバイス一覧',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SingleChildScrollView(
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
      ],
    );
  }

  Widget _senderAuthSection() {
    if (spfResults.isEmpty) return const SizedBox.shrink();

    String _rowState(SpfResult r) {
      var missing = 0;
      if (r.record.isEmpty) missing++;
      if (!r.dkimValid) missing++;
      if (!r.dmarcValid) missing++;
      if (missing == 0) return '安全';
      if (missing == 1) return '注意';
      return '危険';
    }

    String _rowComment(SpfResult r) {
      final missing = <String>[];
      if (r.record.isEmpty) missing.add('SPF');
      if (!r.dkimValid) missing.add('DKIM');
      if (!r.dmarcValid) missing.add('DMARC');
      if (missing.isEmpty) {
        return 'すべての認証が適切に設定されています';
      }
      final joined = missing.join('・');
      return missing.length >= 2
          ? '$joinedが未設定で、なりすましリスク大'
          : '$joinedが未設定のため、不正メールを防ぎにくい';
    }

    Color _rowColor(String state) {
      switch (state) {
        case '危険':
          return Colors.redAccent.withOpacity(0.2);
        case '注意':
          return Colors.yellowAccent.withOpacity(0.2);
        default:
          return Colors.green.withOpacity(0.2);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ドメインの送信元検証設定',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text(
            'SPF・DKIM・DMARCは、送信元のドメインが正当であることを検証する仕組みです。いずれかが欠けている場合、なりすましメールのリスクが高まり、フィッシングやマルウェア(迷惑メール)の原因になります。'),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('ドメイン')),
              DataColumn(label: Text('SPF')),
              DataColumn(label: Text('DKIM')),
              DataColumn(label: Text('DMARC')),
              DataColumn(label: Text('状態')),
              DataColumn(label: Text('コメント')),
            ],
            rows: [
              for (final r in spfResults)
                () {
                  final state = _rowState(r);
                  final comment = _rowComment(r);
                  return DataRow(
                    color: MaterialStateProperty.all(_rowColor(state)),
                    cells: [
                      DataCell(Text(r.domain)),
                      DataCell(Text(r.record.isNotEmpty ? '〇' : '×')),
                      DataCell(Text(r.dkimValid ? '〇' : '×')),
                      DataCell(Text(r.dmarcValid ? '〇' : '×')),
                      DataCell(Text(state)),
                      DataCell(Text(comment)),
                    ],
                  );
                }(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _externalCommSection() {
    if (externalComms.isEmpty) return const SizedBox.shrink();
    Color rowColor(String state) {
      switch (state) {
        case '危険':
          return Colors.redAccent.withOpacity(0.2);
        case '安全':
          return Colors.green.withOpacity(0.2);
        default:
          return Colors.grey.withOpacity(0.2);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('外部通信の暗号化状況',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('宛先')),
              DataColumn(label: Text('プロトコル')),
              DataColumn(label: Text('暗号化')),
              DataColumn(label: Text('状態')),
              DataColumn(label: Text('コメント')),
            ],
            rows: [
              for (final e in externalComms)
                DataRow(
                  color: MaterialStateProperty.all(rowColor(e.state)),
                  cells: [
                    DataCell(Text(e.dest)),
                    DataCell(Text(e.protocol)),
                    DataCell(Text(e.encryption)),
                    DataCell(Text(e.state)),
                    DataCell(Text(e.comment)),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _defenseSection() {
    if (defenderEnabled == null && firewallEnabled == null) {
      return const SizedBox.shrink();
    }
    DataRow row(String name, bool? enabled, String comment) {
      Color? color;
      TextStyle? style;
      String state;
      if (enabled == null) {
        state = '不明';
      } else if (enabled) {
        state = '有効';
        color = Colors.green.withOpacity(0.2);
        style = const TextStyle(color: Colors.green);
      } else {
        state = '無効';
        color = Colors.redAccent.withOpacity(0.2);
        style = const TextStyle(color: Colors.red, fontWeight: FontWeight.bold);
      }
      return DataRow(
        color: color != null ? MaterialStateProperty.all(color) : null,
        cells: [
          DataCell(Text(name)),
          DataCell(Text(state, style: style)),
          DataCell(Text(comment)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('端末の防御機能の有効性チェック',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text(
            'リアルタイム保護やファイアウォールが無効な状態では、マルウェア感染や外部からの侵入を防ぐことができず、端末が極めて無防備になります。基本的なセキュリティ機能が適切に動作しているかを確認してください。'),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('保護機能名')),
              DataColumn(label: Text('状態')),
              DataColumn(label: Text('コメント')),
            ],
            rows: [
              row(
                'リアルタイム保護（Defender）',
                defenderEnabled,
                'ウイルスやマルウェアを常時監視し、感染を未然に防ぎます。無効化すると新たな脅威を検知できません。',
              ),
              row(
                '外部アクセス遮断（Firewall）',
                firewallEnabled,
                '不正アクセスをブロックします。無効にすると外部からの侵入に対して無防備になります。',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _spfSection() {
    if (spfResults.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('SPFレコードの設定状況',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text(
            'SPFレコードは、なりすましメールを防止する仕組みです。設定されていないドメインは、フィッシング詐欺やマルウェア拡散の踏み台として悪用される可能性があります。'),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('ドメイン')),
              DataColumn(label: Text('SPFレコード有無')),
              DataColumn(label: Text('状態')),
              DataColumn(label: Text('コメント')),
            ],
            rows: [
              for (final r in spfResults)
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
                    DataCell(Text(r.record.isNotEmpty ? 'あり' : 'なし')),
                    DataCell(Text(_statusText(r.status))),
                    DataCell(Text(r.comment)),
                  ],
                ),
            ],
          ),
        ),
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
      if (!context.mounted) return;
      final controller = TransformationController();

      await showDialog(
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
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _scoreSection('セキュリティスコア', securityScore),
            const SizedBox(height: 16),
          _scoreSection('リスクスコア', riskScore),
          const SizedBox(height: 16),
          if (sslEntries.isNotEmpty) ...[
            SslCheckSection(results: sslEntries),
            const SizedBox(height: 16),
          ],
          _portStatusSection(),
          const SizedBox(height: 16),
          _lanDevicesSection(context),
          const SizedBox(height: 16),
          _senderAuthSection(),
          const SizedBox(height: 16),
          _externalCommSection(),
          const SizedBox(height: 16),
          _defenseSection(),
          const SizedBox(height: 16),
          Expanded(
              child: ListView.builder(
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
