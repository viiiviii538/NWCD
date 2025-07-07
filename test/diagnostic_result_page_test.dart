import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nwc_densetsu/result_page.dart';

void main() {
  testWidgets('shows score labels, icons and styled score text', (tester) async {
    const items = [
      DiagnosticItem(name: 'A', description: 'desc', status: 'ok', action: '対策する'),
      DiagnosticItem(name: 'B', description: 'desc', status: 'warn', action: '対策する'),
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

    expect(find.text('セキュリティスコア'), findsOneWidget);
    expect(find.text('リスクスコア'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.byIcon(Icons.error), findsOneWidget);

    final scoreText = tester.widget<Text>(find.text('9'));
    expect(scoreText.style?.fontSize, 48);
  });

  testWidgets('each card shows status and action text', (tester) async {
    const items = [
      DiagnosticItem(name: 'A', description: '説明A', status: 'ok', action: '対策A'),
      DiagnosticItem(name: 'B', description: '説明B', status: 'bad', action: '対策B'),
    ];

    await tester.pumpWidget(
      const MaterialApp(
        home: DiagnosticResultPage(
          securityScore: 5,
          riskScore: 3,
          items: items,
        ),
      ),
    );

    for (final item in items) {
      expect(find.text(item.name), findsOneWidget);
      expect(find.text(item.description), findsOneWidget);
      expect(find.text('現状: ${item.status}'), findsOneWidget);
      expect(find.text('推奨対策: ${item.action}'), findsOneWidget);
    }
  });
}
