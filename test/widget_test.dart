// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:nwc_densetsu/main.dart';

void main() {
  testWidgets('Home page shows title and buttons', (WidgetTester tester) async {
    // Build the app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the main title and LAN scan button are present.
    expect(find.text('NWCD'), findsOneWidget);
    expect(find.text('LANスキャン'), findsOneWidget);
    expect(find.text('レポート保存'), findsOneWidget);
    expect(find.byType(DropdownButton<String>), findsOneWidget);
  });
}
