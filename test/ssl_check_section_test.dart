import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nwc_densetsu/ssl_check_section.dart';

void main() {
  testWidgets('SslCheckSection displays entries', (tester) async {
    const items = [
      SslCheckEntry(
        domain: 'example.com',
        issuer: 'CA',
        expiry: '2025-01-01',
        safe: true,
        comment: '',
      ),
      SslCheckEntry(
        domain: 'bad.example',
        issuer: 'Unknown',
        expiry: '2020-01-01',
        safe: false,
        comment: 'Expired certificate',
      ),
    ];

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SslCheckSection(results: items),
        ),
      ),
    );

    expect(find.text('SSL証明書の安全性チェック'), findsOneWidget);
    expect(find.text('example.com'), findsOneWidget);
    expect(find.text('bad.example'), findsOneWidget);
    expect(find.text('安全'), findsOneWidget);
    expect(find.text('危険'), findsOneWidget);
    expect(find.text('Expired certificate'), findsOneWidget);
  });
}
