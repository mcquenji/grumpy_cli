import 'dart:io';

/// Installs sibling dependency overrides for local development.
Future<void> main() async {
  await File('pubspec_overrides.dev.yaml').copy('pubspec_overrides.yaml');
}
