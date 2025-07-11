import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nwc_densetsu/result_page.dart';
import 'package:nwc_densetsu/ssl_check_section.dart';

void main() {
  testWidgets('DiagnosticResultPage shows statuses and actions', (tester) async {
    const items = [
      DiagnosticItem(name: 'A', description: 'd', status: 'safe', action: 'fix1'),
      DiagnosticItem(name: 'B', description: 'd', status: 'warning', action: 'fix2'),
      DiagnosticItem(name: 'C', description: 'd', status: 'danger', action: 'fix3'),
    ];

    await tester.pumpWidget(
      const MaterialApp(
        home: DiagnosticResultPage(
          securityScore: 9,
          riskScore: 2,
          items: items,
          sslEntries: const [],
        ),
      ),
    );

    expect(find.text('セキュリティスコア'), findsOneWidget);
    expect(find.text('リスクスコア'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.byIcon(Icons.error), findsOneWidget);

    // Verify status and action text for each item
    expect(find.text('現状: safe'), findsOneWidget);
    expect(find.text('推奨対策: fix1'), findsOneWidget);
    expect(find.text('現状: warning'), findsOneWidget);
    expect(find.text('推奨対策: fix2'), findsOneWidget);
    expect(find.text('現状: danger'), findsOneWidget);
    expect(find.text('推奨対策: fix3'), findsOneWidget);
  });

  testWidgets('DiagnosticResultPage displays SSL table', (tester) async {
    const sslItems = [
      SslCheckEntry(
        domain: 'example.com',
        issuer: 'CA',
        expiry: '2025-01-01',
        safe: true,
        comment: '',
      ),
    ];

    await tester.pumpWidget(
      const MaterialApp(
        home: DiagnosticResultPage(
          securityScore: 8,
          riskScore: 1,
          items: [],
          sslEntries: sslItems,
        ),
      ),
    );

    expect(find.byType(SslCheckSection), findsOneWidget);
    expect(find.text('SSL証明書の安全性チェック'), findsOneWidget);
    expect(find.text('example.com'), findsOneWidget);
  });
}
