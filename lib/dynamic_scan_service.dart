import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service class to interact with dynamic scan API.
class DynamicScanService {
  /// Base URL of the API server.
  final String baseUrl;

  DynamicScanService({this.baseUrl = 'http://localhost:8000'});

  /// Start dynamic network scan.
  Future<void> startScan({String? subnet}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/dynamic-scan/start'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'subnet': subnet}),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to start scan: ${res.body}');
    }
  }

  /// Stop dynamic scan.
  Future<void> stopScan() async {
    final res = await http.post(Uri.parse('$baseUrl/dynamic-scan/stop'));
    if (res.statusCode != 200) {
      throw Exception('Failed to stop scan: ${res.body}');
    }
  }

  /// Fetch current scan results.
  Future<List<DynamicScanResult>> fetchResults() async {
    final res = await http.get(Uri.parse('$baseUrl/dynamic-scan/results'));
    if (res.statusCode != 200) {
      throw Exception('Failed to fetch results: ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final list = data['results'] as List<dynamic>? ?? [];
    return [for (final item in list) DynamicScanResult.fromJson(item)];
  }
}

/// Represents a single dynamic scan result.
class DynamicScanResult {
  final String ip;
  final List<dynamic> ports;

  DynamicScanResult({required this.ip, required this.ports});

  factory DynamicScanResult.fromJson(Map<String, dynamic> json) {
    return DynamicScanResult(
      ip: json['ip'] ?? '',
      ports: json['ports'] as List<dynamic>? ?? [],
    );
  }
}
