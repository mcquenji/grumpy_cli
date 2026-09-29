import 'dart:io';

/// Generates or checks the consuming example's config artifacts.
Future<void> main(List<String> arguments) async {
  final result = await Process.start(
    'fvm',
    ['dart', 'run', 'tool/generate_config_schema.dart', ...arguments],
    workingDirectory: 'example',
    mode: ProcessStartMode.inheritStdio,
  );
  exitCode = await result.exitCode;
}
