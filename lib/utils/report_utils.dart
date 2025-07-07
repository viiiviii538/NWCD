import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../diagnostics.dart' show SecurityReport;
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

/// Generates a network topology SVG using the bundled Python script.
///
/// The diagram is created from the sample JSON data included with the
/// application and returned as a path to the generated file.
Future<String> generateTopologyDiagram() async {
  final tempDir = await Directory.systemTemp.createTemp('nwcd_topo');
  final outputPath = p.join(tempDir.path, 'topology.svg');
  final result = await Process.run('python', [
    'generate_topology.py',
    'sample_devices.json',
    '-o',
    outputPath,
  ]);
  if (result.exitCode != 0) {
    throw Exception(result.stderr.toString());
  }
  return outputPath;
}
