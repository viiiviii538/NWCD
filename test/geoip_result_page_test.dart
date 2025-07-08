import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nwc_densetsu/geoip_result_page.dart';

void main() {
  testWidgets('GeoipResultPage shows entries and chart correctly', (tester) async {
    final entries = [
      GeoipEntry('1.1.1.1', 'example.com', 'CN'),
      GeoipEntry('2.2.2.2', 'mal.example', 'US'),
    ];

    await tester.pumpWidget(
      MaterialApp(home: GeoipResultPage(entries: entries)),
    );

    // 見出し確認
    expect(find.text('GeoIP解析：通信先の国別リスクチェック'), findsOneWidget);

    // Chart & Card
    expect(find.byType(BarChart), findsOneWidget);
    expect(find.byType(Card), findsNWidgets(2));

    // ドメイン・IP確認
    expect(find.text('example.com'), findsOneWidget);
    expect(find.text('mal.example'), findsOneWidget);
    expect(find.textContaining('1.1.1.1'), findsOneWidget);
    expect(find.textContaining('2.2.2.2'), findsOneWidget);

    // スタイル確認（危険アイコンなど）
    final card = tester.widget<Card>(find.byType(Card).first);
    expect(card.color, equals(Colors.redAccent.withOpacity(0.2)));

    final icon = tester.widget<Icon>(find.byIcon(Icons.error));
    expect(icon.color, equals(Colors.redAccent));
  });
}

  });
}
