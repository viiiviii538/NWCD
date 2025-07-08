import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nwc_densetsu/diagnostics.dart' as diag;

void main() {
  test('checkDkimRecord tries selectors', () async {
    final file = File('${Directory.systemTemp.path}/dkim.txt');
    await file.writeAsString(
        'google._domainkey.example.com. IN TXT "v=DKIM1; k=rsa"');
    final ok = await diag.checkDkimRecord(
      'example.com',
      recordsFile: file.path,
      selectors: ['default', 'google'],
    );
    expect(ok, isTrue);
    await file.delete();
  });

  test('checkDmarcRecord detects absence', () async {
    final file = File('${Directory.systemTemp.path}/dmarc.txt');
    await file.writeAsString('no record');
    final ok = await diag.checkDmarcRecord('example.com', recordsFile: file.path);
    expect(ok, isFalse);
    await file.delete();
  });
}
