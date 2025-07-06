import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nwc_densetsu/result_page.dart';

void main() {
  testWidgets('DiagnosticResultPage shows colored status labels', (tester) async {
    const items = [
      DiagnosticItem(name: 'A', description: 'd', status: 'safe'),
      DiagnosticItem(name: 'B', description: 'd', status: 'warning'),
      DiagnosticItem(name: 'C', description: 'd', status: 'danger'),
    ];

    await tester.pumpWidget(
      const MaterialApp(
        home: DiagnosticResultPage(
          securityScore: 9,
void main() {
  testWidgets('DiagnosticResultPage shows styled scores and colored labels', (tester) async {
    const items = [
      DiagnosticItem(name: 'A', description: 'd', status: 'safe'),
      DiagnosticItem(name: 'B', description: 'd', status: 'warning'),
      DiagnosticItem(name: 'C', description: 'd', status: 'danger'),
    ];

    await tester.pumpWidget(
      const MaterialApp(
        home: DiagnosticResultPage(
          securityScore: 9,
          riskScore: 2,
          items: items,
        ),
      ),
    );

    // スコアの表示確認
    expect(find.text('セキュリティスコア'), findsOneWidget);
    expect(find.text('リスクスコア'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.byIcon(Icons.error), findsOneWidget);

    final text = tester.widget<Text>(find.text('9'));
    expect(text.style?.fontSize, 48);

    // ステータス色の確認
    final safeText = tester.widget<Text>(find.text('safe'));
    final warningText = tester.widget<Text>(find.text('warning'));
    final dangerText = tester.widget<Text>(find.text('danger'));

    expect(safeText.style?.color, Colors.green);
    expect(warningText.style?.color, Colors.orange);
    expect(dangerText.style?.color, Colors.red);
  });
}

  });
}
