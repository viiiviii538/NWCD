import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nwc_densetsu/result_page.dart';

void main() {
  testWidgets('DiagnosticResultPage shows styled scores', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DiagnosticResultPage(
          securityScore: 9,
          riskScore: 3,
          items: <DiagnosticItem>[],
        ),
      ),
    );

    expect(find.text('セキュリティスコア'), findsOneWidget);
    expect(find.text('リスクスコア'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.byIcon(Icons.error), findsOneWidget);
    final text = tester.widget<Text>(find.text('9'));
    expect(text.style?.fontSize, 48);
  });
}
