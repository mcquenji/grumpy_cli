import 'package:grumpy_cli/src/config/domain/datasources/config_datasource.dart';
import 'package:grumpy_cli/src/config/domain/models/config_schema.dart';
import 'package:grumpy_cli/src/config/domain/services/config_schema_service.dart';

/// Emits schema and settings reference files through the configured datasource.
class DefaultConfigSchemaService extends ConfigSchemaService {
  /// Borrows storage; this service never disposes it.
  DefaultConfigSchemaService(this.datasource) : super.internal();

  /// Storage used for artifact reads and safe replacement.
  final ConfigDatasource datasource;
  @override
  String get logTag => 'DefaultConfigSchemaService';
  @override
  Future<bool> generate(
    ConfigSchema schema, {
    String schemaPath = 'schema.json',
    String? docsPath,
    bool check = false,
  }) async {
    final documents = {
      schemaPath: schema.jsonSchemaDocument(),
      ?docsPath: schema.markdownDocument(),
    };
    var current = true;
    for (final entry in documents.entries) {
      final original = await datasource.read(entry.key);
      if (check) {
        current = original == entry.value && current;
      } else {
        await datasource.replace(entry.key, entry.value, expected: original);
      }
    }
    return current;
  }

  @override
  Future<void> destroy() async {}
}
