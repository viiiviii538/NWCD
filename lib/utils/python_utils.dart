import 'dart:io';

/// Returns the Python executable path.
///
/// The environment variable `PYTHON_EXECUTABLE` takes precedence. If not set,
/// the function checks whether `python` can be executed and falls back to
/// `python3` when unavailable.
String getPythonExecutable() {
  final override = Platform.environment['PYTHON_EXECUTABLE'];
  if (override != null && override.isNotEmpty) {
    return override;
  }
  try {
    final result = Process.runSync('python', ['--version']);
    if (result.exitCode == 0) return 'python';
  } catch (_) {
    // ignore errors and try python3
  }
  return 'python3';
}

/// Cached Python executable used by the application.
final String pythonExecutable = getPythonExecutable();
