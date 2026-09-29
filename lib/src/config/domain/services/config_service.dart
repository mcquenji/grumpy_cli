import 'package:grumpy/grumpy.dart';
import 'package:grumpy_cli/src/config/domain/models/config_explanation.dart';
import 'package:grumpy_cli/src/config/domain/models/config_files.dart';
import 'package:grumpy_cli/src/config/domain/models/config_schema.dart';
import 'package:grumpy_cli/src/config/domain/services/config_scope_service.dart';
import 'package:grumpy_cli/src/config/domain/models/config_setting.dart';
import 'package:grumpy_cli/src/shared/domain/exceptions/cli_usage_exception.dart';

/// Loads typed config and resolves local values, then global values, then defaults.
///
/// Resolve the registered implementation with `ConfigService()` or replace its app builder.
abstract class ConfigService extends Service {
  /// Resolves the implementation registered under this domain contract.
  factory ConfigService() => Service.get<ConfigService>();

  /// Constructor for independently implemented adapters.
  ConfigService.internal();

  @override
  bool get singelton => true;
  @override
  String get group => '${super.group}.ConfigService';

  /// Definitions governing both scopes.
  ConfigSchema get schema;

  /// Config-file location policy.
  ConfigFiles get files;

  /// Loaded global-only values; writes never select a scope implicitly.
  ConfigScopeService get global;

  /// Loaded local-only values.
  ConfigScopeService get local;

  /// Loads and validates both scopes before publishing them.
  Future<void> load();

  /// Resolves effective value and provenance; requires successful loading.
  ConfigExplanation<T> explain<T>(ConfigSetting<T> setting);

  /// Returns the effective value without conflating false/zero/empty with absence.
  T? get<T>(ConfigSetting<T> setting) => explain(setting).value;

  /// Requires an effective value after precedence and defaults have been applied.
  T require<T>(ConfigSetting<T> setting) =>
      get(setting) ??
      (throw CliUsageException('Missing setting ${setting.name}.'));
}
