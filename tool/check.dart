import 'dart:io';

/// Runs the package and consuming-example checks with the configured FVM SDK.
Future<void> main() async {
  for (final (directory, arguments) in <(String, List<String>)>[
    ('.', ['dart', 'analyze', '--fatal-infos']),
    ('.', ['dart', 'test']),
    ('example', ['dart', 'pub', 'get']),
    ('example', ['dart', 'run', 'build_runner', 'build']),
    ('example', ['dart', 'analyze', '--fatal-infos']),
    ('example', ['dart', 'test']),
    ('example', ['dart', 'run', 'tool/generate_config_schema.dart', '--check']),
  ]) {
    final process = await Process.start(
      'fvm',
      arguments,
      workingDirectory: directory,
      mode: ProcessStartMode.inheritStdio,
    );
    final result = await process.exitCode;
    if (result != 0) {
      exitCode = result;
      return;
    }
  }
}
