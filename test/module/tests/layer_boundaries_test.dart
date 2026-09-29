import 'dart:io';
import 'package:test/test.dart';

void main() {
  test(
    'domain code depends on contracts and performs no native storage IO',
    () {
      final files = Directory('lib/src')
          .listSync(recursive: true)
          .whereType<File>()
          .where(
            (file) =>
                file.path.contains('/domain/') && file.path.endsWith('.dart'),
          );
      for (final file in files) {
        final imports = RegExp(
          r"^import '(.*?)'",
          multiLine: true,
        ).allMatches(file.readAsStringSync()).map((match) => match.group(1)!);
        expect(
          imports.where(
            (path) =>
                path.contains('/infra/') ||
                path.contains('/infra.') ||
                path == 'dart:io' ||
                path == 'package:grumpy_cli/grumpy_cli.dart',
          ),
          isEmpty,
          reason: file.path,
        );
      }
    },
  );
}
