import 'package:grumpy/grumpy.dart';
import '../services/config_service.dart';
import 'config_schema.dart';

/// Contract implemented by generated immutable application configuration.
abstract class CliConfig<C extends Object> extends Model {
  /// Creates a configuration snapshot.
  const CliConfig();

  /// Descriptors generated from your global and local model declarations.
  ConfigSchema get configSchema;

  /// Builds a resolved snapshot after both configuration files have loaded.
  C resolveConfig(ConfigService service);
}
