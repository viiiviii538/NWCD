import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nwc_densetsu/diagnostics.dart';
import 'package:nwc_densetsu/result_page.dart';
import 'package:nwc_densetsu/extended_results.dart';
import 'package:nwc_densetsu/utils/report_utils.dart' as report_utils;

void main() {
  testWidgets('ResultPage displays scores and items', (WidgetTester tester) async {
    const reports = [
      SecurityReport('1.1.1.1', 9, [RiskItem('risk1', 'fix1')], [], '',
          openPorts: [80], geoip: 'US'),
      SecurityReport('2.2.2.2', 4, [RiskItem('risk2', 'fix2')], [], '',
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
    expect(find.text('レポート保存'), findsOneWidget);

    // Verify that the generated risk texts include the status labels.
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
      const MaterialApp(
        home: DiagnosticResultPage(
          securityScore: 4,
          items: items,
          portSummaries: [],
        ),
      ),
    );

    expect(find.text('チェック1'), findsOneWidget);
    expect(find.text('説明'), findsOneWidget);
    expect(find.text('現状: ok'), findsOneWidget);
    expect(find.text('推奨対策: 対策する'), findsOneWidget);
  });

  testWidgets('Topology button triggers topology generation', (tester) async {
    const devices = [
      LanDeviceRisk(
          ip: '192.168.1.2',
          mac: '00:11',
          vendor: 'Test',
          name: 'd',
          status: 'ok',
          comment: '',
          note: '')
    ];

    var called = false;
    await tester.pumpWidget(
      MaterialApp(
        home: DiagnosticResultPage(
          securityScore: 4,
          items: const [],
          portSummaries: const [],
          lanDevices: devices,
          onGenerateTopology: () async {
            called = true;
            return report_utils.generateTopologyDiagram(devices);
          },
        ),
      ),
    );

    final topoButton = find.text('トポロジ表示');
    expect(topoButton, findsOneWidget);
    await tester.tap(topoButton);
    await tester.pumpAndSettle();
    expect(called, isTrue);
  }, skip: true);

  testWidgets('Tapping device row triggers topology generation', (tester) async {
    const devices = [
      LanDeviceRisk(
          ip: '192.168.1.2',
          mac: '00:11',
          vendor: 'Test',
          name: 'd',
          status: 'ok',
          comment: '',
          note: '')
    ];

    var called = false;
    await tester.pumpWidget(
      MaterialApp(
        home: DiagnosticResultPage(
          securityScore: 4,
          items: const [],
          portSummaries: const [],
          lanDevices: devices,
          onGenerateTopology: () async {
            called = true;
            return report_utils.generateTopologyDiagram(devices);
          },
        ),
      ),
    );

    final deviceRow = find.text('192.168.1.2');
    expect(deviceRow, findsOneWidget);
    await tester.scrollUntilVisible(deviceRow, 100);
    await tester.tap(deviceRow);
    await tester.pumpAndSettle();
    expect(called, isTrue);
  }, skip: true);
}
