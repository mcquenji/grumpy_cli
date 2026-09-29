import 'dart:io';
import 'package:grumpy_cli_example/src/app.dart';

/// Runs the setup example and returns its exit code to the shell.
Future<void> main(List<String> arguments) async {
  exitCode = await App().run(arguments);
}
