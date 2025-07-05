import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nwc_densetsu/progress_list.dart';

void main() {
  testWidgets('progress list renders entries', (tester) async {
    final progress = {'1.1.1.1': 2, '2.2.2.2': 1};
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScanningProgressList(progress: progress, taskCount: 3),
        ),
      ),
    );
    expect(find.byType(LinearProgressIndicator), findsNWidgets(2));
    expect(find.textContaining('Scanning'), findsNWidgets(2));
  });
}
