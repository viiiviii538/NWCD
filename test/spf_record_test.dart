import 'dart:io';
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
}
