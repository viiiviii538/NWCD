import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:nwc_densetsu/geoip_result_page.dart';

void main() {
  testWidgets('GeoipResultPage shows chart and entries', (tester) async {
    final entries = [
      GeoipEntry('1.1.1.1', 'example.com', 'CN'),
      GeoipEntry('2.2.2.2', 'example.org', 'US'),
    ];

    await tester.pumpWidget(
      MaterialApp(home: GeoipResultPage(entries: entries)),
    );

    expect(find.byType(BarChart), findsOneWidget);
    expect(find.byType(Card), findsNWidgets(2));
    expect(find.textContaining('1.1.1.1'), findsOneWidget);
    expect(find.textContaining('2.2.2.2'), findsOneWidget);

    final card = tester.widget<Card>(find.byType(Card).first);
    expect(card.color, equals(Colors.redAccent.withOpacity(0.2)));
    final icon = tester.widget<Icon>(find.byIcon(Icons.error));
    expect(icon.color, equals(Colors.redAccent));
  });
}
