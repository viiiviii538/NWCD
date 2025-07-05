import 'dart:io';
import 'package:flutter/material.dart';

class DiagnosticItem {
  final String name;
  final String description;
  final String status;

  const DiagnosticItem({
    required this.name,
    required this.description,
    required this.status,
  });
}

class DiagnosticResultPage extends StatelessWidget {
  final int securityScore;
  final int riskScore;
  final List<DiagnosticItem> items;

  const DiagnosticResultPage({
    super.key,
    required this.securityScore,
    required this.riskScore,
    required this.items,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('診断結果')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Security Score: $securityScore',
              style: TextStyle(
                fontSize: 32,
                color: _scoreColor(securityScore),
              ),
            ),
            Text(_scoreMessage(securityScore)),
            const SizedBox(height: 16),
            Text(
              'Risk Score: $riskScore',
              style: TextStyle(
                fontSize: 32,
                color: _scoreColor(riskScore),
              ),
            ),
            Text(_scoreMessage(riskScore)),
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
              child: ElevatedButton(
                onPressed: () => _saveReport(context),
                child: const Text('レポート保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
