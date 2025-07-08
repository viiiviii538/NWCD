import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nwc_densetsu/geoip_result_page.dart';

void main() {
  testWidgets('GeoipResultPage shows entries and chart', (tester) async {
    final entries = [
      GeoipEntry('1.1.1.1', 'example.com', 'US'),
      GeoipEntry('2.2.2.2', 'mal.example', 'CN'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: GeoipResultPage(entries: entries),
      ),
    );

    expect(find.text('GeoIP解析：通信先の国別リスクチェック'), findsOneWidget);
    expect(find.text('example.com'), findsOneWidget);
    expect(find.text('mal.example'), findsOneWidget);
  });
}
