import 'package:grumpy/grumpy.dart';
import 'package:grumpy_cli/src/config/domain/models/config_schema.dart';

/// Generates config schema/reference artifacts through replaceable storage.
///
/// Resolve the registered implementation with `ConfigSchemaService()` or replace its app builder.
abstract class ConfigSchemaService extends Service {
  /// Resolves the implementation registered under this domain contract.
  factory ConfigSchemaService() => Service.get<ConfigSchemaService>();

  /// Constructor for independently implemented adapters.
  ConfigSchemaService.internal();

  @override
  bool get singelton => true;
  @override
  String get group => '${super.group}.ConfigSchemaService';

  /// Writes declarations as schema/docs, or checks freshness without writing.
  ///
  /// Returns false only when check mode finds missing or stale output.
  Future<bool> generate(
    ConfigSchema schema, {
    String schemaPath = 'schema.json',
    String? docsPath,
    bool check = false,
  });
}
