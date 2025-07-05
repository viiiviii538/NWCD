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
}
