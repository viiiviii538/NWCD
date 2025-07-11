import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nwc_densetsu/result_page.dart';
import 'package:nwc_densetsu/ssl_check_section.dart';
import 'package:nwc_densetsu/diagnostics.dart';
import 'package:nwc_densetsu/network_scan.dart';

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
          securityScore: 9,
          riskScore: 2,
          items: items,
          sslEntries: const [],
          portSummaries: summaries,
          devices: devices,
          reports: reports,
        ),
      ),
    );

    expect(find.text('セキュリティスコア'), findsOneWidget);
    expect(find.text('リスクスコア'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
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
    expect(find.textContaining('3389'), findsOneWidget);
    expect(find.textContaining('危険'), findsOneWidget);

    // LAN devices section
    expect(find.text('host1'), findsOneWidget);
    expect(find.byType(DataRow), findsWidgets);
  });

  testWidgets('External communication table is displayed', (tester) async {
    final comms = [
      const ExternalCommEntry('example.com', 'HTTP', '非暗号化', '危険', 'r')
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: DiagnosticResultPage(
          securityScore: 5,
          riskScore: 5,
          items: const [],
          externalComms: comms,
        ),
      ),
    );

    expect(find.text('外部通信の暗号化状況'), findsOneWidget);
    expect(find.text('example.com'), findsOneWidget);
    expect(find.text('HTTP'), findsOneWidget);
    expect(find.text('非暗号化'), findsOneWidget);
  });

  testWidgets('DiagnosticResultPage displays SSL table', (tester) async {
    const sslItems = [
      SslCheckEntry(
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
          securityScore: 8,
          riskScore: 1,
          items: [],
          sslEntries: sslItems,
        ),
      ),
    );

    expect(find.text('SSL証明書の安全性チェック'), findsOneWidget);
    expect(find.text('example.com'), findsOneWidget);
  });

  testWidgets('SPF table rows use colors based on status', (tester) async {
    const results = [
      SpfResult('ok.com', 'v=spf1 -all', 'safe', '',
          dkimValid: true, dmarcValid: true),
      SpfResult('none.com', '', 'danger', 'missing',
          dkimValid: false, dmarcValid: false),
      SpfResult('fail.com', 'v=spf1 -all', 'safe', '',
          dkimValid: true, dmarcValid: false),
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
}
