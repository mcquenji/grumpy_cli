import 'dart:io';
import 'package:grumpy_cli_example/src/memory_app.dart';

/// Runs the example without persisting configuration on disk.
Future<void> main(List<String> arguments) async {
  exitCode = await MemoryApp().run(arguments);
}
