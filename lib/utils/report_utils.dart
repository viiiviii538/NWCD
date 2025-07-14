import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../diagnostics.dart' show SecurityReport;
import '../extended_results.dart' show LanDeviceRisk;
import 'python_utils.dart';
import 'file_utils.dart';

/// Generates a PDF report from [reports] using the bundled Python script
/// and saves it to a location chosen by the user.
Future<void> savePdfReport(List<SecurityReport> reports) async {
  // Create temporary directory for intermediate files
  final tempDir = await Directory.systemTemp.createTemp('nwcd');
  try {
    final jsonPath = p.join(tempDir.path, 'devices.json');
    final jsonList = [
      for (final r in reports)
        {
          'ip': r.ip,
          'open_ports': r.openPorts,
          'countries': [if (r.geoip.isNotEmpty) r.geoip],
        },
    ];
    await File(jsonPath).writeAsString(jsonEncode(jsonList));

    final htmlPath = p.join(tempDir.path, 'report.html');
    final result = await Process.run('python', [
      'generate_html_report.py',
      jsonPath,
      '-o',
      htmlPath,
      '--pdf',
    ]);

    if (result.exitCode != 0) {
      throw Exception(result.stderr.toString());
    }

    final pdfPath = '${p.withoutExtension(htmlPath)}.pdf';
    final savePath = await getSavePath(suggestedName: 'report.pdf');
    if (savePath != null) {
      final pdfFile = File(pdfPath);
      if (await pdfFile.exists()) {
        await pdfFile.copy(savePath);
      }
    }
  } finally {
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {
      // ignore cleanup errors
    }
  }
}
/// Generates a network topology diagram from [devices].
///
/// The function creates a temporary JSON file compatible with
/// `generate_topology.py` and invokes the script. The returned path points
/// to the produced SVG file.
Future<String> generateTopologyDiagram([List<LanDeviceRisk> devices = const []])
    async {
  final tmpDir = await Directory.systemTemp.createTemp('nwcd_topology');
  final jsonPath = p.join(tmpDir.path, 'scan.json');
  final outputPath = p.join(tmpDir.path, 'topology.svg');

  final data = {
    'hosts': [
      for (final d in devices)
        {
          'ip': d.ip,
          if (d.vendor.isNotEmpty) 'vendor': d.vendor,
        }
    ]
  };
  await File(jsonPath).writeAsString(jsonEncode(data));

  final result = await Process.run(pythonExecutable, [
    'generate_topology.py',
    jsonPath,
    '-o',
    outputPath,
  ]);

  if (result.exitCode != 0) {
    throw Exception(result.stderr.toString());
  }

  return outputPath;
}

/// Saves [reports] to `history/YYYYMMDD_HHMM.json` and returns the file path.
Future<String> saveHistoryReports(List<SecurityReport> reports) async {
  final historyDir = Directory(p.join(Directory.current.path, 'history'));
  await historyDir.create(recursive: true);
  final now = DateTime.now();
  final stamp =
      '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
  final path = p.join(historyDir.path, '$stamp.json');
  final list = [
    for (final r in reports)
      {
        'ip': r.ip,
        'score': r.score,
        'utmItems': r.utmItems,
        'risks': [
          for (final risk in r.risks)
            {'description': risk.description, 'countermeasure': risk.countermeasure}
        ],
        'open_ports': r.openPorts,
        'geoip': r.geoip,
        'utmActive': r.utmActive,
      }
  ];
  await File(path).writeAsString(jsonEncode(list));
  return path;
}

/// Loads scan results from [path] previously saved with [saveHistoryReports].
List<SecurityReport> loadHistoryReports(String path) {
  final file = File(path);
  if (!file.existsSync()) return [];
  final data = jsonDecode(file.readAsStringSync());
  if (data is! List) return [];
  final reports = <SecurityReport>[];
  for (final item in data) {
    if (item is Map<String, dynamic>) {
      final risks = <RiskItem>[];
      if (item['risks'] is List) {
        for (final r in item['risks']) {
          if (r is Map) {
            risks.add(RiskItem(
              r['description']?.toString() ?? '',
              r['countermeasure']?.toString() ?? '',
            ));
          }
        }
      }
      reports.add(SecurityReport(
        item['ip']?.toString() ?? '',
        (item['score'] as num?)?.toDouble() ?? 0.0,
        risks,
        [for (final u in item['utmItems'] ?? []) u.toString()],
        '',
        openPorts: [for (final p in item['open_ports'] ?? []) int.tryParse(p.toString()) ?? 0],
        geoip: item['geoip']?.toString() ?? '',
        utmActive: item['utmActive'] == true,
      ));
    }
  }
  return reports;
}
