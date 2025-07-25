import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'utils/python_utils.dart';

/// Represents a discovered network device.
class NetworkDevice {
  final String ip;
  final String mac;
  final String vendor;

  const NetworkDevice(this.ip, this.mac, this.vendor);
}

/// Runs the LAN discovery script and returns a list of devices.
Future<List<NetworkDevice>> scanNetwork(
    {void Function(String message)? onError}) async {
  const checkScript = 'scanner_check.py';
  const script = 'nwcd_cli.py';
  try {
    final check = await Process.run(pythonExecutable, [checkScript]);
    if (check.exitCode != 0) {
      try {
        final data = jsonDecode(check.stdout.toString()) as Map<String, dynamic>;
        final missing = (data['missing'] as List<dynamic>).join(', ');
        final msg = 'Missing scanners: $missing';
        stderr.writeln(msg);
        if (onError != null) onError(msg);
      } catch (_) {
        const msg = 'Required scanners not found';
        stderr.writeln(msg);
        if (onError != null) onError(msg);
      }
      return [];
    }
    final result = await Process.run(pythonExecutable, [script, 'discover-hosts']);
    if (result.exitCode != 0) {
      final msg = result.stderr.toString().trim();
      final err = msg.isEmpty
          ? 'LAN discovery script exited with code ${result.exitCode}'
          : msg;
      stderr.writeln(err);
      if (onError != null) onError(err);
      return [];
    }
    final output = result.stdout.toString();
    if (output.trim().isEmpty) {
      stderr.writeln('nwcd_cli.py discover-hosts produced no output');
      if (onError != null) onError('Empty output from nwcd_cli.py discover-hosts');
      return [];
    }
    final data = jsonDecode(output) as Map<String, dynamic>;
    final devices = <NetworkDevice>[];
    if (data.containsKey('hosts')) {
      for (final item in data['hosts']) {
        devices.add(NetworkDevice(
          item['ip'] ?? '',
          item['mac'] ?? '',
          item['vendor'] ?? '',
        ));
      }
    }
    return devices;
  } catch (e) {
    final msg =
        'Failed to run $script: $e. Ensure Python and required tools are installed.';
    stderr.writeln(msg);
    if (onError != null) onError(msg);
    return [];
  }
}
