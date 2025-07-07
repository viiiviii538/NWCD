import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nwc_densetsu/device_list_page.dart';
import 'package:nwc_densetsu/network_scan.dart';
import 'package:nwc_densetsu/diagnostics.dart';

void main() {
  testWidgets('DeviceListPage shows devices and status', (tester) async {
    const devices = [
      NetworkDevice('1.1.1.1', 'AA:BB', 'V1', 'host1'),
      NetworkDevice('2.2.2.2', 'CC:DD', 'V2', 'host2'),
    ];
    const reports = [
      SecurityReport('1.1.1.1', 9, [RiskItem('r', 'c')], [], '',
          openPorts: [], geoip: 'US'),
      SecurityReport('2.2.2.2', 3, [], [], '', openPorts: [], geoip: 'JP'),
    ];

    await tester.pumpWidget(
      const MaterialApp(
        home: DeviceListPage(devices: devices, reports: reports),
      ),
    );

    expect(find.text('1.1.1.1'), findsOneWidget);
    expect(find.text('host1'), findsOneWidget);
    expect(find.text('危険'), findsOneWidget);
    expect(find.byType(DataRow), findsNWidgets(2));
  });
}

