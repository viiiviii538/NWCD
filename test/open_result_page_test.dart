import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:nwc_densetsu/result_page.dart';
import 'package:nwc_densetsu/diagnostics.dart';

void main() {
  testWidgets('port summaries shown when result page opened', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DiagnosticResultPage(
          securityScore: 0,
          items: [],
          portSummaries: [
            PortScanSummary('1.1.1.1', [PortStatus(80, 'open', 'http')])
          ],
        ),
      ),
    );

    expect(find.text('ポート開放状況'), findsOneWidget);
    expect(find.textContaining('80'), findsOneWidget);
    expect(find.text('http'), findsOneWidget);
    expect(find.text('1/1 ポート開放'), findsOneWidget);
  });
}
