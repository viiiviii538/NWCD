import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

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
        itemCount: _files.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  DefaultTabController.of(context).animateTo(0);
                },
                icon: const Icon(Icons.arrow_back),
                label: const Text('ホームに戻る'),
              ),
            );
          }
          final f = _files[index - 1];
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
