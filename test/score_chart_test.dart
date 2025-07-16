import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nwc_densetsu/main.dart';
import 'package:nwc_densetsu/diagnostics.dart';

void main() {
  testWidgets('ScoreChart renders', (WidgetTester tester) async {
    const reports = [
      SecurityReport('1.1.1.1', 9.0, <RiskItem>[], [], '',
          openPorts: [80], geoip: 'US',utmActive: false,),
      SecurityReport('2.2.2.2', 3.0, <RiskItem>[], [], '',
          openPorts: [22], geoip: 'JP',utmActive: false,),
    ];
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ScoreChart(reports: reports))),
    );
    expect(find.byType(ScoreChart), findsOneWidget);
  });
}
