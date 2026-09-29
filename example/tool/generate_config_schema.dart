import 'dart:io';
import 'package:grumpy_cli/grumpy_cli.dart';
import 'package:grumpy_io/grumpy_io.dart';
import 'package:grumpy_cli_example/src/shared/domain/models/app_config.g.dart';

/// Generates settings artifacts, or checks their freshness with --check.
Future<void> main(List<String> arguments) async {
  final service = DefaultConfigSchemaService(
    FileConfigDatasource(fileSystemService: DefaultFileSystemService()),
  );
  final fresh = await service.generate(
    AppConfig.defaults().configSchema,
    schemaPath: 'schema.json',
    docsPath: 'docs/configuration.md',
    check: arguments.contains('--check'),
  );
  if (!fresh) exitCode = 1;
}
