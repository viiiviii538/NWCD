import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nwc_densetsu/result_page.dart';
import 'package:nwc_densetsu/ssl_check_section.dart';
import 'package:nwc_densetsu/diagnostics.dart';
import 'package:nwc_densetsu/network_scan.dart';
import 'package:nwc_densetsu/extended_results.dart';

void main() {
  testWidgets('DiagnosticResultPage shows statuses and actions', (tester) async {
    const items = [
      DiagnosticItem(name: 'A', description: 'd', status: 'safe', action: 'fix1'),
      DiagnosticItem(name: 'B', description: 'd', status: 'warning', action: 'fix2'),
      DiagnosticItem(name: 'C', description: 'd', status: 'danger', action: 'fix3'),
    ];

    final summaries = [
      const PortScanSummary('1.1.1.1', [
        PortStatus(445, 'closed', 'smb'),
        PortStatus(3389, 'open', 'rdp'),
      ])
    ];
    const devices = [
      NetworkDevice('1.1.1.1', 'AA:BB', 'V1', 'host1'),
    ];
    const reports = [
      SecurityReport('1.1.1.1', 9, [RiskItem('r', 'c')], [], '',
          openPorts: [], geoip: 'US'),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: DiagnosticResultPage(
          securityScore: 2.0,
          items: items,
          sslEntries: const [],
          portSummaries: summaries,
          devices: devices,
          reports: reports,
        ),
      ),
    );

    expect(find.text('セキュリティスコア'), findsOneWidget);
    expect(find.byIcon(Icons.error), findsOneWidget);

    // Verify status and action text for each item
    expect(find.text('現状: safe'), findsOneWidget);
    expect(find.text('推奨対策: fix1'), findsOneWidget);
    expect(find.text('現状: warning'), findsOneWidget);
    expect(find.text('推奨対策: fix2'), findsOneWidget);
    expect(find.text('現状: danger'), findsOneWidget);
    expect(find.text('推奨対策: fix3'), findsOneWidget);

    // Port status section
    expect(find.text('ポート開放状況'), findsOneWidget);
testWidgets('ポートの状態表示とLANデバイスが表示される', (tester) async {
  const devices = [
    LanDeviceRisk(
      ip: '1.1.1.1',
      mac: '00:11',
      vendor: 'TestVendor',
      name: 'host1',
      status: 'ok',
      comment: '',
    )
  ];
  await tester.pumpWidget(
    const MaterialApp(
      home: DiagnosticResultPage(
        securityScore: 5,
        riskScore: 5,
        items: [],
        lanDevices: devices,
        portSummaries: [],
      ),
    ),
  );

  expect(find.text('3389'), findsOneWidget);
  expect(find.text('危険（開いている）'), findsOneWidget);
  expect(find.text('445'), findsOneWidget);
  expect(find.text('安全（閉じている）'), findsOneWidget);

  expect(find.text('host1'), findsOneWidget);
  expect(find.byType(DataRow), findsWidgets);
});

testWidgets('外部通信テーブルが正しく表示される', (tester) async {
  const comms = [
    ExternalCommInfo(
      domain: 'example.com',
      protocol: 'HTTP',
      encryption: '非暗号化',
      status: '危険',
      comment: 'r',
    ),
  ];

  await tester.pumpWidget(
    const MaterialApp(
      home: DiagnosticResultPage(
        securityScore: 5,
        riskScore: 5,
        items: [],
        externalComms: comms,
      ),
    ),
  );

  expect(find.text('外部通信の暗号化状況'), findsOneWidget);
  expect(find.text('example.com'), findsOneWidget);
  expect(find.text('HTTP'), findsOneWidget);
  expect(find.text('非暗号化'), findsOneWidget);
});

testWidgets('SSL テーブルが表示される', (tester) async {
  const ssl = [
    SslCheck(
      domain: 'example.com',
      issuer: 'CA',
      expiry: '2025-01-01',
      safe: true,
      comment: '',
    ),
  ];

  await tester.pumpWidget(
    const MaterialApp(
      home: DiagnosticResultPage(
        securityScore: 5,
        riskScore: 5,
        items: [],
        sslChecks: ssl,
      ),
    ),
  );

  expect(find.text('SSL証明書の安全性チェック'), findsOneWidget);
  expect(find.text('example.com'), findsOneWidget);
  expect(find.text('CA'), findsOneWidget);
  expect(find.text('2025-01-01'), findsOneWidget);
});

testWidgets('extended result sections are visible when data provided', (tester) async {
  const ssl = [
    SslCheck(
      domain: 'example.com',
      issuer: 'CA',
      expiry: '2025',
      status: 'ok',
      comment: '',
    )
  ];
  const spf = [
    SpfCheck(
      domain: 'example.com',
      spf: 'v=spf1',
      status: 'ok',
      comment: '',
    )
  ];
  const auth = [
    DomainAuthCheck(
      domain: 'example.com',
      spf: true,
      dkim: false,
      dmarc: false,
      status: 'ok',
      comment: '',
    )
  ];
  const geo = [GeoIpStat(country: 'US', count: 1, status: 'ok')];
  const devices = [
    LanDeviceRisk(
      ip: '1.1.1.1',
      mac: '00:11',
      vendor: 'Acme',
      name: 'Dev',
      status: 'ok',
      comment: '',
    )
  ];
  const comms = [
    ExternalCommInfo(
      domain: 'example.com',
      protocol: 'HTTPS',
      encryption: '暗号化',
      status: 'ok',
      comment: '',
    )
  ];
  const defense = [
    DefenseFeatureStatus(
      feature: 'Firewall',
      status: 'recommended',
      comment: '',
    )
  ];
  const version = 'Windows 10';

  await tester.pumpWidget(
    const MaterialApp(
      home: DiagnosticResultPage(
        securityScore: 5,
        riskScore: 5,
        items: [],
        sslChecks: ssl,
        spfChecks: spf,
        domainAuths: auth,
        geoipStats: geo,
        lanDevices: devices,
        externalComms: comms,
        defenseStatus: defense,
        windowsVersion: version,
      ),
    ),
  );

  expect(find.text('SPFレコードの設定状況'), findsOneWidget);
  expect(find.text('ドメインの送信元検証設定'), findsOneWidget);
  expect(find.text('GeoIP解析：通信先の国別リスクチェック'), findsOneWidget);
  expect(find.text('LAN内デバイス一覧とリスクチェック'), findsOneWidget);
  expect(find.text('外部通信の暗号化状況'), findsOneWidget);
  expect(find.text('端末の防御機能の有効性チェック'), findsOneWidget);
  expect(find.text('Windows バージョン'), findsOneWidget);
  expect(find.text(version), findsOneWidget);
});


    await tester.pumpWidget(
      const MaterialApp(
        home: DiagnosticResultPage(
          securityScore: 8,
  riskScore: 1,
  items: [],
  sslEntries: sslItems,
  portSummaries: [],
  spfChecks: spf,
  domainAuths: auth,
  geoipStats: geo,
  lanDevices: devices,
  externalComms: comms,
  defenseStatus: defense,
  windowsVersion: version,

        ),
      ),
    );

    expect(find.text('SSL証明書の安全性チェック'), findsOneWidget);    expect(find.text('example.com'), findsOneWidget);

    expect(find.text('SPFレコードの設定状況'), findsOneWidget);
    expect(find.text('ドメインの送信元検証設定'), findsOneWidget);
    expect(find.text('GeoIP解析：通信先の国別リスクチェック'), findsOneWidget);
    expect(find.text('LAN内デバイス一覧とリスクチェック'), findsOneWidget);
    expect(find.text('外部通信の暗号化状況'), findsOneWidget);
    expect(find.text('端末の防御機能の有効性チェック'), findsOneWidget);
    expect(find.text('Windows バージョン'), findsOneWidget);
    expect(find.text(version), findsOneWidget);
  });

  testWidgets('SPF table rows use colors based on status', (tester) async {
    const results = [
      SpfResult('ok.com', 'v=spf1 -all', 'safe', ''),
      SpfResult('none.com', '', 'danger', 'missing'),
      SpfResult('fail.com', '', 'warning', 'error'),
    ];

    await tester.pumpWidget(
      const MaterialApp(
        home: DiagnosticResultPage(
          securityScore: 5,
          riskScore: 5,
          items: [],
          spfResults: results,
        ),
      ),
    );

    final rows = tester.widgetList<DataRow>(find.byType(DataRow)).toList();
    expect(rows.length, 3);
    expect(rows[0].color?.resolve({}), Colors.green.withOpacity(0.2));
    expect(rows[1].color?.resolve({}), Colors.redAccent.withOpacity(0.2));
    expect(rows[2].color?.resolve({}), Colors.yellowAccent.withOpacity(0.2));
  });

  });
}
