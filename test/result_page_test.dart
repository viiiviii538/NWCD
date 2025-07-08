import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nwc_densetsu/diagnostics.dart';
import 'package:nwc_densetsu/result_page.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:io';

void main() {
  testWidgets('ResultPage displays scores and items', (WidgetTester tester) async {
    const reports = [
      SecurityReport('1.1.1.1', 9.0, [RiskItem('risk1', 'fix1')], [], '',
          openPorts: [80], geoip: 'US'),
      SecurityReport('2.2.2.2', 4.0, [RiskItem('risk2', 'fix2')], [], '',
          openPorts: [22], geoip: 'JP'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ResultPage(reports: reports, onSave: () {})),
      ),
    );

    expect(find.text('Scores'), findsOneWidget);
    expect(find.text('1.1.1.1'), findsOneWidget);
    expect(find.text('2.2.2.2'), findsOneWidget);
    expect(find.text('9.0'), findsOneWidget);
    expect(find.text('4.0'), findsOneWidget);
    expect(find.text('risk1'), findsOneWidget);
    expect(find.text('risk2'), findsOneWidget);
    expect(find.text('レポート保存'), findsOneWidget);

    // Verify that the generated risk texts include the status labels.
    expect(find.text('安全 → risk1 → fix1'), findsOneWidget);
    expect(find.text('危険 → risk2 → fix2'), findsOneWidget);

    expect(find.byType(Card), findsNWidgets(2));
  });

  testWidgets('DiagnosticResultPage shows action text', (WidgetTester tester) async {
    const items = [
      DiagnosticItem(
        name: 'チェック1',
        description: '説明',
        status: 'ok',
        action: '対策する',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: DiagnosticResultPage(
          securityScore: 5,
          riskScore: 4,
          items: items,
          portSummaries: const [],
        ),
      ),
    );

    expect(find.text('チェック1'), findsOneWidget);
    expect(find.text('説明'), findsOneWidget);
    expect(find.text('現状: ok'), findsOneWidget);
    expect(find.text('推奨対策: 対策する'), findsOneWidget);
  });

  testWidgets('Topology button shows image dialog', (tester) async {
    final imgFile = File('${Directory.systemTemp.path}/dummy.png');
    await imgFile.writeAsBytes(List.filled(10, 0));

    await tester.pumpWidget(
      MaterialApp(
        home: DiagnosticResultPage(
          securityScore: 5,
          riskScore: 4,
          items: const [],
          portSummaries: const [],
          onGenerateTopology: () async => imgFile.path,
        ),
      ),
    );

    expect(find.text('トポロジ表示'), findsOneWidget);
    await tester.tap(find.text('トポロジ表示'));
    await tester.pumpAndSettle();
    expect(find.byType(SvgPicture), findsOneWidget);
  });
}
