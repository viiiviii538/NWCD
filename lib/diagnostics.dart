import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'utils/python_utils.dart';

import 'ssl_result.dart';
export 'ssl_result.dart';
import 'network_scan.dart' as net;

typedef LanDevice = net.NetworkDevice;

typedef ProcessRunner = Future<ProcessResult> Function(
    String executable, List<String> arguments);

Future<ProcessResult> _defaultRunner(String exe, List<String> args) =>
    Process.run(exe, args);

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


class RiskItem {
  final String description;
  final String countermeasure;

  const RiskItem(this.description, this.countermeasure);
}

class SecurityReport {
  final String ip;
  final double score;
  final List<RiskItem> risks;
  final List<String> utmItems;
  final String path;
  final List<int> openPorts;
  final String geoip;
  final bool utmActive;

  const SecurityReport(
    this.ip,
    this.score,
    this.risks,
    this.utmItems,
    this.path, {
    this.openPorts = const [],
    this.geoip = '',
    required this.utmActive,
  });
}

class NetworkSpeed {
  final double downloadMbps;
  final double uploadMbps;
  final double pingMs;

  const NetworkSpeed(this.downloadMbps, this.uploadMbps, this.pingMs);
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
Future<NetworkSpeed?> measureNetworkSpeed({void Function(String message)? onError}) async {
  const script = 'network_speed.py';
  try {
    final result = await Process.run(pythonExecutable, [script]);
    if (result.exitCode != 0) {
      final msg = result.stderr.toString().trim();
      if (onError != null && msg.isNotEmpty) onError(msg);
      return null;
    }
    final output = result.stdout.toString();
    if (output.trim().isEmpty) {
      const msg = 'network_speed.py produced no output';
      if (onError != null) onError(msg);
    }
    final data = jsonDecode(output) as Map<String, dynamic>;
    final down = (data['download'] as num).toDouble();
    final up = (data['upload'] as num).toDouble();
    final ping = (data['ping'] as num).toDouble();
    return NetworkSpeed(down, up, ping);
  } catch (e) {
    final msg = 'Failed to run $script: $e';
    if (onError != null) onError(msg);
    return null;
  }
}

/// Detects the Windows version of the current system using ``os_version.py``.
/// Returns ``null`` on non-Windows or when detection fails.
Future<String?> getWindowsVersion({void Function(String message)? onError}) async {
  const script = 'os_version.py';
  try {
    final result = await Process.run(pythonExecutable, [script]);
    if (result.exitCode != 0) return null;
    final output = result.stdout.toString().trim();
    if (output.isEmpty || output == 'Non-Windows') return null;
    return output;
  } catch (e) {
    if (onError != null) onError('Failed to run $script: $e');
    return null;
  }
}

/// Runs the bundled Python script using `nmap` to scan [ports] on [host].
/// Returns a [PortScanSummary] containing all results.
Future<PortScanSummary> scanPorts(String host,
    {List<int>? ports, void Function(String message)? onError}) async {
  const script = 'port_scan.py';
  try {
    final args = <String>[script, host];
    if (ports != null && ports.isNotEmpty) {
      args.add(ports.join(','));
    }
    final result = await Process.run(pythonExecutable, args);
    if (result.exitCode != 0) {
      final msg = result.stderr.toString();
      if (onError != null) onError(msg);
      throw msg;
    }
    final output = result.stdout.toString();
    if (output.trim().isEmpty) {
      return PortScanSummary(host, []);
    }
    final data = jsonDecode(output) as Map<String, dynamic>;
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
    if (onError != null) onError('Failed to run $script: $e');
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
  void Function(String message)? onError,
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
    final result = await Process.run(pythonExecutable, [script, ...args]);
    if (result.exitCode != 0) {
      final msg = result.stderr.toString();
      if (onError != null) onError(msg);
      throw msg;
    }
    final output = result.stdout.toString();
    if (output.trim().isEmpty) {
      return [];
    }
    final data = jsonDecode(output) as List<dynamic>;
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
  } catch (e) {
    if (onError != null) onError('Failed to run $script: $e');
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

/// Retrieves the SPF record for the given domain using `nslookup`.
Future<String> checkSpfRecord(String domain) async {
  try {
    final result = await Process.run('nslookup', ['-type=txt', domain]);
    final output = result.stdout.toString();
    final lines = output.split('\n');
    for (final line in lines) {
      if (line.contains('v=spf1')) {
        return 'SPF record: ${line.trim()}';
      }
    }
    return 'No SPF record found for $domain';
  } catch (e) {
    return 'Failed to check SPF record: $e';
  }
}

Future<SecurityReport> runSecurityReport({
  required String ip,
  required List<int> openPorts,
  required bool sslValid,
  required bool spfValid,
  required bool utmActive,
  String geoip = 'JP',
  ProcessRunner processRunner = _defaultRunner,
}) async {
  const script = 'security_report.py';
  try {
    final result = await processRunner(pythonExecutable, [
      script,
      ip,
      openPorts.join(','),
      sslValid ? 'true' : 'false',
      spfValid ? 'true' : 'false',
      geoip,
    ]);
    final output = result.stdout.toString();
    if (output.trim().isEmpty) {
      return SecurityReport(
        ip,
        0.0,
        [const RiskItem('error', 'No output from security_report.py')],
        [],
        '',
        openPorts: [],
        geoip: '',
        utmActive: utmActive,
      );
    }
    final data = jsonDecode(output) as Map<String, dynamic>;
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
    double parsedScore() {
      final value = data['score'];
      if (value is num) return value.toDouble();
      final d = double.tryParse(value.toString());
      return d ?? 0.0;
    }
    final score = parsedScore();
    return SecurityReport(
      data['ip']?.toString() ?? ip,
      score,
      risks,
      utm,
      data['path']?.toString() ?? '',
      openPorts: ports,
      geoip: country,
      utmActive: true,
    );
  } catch (e) {
    return SecurityReport(
      ip,
      0.0,
      [RiskItem('error', 'Failed to run $script: $e')],
      [],
      '',
      openPorts: [],
      geoip: '',
      utmActive: true,
    );
  }
}

/// Performs diagnostics for [ip] and returns a [SecurityReport].
Future<SecurityReport> analyzeHost(String ip, {List<int>? ports}) async {
  final portSummary = await scanPorts(ip, ports: ports);
  final sslRes = await checkSslCertificate(ip);
  final spfRes = await checkSpfRecord(ip);
  final spfFound = spfRes.startsWith('SPF record');
  final report = await runSecurityReport(
    ip: ip,
    openPorts: [for (final p in portSummary.results)
      if (p.state == 'open') p.port],
    sslValid: sslRes.valid,
    spfValid: spfFound,
    utmActive: false,
  );
  return report;
}


