import 'package:file_selector/file_selector.dart' as fs;
import 'package:path/path.dart' as p;
import 'dart:io';

/// Opens a file save dialog and returns the chosen path.
///
/// The optional [suggestedName] parameter sets the default file name shown
/// to the user in the dialog.
Future<String?> getSavePath({String suggestedName = 'report.txt'}) async {
  try {
    final loc = await fs.getSaveLocation(suggestedName: suggestedName);
    return loc?.path;
  } catch (e) {
    return null;
  }
}

/// Saves diagnostic [content] to a report file on the user's desktop
/// if no path is available. Returns the full file path.
Future<String> saveReport(String content) async {
  final now = DateTime.now();
  final stamp =
      '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}';

  final fileName = 'report_$stamp.txt';

  final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
  Directory dir;
  if (home != null) {
    final desktop = p.join(home, 'Desktop');
    dir = Directory(desktop);
    if (!await dir.exists()) {
      dir = Directory.current;
    }
  } else {
    dir = Directory.current;
  }

  final file = File(p.join(dir.path, fileName));
  await file.writeAsString(content);
  return file.path;
}
