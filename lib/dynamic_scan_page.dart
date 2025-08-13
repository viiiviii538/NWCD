import 'dart:async';
import 'package:flutter/material.dart';
import 'dynamic_scan_service.dart';

/// Page that displays dynamic scan results.
class DynamicScanPage extends StatefulWidget {
  const DynamicScanPage({super.key});

  @override
  State<DynamicScanPage> createState() => _DynamicScanPageState();
}

class _DynamicScanPageState extends State<DynamicScanPage> {
  final DynamicScanService _service = DynamicScanService();
  List<DynamicScanResult> _results = [];
  bool _running = false;
  Timer? _timer;
  final Set<String> _alerted = <String>{};

  Future<void> _start() async {
    try {
      await _service.startScan();
      setState(() {
        _running = true;
        _results = [];
        _alerted.clear();
      });
      _timer = Timer.periodic(const Duration(seconds: 2), (_) async {
        final res = await _service.fetchResults();
        if (!mounted) return;
        setState(() => _results = res);
        _checkAlerts(res);
      });
    } catch (e) {
      _showError('開始失敗: $e');
    }
  }

  Future<void> _stop() async {
    try {
      await _service.stopScan();
      _timer?.cancel();
      setState(() => _running = false);
      _showMessage('スキャン停止');
    } catch (e) {
      _showError('停止失敗: $e');
    }
  }

  void _checkAlerts(List<DynamicScanResult> res) {
    for (final r in res) {
      if (!_alerted.contains(r.ip) && r.ports.isNotEmpty) {
        _alerted.add(r.ip);
        _showMessage('オープンポート検出: ${r.ip}');
      }
    }
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dynamic Scan')),
      body: Column(
        children: [
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _running ? null : _start,
                child: const Text('Start'),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: _running ? _stop : null,
                child: const Text('Stop'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [
                for (final r in _results)
                  ListTile(
                    title: Text(r.ip),
                    subtitle: Text(
                        'Ports: ${r.ports.map((p) => p['port']).join(', ')}'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
