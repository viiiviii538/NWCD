import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:nwc_densetsu/diagnostics.dart' as diag;

void main() {
  test('checkSpfRecord reads zone file', () async {
    final file = File('${Directory.systemTemp.path}/spf.txt');
    await file.writeAsString('example.com. IN TXT "v=spf1 +mx -all"');
    final res = await diag.checkSpfRecord('example.com', recordsFile: file.path);
    expect(res.record, 'v=spf1 +mx -all');
    expect(res.status, 'safe');
    await file.delete();
  });

  test('checkSpfRecord handles valid lookup', () async {
    Future<ProcessResult> fakeRun(String cmd, List<String> args,
        {String? workingDirectory,
        Map<String, String>? environment,
        bool? runInShell,
        Encoding? stdoutEncoding,
        Encoding? stderrEncoding}) async {
      return ProcessResult(0, 0, jsonEncode({'spf': 'v=spf1 -all'}), '');
    }

    final res = await diag.checkSpfRecord('example.com', runProcess: fakeRun);
    expect(res.status, 'safe');
    expect(res.record, 'v=spf1 -all');
  });

  test('checkSpfRecord handles no record', () async {
    Future<ProcessResult> fakeRun(String cmd, List<String> args,
        {String? workingDirectory,
        Map<String, String>? environment,
        bool? runInShell,
        Encoding? stdoutEncoding,
        Encoding? stderrEncoding}) async {
      return ProcessResult(0, 0, jsonEncode({'spf': ''}), '');
    }

    final res = await diag.checkSpfRecord('example.com', runProcess: fakeRun);
    expect(res.status, 'danger');
  });

  test('checkSpfRecord handles lookup failure', () async {
    Future<ProcessResult> fakeRun(String cmd, List<String> args,
        {String? workingDirectory,
        Map<String, String>? environment,
        bool? runInShell,
        Encoding? stdoutEncoding,
        Encoding? stderrEncoding}) async {
      return ProcessResult(0, 1, '', 'error');
    }

    final res = await diag.checkSpfRecord('example.com', runProcess: fakeRun);
    expect(res.status, 'warning');
  });
}
