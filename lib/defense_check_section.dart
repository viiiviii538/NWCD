import 'package:flutter/material.dart';

/// Section widget that displays Defender and Firewall status.
class DefenseCheckSection extends StatelessWidget {
  final bool? defenderEnabled;
  final bool? firewallEnabled;

  const DefenseCheckSection({
    super.key,
    required this.defenderEnabled,
    required this.firewallEnabled,
  });

  DataRow _row(String name, bool? enabled, String comment) {
    Color? rowColor;
    TextStyle? textStyle;
    String state;
    if (enabled == null) {
      state = '不明';
    } else if (enabled) {
      state = '有効';
      rowColor = Colors.green.withOpacity(0.2);
      textStyle = const TextStyle(color: Colors.green);
    } else {
      state = '無効';
      rowColor = Colors.redAccent.withOpacity(0.2);
      textStyle = const TextStyle(color: Colors.red, fontWeight: FontWeight.bold);
    }
    return DataRow(
      color: rowColor != null ? MaterialStateProperty.all(rowColor) : null,
      cells: [
        DataCell(Text(name)),
        DataCell(Text(state, style: textStyle)),
        DataCell(Text(comment)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (defenderEnabled == null && firewallEnabled == null) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '端末の防御機能の有効性チェック',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'リアルタイム保護やファイアウォールが無効な状態では、マルウェア感染や外部からの侵入を防ぐことができず、端末が極めて無防備になります。基本的なセキュリティ機能が適切に動作しているかを確認してください。',
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('保護機能名')),
              DataColumn(label: Text('状態')),
              DataColumn(label: Text('コメント')),
            ],
            rows: [
              _row(
                'リアルタイム保護（Defender）',
                defenderEnabled,
                'ウイルスやマルウェアを常時監視し、感染を未然に防ぎます。無効化すると新たな脅威を検知できません。',
              ),
              _row(
                '外部アクセス遮断（Firewall）',
                firewallEnabled,
                '不正アクセスをブロックします。無効にすると外部からの侵入に対して無防備になります。',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
