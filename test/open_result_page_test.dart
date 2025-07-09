import 'package:flutter_test/flutter_test.dart';
import 'package:nwc_densetsu/main.dart';
import 'package:nwc_densetsu/diagnostics.dart';

void main() {
  testWidgets('port summaries shown when result page opened', (tester) async {
    await tester.pumpWidget(const MyApp());

    final state = tester.state(find.byType(HomePage)) as dynamic;
    state.setState(() {
      state._scanResults = [
        const PortScanSummary('1.1.1.1', [
          PortStatus(80, 'open', 'http'),
        ])
      ];
    });

    await tester.tap(find.text('診断結果ページ'));
    await tester.pumpAndSettle();

    expect(find.text('ポート開放状況'), findsOneWidget);
    expect(find.textContaining('80'), findsOneWidget);
  });
}
