import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nwc_densetsu/result_page.dart';
import 'package:nwc_densetsu/diagnostics.dart';
import 'package:nwc_densetsu/extended_results.dart';

void main() {
  testWidgets('DiagnosticResultPage shows statuses and actions', (tester) async {
    const items = [
      DiagnosticItem(name: 'A', description: 'd', status: 'safe', action: 'fix1'),
      DiagnosticItem(name: 'B', description: 'd', status: 'warning', action: 'fix2'),
      DiagnosticItem(name: 'C', description: 'd', status: 'danger', action: 'fix3'),
    ];

    const summaries = [
      PortScanSummary('1.1.1.1', [
        PortStatus(445, 'closed', 'smb'),
        PortStatus(3389, 'open', 'rdp'),
      ])
    ];
    await tester.pumpWidget(
      const MaterialApp(
        home: DiagnosticResultPage(
          securityScore: 2.0,
          items: items,
          portSummaries: summaries,
        ),
      ),
    );

    expect(find.text('セキュリティスコア'), findsOneWidget);
    // One error icon from score section and one from the danger item
    expect(find.byIcon(Icons.error), findsNWidgets(2));
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.byIcon(Icons.warning), findsOneWidget);

    // Verify status and action text for each item
    expect(find.text('現状: safe'), findsOneWidget);
    expect(find.text('推奨対策: fix1'), findsOneWidget);
    expect(find.text('現状: warning'), findsOneWidget);
    expect(find.text('推奨対策: fix2'), findsOneWidget);
    expect(find.text('現状: danger'), findsOneWidget);
    expect(find.text('推奨対策: fix3'), findsOneWidget);

    // Port status section
    expect(find.text('ポート開放状況'), findsOneWidget);
    expect(find.text('3389'), findsOneWidget);
    expect(find.text('open'), findsOneWidget);
    expect(find.text('445'), findsOneWidget);
    expect(find.text('closed'), findsOneWidget);
    expect(find.text('rdp'), findsOneWidget);
    expect(find.text('smb'), findsOneWidget);
    expect(find.text('1/2 ポート開放'), findsOneWidget);
  });

  testWidgets('extended result sections are visible when data provided',
      (tester) async {
    const ssl = [
      SslCheck(
          domain: 'example.com',
          issuer: 'CA',
          expiry: '2025',
          status: 'ok',
          comment: '')
    ];
    const auth = [
      DomainAuthCheck(
          domain: 'example.com',
          spf: true,
          dkim: false,
          dmarc: false,
          status: 'ok',
          comment: '')
    ];
    const geo = [GeoIpStat(country: 'US', count: 1, status: 'ok')];
    const devices = [
      LanDeviceRisk(
          ip: '1.1.1.1',
          mac: '00:11',
          vendor: 'Acme',
          name: 'Dev',
          status: 'ok',
          comment: '')
    ];
    const comms = [
      ExternalCommInfo(
          domain: 'example.com',
          protocol: 'HTTPS',
          encryption: '暗号化',
          status: 'ok',
          comment: '')
    ];
    const defense = [
      DefenseFeatureStatus(feature: 'Firewall', status: 'recommended', comment: '')
    ];
    const version = 'Windows 10';

    await tester.pumpWidget(
      const MaterialApp(
        home: DiagnosticResultPage(
          securityScore: 8,
          items: [],
          portSummaries: [],
          sslChecks: ssl,
          domainAuths: auth,
          geoipStats: geo,
          lanDevices: devices,
          externalComms: comms,
          defenseStatus: defense,
          windowsVersion: version,
        ),
      ),
    );

    expect(find.text('SSL証明書の安全性チェック'), findsOneWidget);
    expect(find.text('ドメインの送信元検証設定'), findsOneWidget);
    expect(find.text('GeoIP解析：通信先の国別リスクチェック'), findsOneWidget);
    expect(find.text('LAN内デバイス一覧とリスクチェック'), findsOneWidget);
    expect(find.text('外部通信の暗号化状況'), findsOneWidget);
    expect(find.text('端末の防御機能の有効性チェック'), findsOneWidget);
    expect(find.text('Windows バージョン'), findsOneWidget);
    expect(find.text(version), findsOneWidget);
  }, skip: true);

  testWidgets('LAN device filter dropdown filters list', (tester) async {
    const devices = [
      LanDeviceRisk(
          ip: '1.1.1.1',
          mac: '00:11',
          vendor: 'A',
          name: 'D1',
          status: 'warning',
          comment: ''),
      LanDeviceRisk(
          ip: '1.1.1.2',
          mac: '00:22',
          vendor: 'B',
          name: 'D2',
          status: 'danger',
          comment: ''),
      LanDeviceRisk(
          ip: '1.1.1.3',
          mac: '00:33',
          vendor: 'C',
          name: 'D3',
          status: 'safe',
          comment: ''),
    ];

    await tester.pumpWidget(
      const MaterialApp(
        home: DiagnosticResultPage(
          securityScore: 5,
          items: [],
          portSummaries: [],
          lanDevices: devices,
        ),
      ),
    );

    // default shows all devices
    expect(find.text('1.1.1.1'), findsOneWidget);
    expect(find.text('1.1.1.2'), findsOneWidget);
    expect(find.text('1.1.1.3'), findsOneWidget);

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Warning').last);
    await tester.pumpAndSettle();

    expect(find.text('1.1.1.1'), findsOneWidget);
    expect(find.text('1.1.1.2'), findsNothing);
    expect(find.text('1.1.1.3'), findsNothing);
  }, skip: true);

  testWidgets('LAN device summary shows status counts', (tester) async {
    const devices = [
      LanDeviceRisk(
          ip: '1',
          mac: 'm1',
          vendor: 'v',
          name: 'n1',
          status: 'safe',
          comment: ''),
      LanDeviceRisk(
          ip: '2',
          mac: 'm2',
          vendor: 'v',
          name: 'n2',
          status: 'warning',
          comment: ''),
      LanDeviceRisk(
          ip: '3',
          mac: 'm3',
          vendor: 'v',
          name: 'n3',
          status: 'danger',
          comment: ''),
      LanDeviceRisk(
          ip: '4',
          mac: 'm4',
          vendor: 'v',
          name: 'n4',
          status: 'danger',
          comment: ''),
    ];

    await tester.pumpWidget(
      const MaterialApp(
        home: DiagnosticResultPage(
          securityScore: 5,
          items: [],
          portSummaries: [],
          lanDevices: devices,
        ),
      ),
    );

    expect(find.text('1 safe / 1 warning / 2 danger'), findsOneWidget);
  }, skip: true);
}
