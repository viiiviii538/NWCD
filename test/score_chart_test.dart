import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nwc_densetsu/main.dart';
import 'package:nwc_densetsu/diagnostics.dart';

void main() {
  testWidgets('ScoreChart renders', (WidgetTester tester) async {
    const reports = [
      const SecurityReport('1.1.1.1', 9.0, const <RiskItem>[], const <String>[], '',
          openPorts: const [80], geoip: 'US', utmActive: false),
      const SecurityReport('2.2.2.2', 3.0, const <RiskItem>[], const <String>[], '',
          openPorts: const [22], geoip: 'JP', utmActive: false),
    ];
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: ScoreChart(reports: reports))),
    );
    expect(find.byType(ScoreChart), findsOneWidget);
  });
}
