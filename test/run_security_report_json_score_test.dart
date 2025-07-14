import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nwc_densetsu/diagnostics.dart';

void main() {
  test('runSecurityReport converts float score from JSON', () async {
    Future<ProcessResult> fakeRunner(String exe, List<String> args) async {
      const data = {
        'ip': '8.8.8.8',
        'score': 3.6,
        'risks': [],
        'utmItems': [],
        'open_ports': [],
        'geoip': 'JP',
        'path': ''
      };
      return ProcessResult(0, 0, jsonEncode(data), '');
    }

    final report = await runSecurityReport(
      ip: '8.8.8.8',
      openPorts: const [],
      sslValid: true,
      spfValid: true,
      processRunner: fakeRunner,
    );

    expect(report.score, 3.6);
  });
}
