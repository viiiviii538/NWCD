import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nwc_densetsu/diagnostics.dart';

void main() {
  test('runSecurityReport parses floating score', () async {
    Future<ProcessResult> fakeRunner(String exe, List<String> args) async {
      final data = {
        'ip': '1.2.3.4',
        'score': 6.7,
        'risks': [],
        'utmItems': [],
        'open_ports': [],
        'geoip': 'JP',
        'path': ''
      };
      final json = jsonEncode(data);
      return ProcessResult(0, 0, json, '');
    }

    final report = await runSecurityReport(
      ip: '1.2.3.4',
      openPorts: const [],
      sslValid: true,
      spfValid: true,
      processRunner: fakeRunner,
    );

    expect(report.score, 6.7);
  });
}
