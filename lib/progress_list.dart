import 'package:flutter/material.dart';

/// Displays progress indicators for multiple hosts.
class ScanningProgressList extends StatelessWidget {
  final Map<String, int> progress;
  final int taskCount;

  const ScanningProgressList({
    super.key,
    required this.progress,
    required this.taskCount,
  });

  @override
  Widget build(BuildContext context) {
    if (progress.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final e in progress.entries) ...[
          Text('Scanning ${e.key}'),
          LinearProgressIndicator(value: e.value / taskCount),
          const SizedBox(height: 4),
        ],
      ],
    );
  }
}

