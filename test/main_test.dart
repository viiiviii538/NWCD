import 'package:flutter_test/flutter_test.dart';
import 'package:nwc_densetsu/main.dart';

void main() {
  testWidgets('HomePage displays LAN scan button', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('LANスキャン'), findsOneWidget);
  });

  testWidgets('Selecting port preset updates dropdown',
      (WidgetTester tester) async {}, skip: true);
}
