import 'dart:io';
import 'package:flutter/material.dart';
import 'package:nwc_densetsu/diagnostics.dart';
import 'package:nwc_densetsu/utils/report_utils.dart' as report_utils;
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
  final Future<String> Function()? onGenerateTopology;

  const DiagnosticResultPage({
    super.key,
    required this.securityScore,
    required this.riskScore,
    required this.items,
    this.onGenerateTopology,
  });

  Color _scoreColor(int score) {
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
              final minX = points.map((p) => p.dx).reduce((a, b) => a < b ? a : b);
              final maxX = points.map((p) => p.dx).reduce((a, b) => a > b ? a : b);
              final minY = points.map((p) => p.dy).reduce((a, b) => a < b ? a : b);
              final maxY = points.map((p) => p.dy).reduce((a, b) => a > b ? a : b);
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
      final generator = onGenerateTopology;
      final path = await (generator ?? report_utils.generateTopologyDiagram)();
      if (!context.mounted) return;

      final nodes = await _parseSvgNodes(path);
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
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
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
            ),
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
    );
  }
}

class ResultPage extends StatelessWidget {
  final List<SecurityReport> reports;
  final VoidCallback onSave;

  const ResultPage({super.key, required this.reports, required this.onSave});

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
                for (final r in reports)
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
