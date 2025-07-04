import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nwc_densetsu/utils/file_utils.dart';

void main() {
  test('saveReport writes file and returns its path', () async {
    final path = await saveReport('hello');
    final file = File(path);
    expect(await file.exists(), isTrue);
    expect(await file.readAsString(), 'hello');
    await file.delete();
  });
}
