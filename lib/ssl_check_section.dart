import 'package:flutter/material.dart';

/// SSL certificate check result entry.
class SslCheckEntry {
  final String domain;
  final String issuer;
  final String expiry;
  final bool safe;
  final String comment;

  const SslCheckEntry({
    required this.domain,
    required this.issuer,
    required this.expiry,
    required this.safe,
    required this.comment,
  });
}

/// Section widget that displays SSL certificate diagnostics in a table.
class SslCheckSection extends StatelessWidget {
  final List<SslCheckEntry> results;

  const SslCheckSection({super.key, required this.results});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SSL証明書の安全性チェック',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'SSL証明書は通信の暗号化と正当性の証明に重要です。不正な証明書や期限切れの証明書は、盗聴やなりすまし攻撃のリスクにつながります。',
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('ドメイン名')),
              DataColumn(label: Text('発行者')),
              DataColumn(label: Text('有効期限')),
              DataColumn(label: Text('状態')),
              DataColumn(label: Text('コメント')),
            ],
            rows: [
              for (final r in results)
                DataRow(
                  color: r.safe
                      ? null
                      : MaterialStateProperty.all(
                          Colors.redAccent.withOpacity(0.1),
                        ),
                  cells: [
                    DataCell(Text(r.domain)),
                    DataCell(Text(r.issuer)),
                    DataCell(Text(r.expiry)),
                    DataCell(
                      Text(
                        r.safe ? '安全' : '危険',
                        style: TextStyle(
                          color: r.safe ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    DataCell(Text(r.comment)),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}
