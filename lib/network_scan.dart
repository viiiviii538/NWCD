import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Represents a discovered network device.
class NetworkDevice {
  final String ip;
  final String mac;
  final String vendor;
  final String name;

  const NetworkDevice(this.ip, this.mac, this.vendor, [this.name = '']);
}

/// Runs the LAN discovery script and returns a list of devices.
Future<List<NetworkDevice>> scanNetwork({void Function(String message)? onError}) async {
  const script = 'discover_hosts.py';
  try {
    final result = await Process.run('python', [script]);
    if (result.exitCode != 0) {
      final msg = result.stderr.toString().trim();
      stderr.writeln(msg.isEmpty
          ? 'LAN discovery script exited with code ${result.exitCode}'
          : msg);
      if (onError != null) onError(msg);
      return [];
    }
    final data = jsonDecode(result.stdout.toString()) as Map<String, dynamic>;
    final devices = <NetworkDevice>[];
    if (data.containsKey('hosts')) {
      for (final item in data['hosts']) {
        devices.add(NetworkDevice(
          item['ip'] ?? '',
          item['mac'] ?? '',
          item['vendor'] ?? '',
          item['name'] ?? item['hostname'] ?? '',
        ));
      }
    }
    return devices;
  } catch (e) {
    stderr.writeln(e);
    if (onError != null) onError(e.toString());
    return [];
  }
}
