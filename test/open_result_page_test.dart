import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:nwc_densetsu/result_page.dart';
import 'package:nwc_densetsu/diagnostics.dart';
import 'package:nwc_densetsu/extended_results.dart';

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

  testWidgets('defense section shows description', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DiagnosticResultPage(
          securityScore: 0,
          items: [],
          portSummaries: [],
          defenseStatus: [
            DefenseFeatureStatus(feature: 'AV', status: 'ok', comment: '')
          ],
        ),
      ),
    );

    expect(find.text('端末の防御機能の有効性チェック'), findsOneWidget);
    expect(
      find.text(
          'セキュリティソフトやファイアウォールなど端末に備わる防御機能が有効か確認します。無効の場合、不正侵入やマルウェア感染のリスクが高まります。'),
      findsOneWidget,
    );
  });
}
