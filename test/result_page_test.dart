import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nwc_densetsu/diagnostics.dart';
import 'package:nwc_densetsu/result_page.dart';

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
    expect(find.text('9'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('risk1'), findsOneWidget);
    expect(find.text('risk2'), findsOneWidget);
    expect(find.text('レポート保存'), findsOneWidget);

    final table = tester.widget<DataTable>(find.byType(DataTable).first);
    final row1Color = table.rows[0].color?.resolve({});
    final row2Color = table.rows[1].color?.resolve({});
    expect(row1Color, Colors.green);
    expect(row2Color, Colors.redAccent);

    expect(find.byType(Card), findsNWidgets(2));
  });

  testWidgets('DiagnosticResultPage shows items in a DataTable', (tester) async {
    const items = [
      DiagnosticItem(
        name: 'ポート開放',
        description: '説明1',
        status: 'warning',
        action: '閉じる',
      ),
      DiagnosticItem(
        name: 'SSL 証明書',
        description: '説明2',
        status: 'danger',
        action: '更新する',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: DiagnosticResultPage(
          securityScore: 5,
          riskScore: 3,
          items: items,
        ),
      ),
    );

    final tableFinder = find.byType(DataTable);
    expect(tableFinder, findsOneWidget);
    final dataTable = tester.widget<DataTable>(tableFinder);
    expect(dataTable.columns.length, 4);
    expect(find.text('項目名'), findsOneWidget);
    expect(find.text('説明'), findsOneWidget);
    expect(find.text('現状'), findsOneWidget);
    expect(find.text('推奨対策'), findsOneWidget);
    expect(find.text('ポート開放'), findsOneWidget);
    expect(find.text('閉じる'), findsOneWidget);
  });
}
