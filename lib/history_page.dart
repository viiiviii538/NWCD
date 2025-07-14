import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

// Import using the package URI to ensure the same library instance is used
// across the project.
import 'package:nwc_densetsu/diagnostics.dart';
import 'utils/report_utils.dart' as report_utils;
import 'result_page.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<FileSystemEntity> _files = [];

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    final dir = Directory(p.join(Directory.current.path, 'history'));
    if (await dir.exists()) {
      final list = await dir
          .list()
          .where((e) => e.path.endsWith('.json'))
          .toList();
      list.sort((a, b) => b.path.compareTo(a.path));
      setState(() => _files = list);
    } else {
      setState(() => _files = []);
    }
  }

  Future<void> _openFile(String path) async {
    final reports = report_utils.loadHistoryReports(path);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResultPage(
          reports: reports,
          onSave: () async {
            await report_utils.savePdfReport(reports);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadFiles,
      child: ListView.builder(
        itemCount: _files.length,
        itemBuilder: (context, index) {
          final f = _files[index];
          final name = p.basename(f.path);
          return ListTile(
            title: Text(name),
            onTap: () => _openFile(f.path),
          );
        },
      ),
    );
  }
}
