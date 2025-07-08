import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'ssl_result.dart';
export 'ssl_result.dart';
import 'spf_result.dart';
export 'spf_result.dart';
import 'network_scan.dart' as net;

typedef LanDevice = net.NetworkDevice;

class PortStatus {
  final int port;
  final String state;
  final String service;

  const PortStatus(this.port, this.state, this.service);
}

class PortScanSummary {
  final String host;
  final List<PortStatus> results;

  const PortScanSummary(this.host, this.results);

  bool get hasOpen =>
      results.any((r) => r.state.toLowerCase() == 'open');
}

class LanPortDevice {
  final String ip;
  final String mac;
  final String vendor;
  final List<PortStatus> ports;

  const LanPortDevice(this.ip, this.mac, this.vendor, this.ports);
}

class ExternalCommEntry {
  final String dest;
  final String protocol;
  final String encryption;
  final String state;
  final String comment;

  const ExternalCommEntry(
      this.dest, this.protocol, this.encryption, this.state, this.comment);

  factory ExternalCommEntry.fromJson(Map<String, dynamic> json) {
    return ExternalCommEntry(
      json['dest']?.toString() ?? '',
      json['protocol']?.toString() ?? '',
      json['encryption']?.toString() ?? '',
      json['state']?.toString() ?? '',
      json['comment']?.toString() ?? '',
    );
  }
}


class RiskItem {
  final String description;
  final String countermeasure;

  const RiskItem(this.description, this.countermeasure);
}

class SecurityReport {
  final String ip;
  final int score;
  final List<RiskItem> risks;
  final List<String> utmItems;
  final String path;
  final List<int> openPorts;
  final String geoip;
  final bool dkimValid;
  final bool dmarcValid;

  const SecurityReport(
    this.ip,
    this.score,
    this.risks,
    this.utmItems,
    this.path, {
    this.openPorts = const [],
    this.geoip = '',
    this.dkimValid = false,
    this.dmarcValid = false,
  });
}

class NetworkSpeed {
  final double downloadMbps;
  final double uploadMbps;
  final double pingMs;

  const NetworkSpeed(this.downloadMbps, this.uploadMbps, this.pingMs);
}

class DefenseStatus {
  final bool? defenderEnabled;
  final bool? firewallEnabled;

  const DefenseStatus({this.defenderEnabled, this.firewallEnabled});
}

/// Runs the system ping command.
Future<String> runPing([String host = 'google.com']) async {
  final args = Platform.isWindows ? ['-n', '4', host] : ['-c', '4', host];
  try {
    final result = await Process.run('ping', args);
    return result.stdout.toString();
  } catch (e) {
    return 'Failed to run ping: $e';
  }
}

/// Measures network speed using the `network_speed.py` script.
Future<NetworkSpeed?> measureNetworkSpeed() async {
  const script = 'network_speed.py';
  try {
    final result = await Process.run('python', [script]);
    if (result.exitCode != 0) {
      return null;
    }
    final data = jsonDecode(result.stdout.toString()) as Map<String, dynamic>;
    final down = (data['download'] as num).toDouble();
    final up = (data['upload'] as num).toDouble();
    final ping = (data['ping'] as num).toDouble();
    return NetworkSpeed(down, up, ping);
  } catch (_) {
    return null;
  }
}

/// Checks Defender and firewall status using `firewall_check.py`.
Future<DefenseStatus> checkDefenseStatus() async {
  const script = 'firewall_check.py';
  try {
    final result = await Process.run('python', [script]);
    if (result.exitCode != 0) {
      return const DefenseStatus();
    }
    final data = jsonDecode(result.stdout.toString()) as Map<String, dynamic>;
    bool? _parse(dynamic v) {
      if (v == null) return null;
      if (v is bool) return v;
      final s = v.toString().toLowerCase();
      if (['true', '1', 'yes'].contains(s)) return true;
      if (['false', '0', 'no'].contains(s)) return false;
      return null;
    }
    return DefenseStatus(
      defenderEnabled: _parse(data['defender_enabled']),
      firewallEnabled: _parse(data['firewall_enabled']),
    );
  } catch (_) {
    return const DefenseStatus();
  }
}

/// Runs the bundled Python script using `nmap` to scan [ports] on [host].
/// Returns a [PortScanSummary] containing all results.
Future<PortScanSummary> scanPorts(String host, [List<int>? ports]) async {
  const script = 'port_scan.py';
  try {
    final args = <String>[script, host];
    if (ports != null && ports.isNotEmpty) {
      args.add(ports.join(','));
    }
    final result = await Process.run('python', args);
    if (result.exitCode != 0) {
      throw result.stderr.toString();
    }
    final data = jsonDecode(result.stdout.toString()) as Map<String, dynamic>;
    final portList = <PortStatus>[];
    if (data.containsKey('ports')) {
      for (final item in data['ports']) {
        portList.add(PortStatus(
            int.parse(item['port']),
            item['state'] ?? '',
            item['service'] ?? ''));
      }
    }
    return PortScanSummary(host, portList);
  } catch (e) {
    return PortScanSummary(host, []);
  }
}

/// Runs the LAN discovery script and returns a list of devices.
Future<List<LanDevice>> discoverLanDevices() async {
  return await net.scanNetwork();
}

/// Runs the combined LAN + port scan Python script and returns devices with
/// scanned ports. When [subnet] or [ports] are omitted, the defaults from the
/// script are used.
Future<List<LanPortDevice>> scanLanWithPorts({
  String? subnet,
  List<int>? ports,
}) async {
  const script = 'lan_port_scan.py';
  final args = <String>[];
  if (subnet != null) {
    args.addAll(['--subnet', subnet]);
  }
  if (ports != null && ports.isNotEmpty) {
    args.addAll(['--ports', ports.join(',')]);
  }
  try {
    final result = await Process.run('python', [script, ...args]);
    if (result.exitCode != 0) {
      throw result.stderr.toString();
    }
    final data = jsonDecode(result.stdout.toString()) as List<dynamic>;
    final devices = <LanPortDevice>[];
    for (final item in data) {
      final portList = <PortStatus>[];
      if (item['ports'] is List) {
        for (final p in item['ports']) {
          portList.add(PortStatus(
            int.tryParse(p['port'].toString()) ?? 0,
            p['state'] ?? '',
            p['service'] ?? '',
          ));
        }
      }
      devices.add(LanPortDevice(
        item['ip']?.toString() ?? '',
        item['mac']?.toString() ?? '',
        item['vendor']?.toString() ?? '',
        portList,
      ));
    }
    return devices;
  } catch (_) {
    return [];
  }
}

/// Runs external_ip_report.py and returns parsed entries.
Future<List<ExternalCommEntry>> runExternalCommReport() async {
  const script = 'external_ip_report.py';
  try {
    final result = await Process.run('python', [script, '--json']);
    if (result.exitCode != 0) {
      return [];
    }
    final data = jsonDecode(result.stdout.toString()) as List<dynamic>;
    return [
      for (final item in data)
        ExternalCommEntry.fromJson(item as Map<String, dynamic>)
    ];
  } catch (_) {
    return [];
  }
}

/// Fetches SSL certificate information from the host.
Future<SslResult> checkSslCertificate(String host) async {
  try {
    final socket = await SecureSocket.connect(host, 443,
        timeout: const Duration(seconds: 5));
    final cert = socket.peerCertificate;
    socket.destroy();
    if (cert == null) {
      return SslResult('No SSL certificate retrieved.', false);
    }
    final expires = cert.endValidity;
    final issuerDn = cert.issuer;
    final ouMatch = RegExp(r'OU=([^,]+)').firstMatch(issuerDn);
    final orgMatch = RegExp(r'O=([^,]+)').firstMatch(issuerDn);
    final issuerName = ouMatch?.group(1) ?? orgMatch?.group(1) ?? issuerDn;
    final valid = expires.isAfter(DateTime.now());
    final msg = 'SSL cert expires on $expires, issued by $issuerName';
    return SslResult(msg, valid);
  } catch (e) {
    return SslResult('Failed to check SSL certificate: $e', false);
  }
}

/// Retrieves the SPF record for the given domain. When [recordsFile] is
/// supplied, the TXT record is looked up offline via `dns_records.py`.
Future<SpfResult> checkSpfRecord(String domain, {String? recordsFile}) async {
  const script = 'dns_records.py';
  final args = <String>[script, domain];
  if (recordsFile != null) {
    args.addAll(['--zone-file', recordsFile]);
  }
  try {
    final result = await Process.run('python', args);
    if (result.exitCode != 0) {
      throw result.stderr.toString();
    }
    final data = jsonDecode(result.stdout.toString()) as Map<String, dynamic>;
    final record = data['spf']?.toString() ?? '';
    if (record.isEmpty) {
      return SpfResult(domain, '', 'danger', 'No SPF record found');
    }
    return SpfResult(domain, record, 'safe', '');
  } catch (e) {
    return SpfResult(domain, '', 'warning', 'Failed to check SPF record: $e');
  }
}

/// Checks DKIM TXT record either via `nslookup` or from a local file.
///
/// [selectors] specifies the DKIM selectors to try in order. The first record
/// containing `v=DKIM1` will result in `true` being returned.
Future<bool> checkDkimRecord(
  String domain, {
  String? recordsFile,
  List<String> selectors = const ['default', 'google', 'selector1'],
}) async {
  const script = 'dns_records.py';
  for (final selector in selectors) {
    final args = <String>[script, domain, '--selector', selector];
    if (recordsFile != null) {
      args.addAll(['--zone-file', recordsFile]);
    }
    try {
      final result = await Process.run('python', args);
      if (result.exitCode != 0) {
        continue;
      }
      final data = jsonDecode(result.stdout.toString()) as Map<String, dynamic>;
      final record = data['dkim']?.toString() ?? '';
      if (record.toLowerCase().contains('v=dkim1')) {
        return true;
      }
    } catch (_) {
      // ignore and try next selector
    }
  }
  return false;
}

/// Checks DMARC TXT record either online or from a zone file using
/// `dns_records.py`.
Future<bool> checkDmarcRecord(String domain, {String? recordsFile}) async {
  const script = 'dns_records.py';
  final args = <String>[script, domain];
  if (recordsFile != null) {
    args.addAll(['--zone-file', recordsFile]);
  }
  try {
    final result = await Process.run('python', args);
    if (result.exitCode != 0) {
      throw result.stderr.toString();
    }
    final data = jsonDecode(result.stdout.toString()) as Map<String, dynamic>;
    final record = data['dmarc']?.toString() ?? '';
    return record.toLowerCase().contains('v=dmarc1');
  } catch (_) {
    return false;
  }
}

Future<SecurityReport> runSecurityReport({
  required String ip,
  required List<int> openPorts,
  required bool sslValid,
  required bool spfValid,
  required bool dkimValid,
  required bool dmarcValid,
  String geoip = 'JP',
}) async {
  const script = 'security_report.py';
  try {
    final result = await Process.run('python', [
      script,
      ip,
      openPorts.join(','),
      sslValid ? 'true' : 'false',
      spfValid ? 'true' : 'false',
      dkimValid ? 'true' : 'false',
      dmarcValid ? 'true' : 'false',
      geoip,
    ]);
    final data = jsonDecode(result.stdout.toString()) as Map<String, dynamic>;
    final risks = <RiskItem>[];
    if (data['risks'] is List) {
      for (final r in data['risks']) {
        if (r is Map) {
          risks.add(RiskItem(
            r['risk']?.toString() ?? '',
            r['counter']?.toString() ?? '',
          ));
        } else if (r is List && r.length >= 2) {
          risks.add(RiskItem(r[0].toString(), r[1].toString()));
        } else {
          risks.add(RiskItem(r.toString(), ''));
        }
      }
    }
    final utm = <String>[];
    if (data['utmItems'] is List) {
      for (final u in data['utmItems']) {
        utm.add(u.toString());
      }
    }
    final ports = <int>[];
    if (data['open_ports'] is List) {
      for (final p in data['open_ports']) {
        final v = int.tryParse(p.toString());
        if (v != null) ports.add(v);
      }
    }
    final country = data['geoip']?.toString() ?? '';
    final dkim = data['dkim_valid'] == true ||
        data['dkim_valid']?.toString().toLowerCase() == 'true';
    final dmarc = data['dmarc_valid'] == true ||
        data['dmarc_valid']?.toString().toLowerCase() == 'true';
    return SecurityReport(
      data['ip']?.toString() ?? ip,
      data['score'] is int
          ? data['score'] as int
          : int.tryParse(data['score'].toString()) ?? 0,
      risks,
      utm,
      data['path']?.toString() ?? '',
      openPorts: ports,
      geoip: country,
      dkimValid: dkim,
      dmarcValid: dmarc,
    );
  } catch (e) {
    return SecurityReport(
      ip,
      0,
      [RiskItem('error', e.toString())],
      [],
      '',
      openPorts: [],
      geoip: '',
      dkimValid: false,
      dmarcValid: false,
    );
  }
}

/// Performs diagnostics for [ip] and returns a [SecurityReport].
Future<SecurityReport> analyzeHost(
  String ip, {
  List<int>? ports,
  required String domain,
}) async {
  final portSummary = await scanPorts(ip, ports);
  final sslRes = await checkSslCertificate(ip);
  final spfRes = await checkSpfRecord(domain);
  final dkimValid = await checkDkimRecord(domain);
  final dmarcValid = await checkDmarcRecord(domain);
  final report = await runSecurityReport(
    ip: ip,
    openPorts: [for (final p in portSummary.results)
      if (p.state == 'open') p.port],
    sslValid: sslRes.valid,
    spfValid: spfRes.status == 'safe',
    dkimValid: dkimValid,
    dmarcValid: dmarcValid,
  );
  return report;
}


