import 'package:flutter/material.dart';

/// A simple page that lists device IP addresses.
class DeviceListPage extends StatelessWidget {
  /// Devices to display.
  final List<String> devices;

  const DeviceListPage({super.key, this.devices = const []});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Devices')),
      body: ListView(
        children: [for (final d in devices) ListTile(title: Text(d))],
      ),
    );
  }
}
