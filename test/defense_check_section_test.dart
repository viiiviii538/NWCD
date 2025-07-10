import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nwc_densetsu/defense_check_section.dart';

void main() {
  testWidgets('DefenseCheckSection shows statuses', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DefenseCheckSection(
            defenderEnabled: true,
            firewallEnabled: false,
          ),
        ),
      ),
    );

    expect(find.text('端末の防御機能の有効性チェック'), findsOneWidget);
    expect(find.text('リアルタイム保護（Defender）'), findsOneWidget);
    expect(find.text('外部アクセス遮断（Firewall）'), findsOneWidget);
    expect(find.text('有効'), findsOneWidget);
    expect(find.text('無効'), findsOneWidget);
  });
}
