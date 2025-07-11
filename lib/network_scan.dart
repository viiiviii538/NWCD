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
Future<List<NetworkDevice>> scanNetwork({void Function(String message)? onError}) async {
  const script = 'discover_hosts.py';
  try {
    final result = await Process.run(pythonExecutable, [script]);
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
      stderr.writeln('discover_hosts.py produced no output');
      if (onError != null) onError('Empty output from discover_hosts.py');
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
