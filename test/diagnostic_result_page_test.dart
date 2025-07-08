import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nwc_densetsu/result_page.dart';
import 'package:nwc_densetsu/diagnostics.dart';

void main() {
  testWidgets('DiagnosticResultPage shows statuses and actions', (tester) async {
    const items = [
      DiagnosticItem(name: 'A', description: 'd', status: 'safe', action: 'fix1'),
      DiagnosticItem(name: 'B', description: 'd', status: 'warning', action: 'fix2'),
      DiagnosticItem(name: 'C', description: 'd', status: 'danger', action: 'fix3'),
    ];

    final summaries = [
      const PortScanSummary('1.1.1.1', [
        PortStatus(445, 'closed', 'smb'),
        PortStatus(3389, 'open', 'rdp'),
      ])
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: DiagnosticResultPage(
          securityScore: 9.0,
          riskScore: 2.0,
          items: items,
          portSummaries: summaries,
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

    // Port status section
    expect(find.text('ポート開放状況'), findsOneWidget);
    expect(find.textContaining('3389'), findsOneWidget);
    expect(find.textContaining('危険'), findsOneWidget);
  });
}
