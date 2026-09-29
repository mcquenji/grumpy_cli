import 'package:grumpy_cli/src/config/domain/datasources/config_datasource.dart';
import 'package:grumpy_cli/src/config/domain/models/config_explanation.dart';
import 'package:grumpy_cli/src/config/domain/models/config_files.dart';
import 'package:grumpy_cli/src/config/domain/models/config_schema.dart';
import 'package:grumpy_cli/src/config/domain/services/config_scope_service.dart';
import 'package:grumpy_cli/src/config/domain/models/config_setting.dart';
import 'package:grumpy_cli/src/config/domain/models/config_source.dart';
import 'package:grumpy_cli/src/config/domain/services/config_codec_service.dart';
import 'package:grumpy_cli/src/config/domain/services/config_location_service.dart';
import 'package:grumpy_cli/src/config/domain/services/config_service.dart';
import 'package:grumpy_cli/src/config/infra/services/default_config_scope_service.dart';
import 'package:grumpy_cli/src/shared/domain/exceptions/cli_usage_exception.dart';

/// Loads scoped settings and resolves local, global, then declared defaults.
///
/// Only settings declared for a scope participate in resolution. Lists and objects
/// replace the lower-precedence value as a whole; they are never deep-merged.
/// False, zero, and empty values are preserved. Load before reading, and name a
/// scope explicitly when writing through `global` or `local`.
///
/// Generated AppConfig snapshots read their effective values from this service.
///
/// {@category config}
class DefaultConfigService extends ConfigService {
  /// Creates a settings service without discovering or reading files.
  DefaultConfigService({
    required this.schema,
    required this.files,
    required this.datasource,
    required this.locations,
    required this.codec,
  }) : super.internal();

  /// Typed declarations for the global and local scopes.
  @override
  final ConfigSchema schema;

  /// File formats, locations, and local discovery policy.
  @override
  final ConfigFiles files;

  /// Injectable filesystem boundary used by both scopes.
  final ConfigDatasource datasource;

  /// Location policy implementation, borrowed from DI.
  final ConfigLocationService locations;

  /// Document encoding implementation, borrowed from DI.
  final ConfigCodecService codec;

  /// Global-only view, available after successful loading.
  @override
  late ConfigScopeService global;

  /// Local-only view, available after successful loading.
  @override
  late ConfigScopeService local;
  bool _loaded = false;

  /// Discovers and validates both files before publishing either new scope.
  ///
  /// Missing files are empty scopes. Invalid syntax, types or scope properties
  /// raise actionable usage errors. A failed reload preserves the previous views.
  @override
  Future<void> load() async {
    final globalScope = DefaultConfigScopeService(
      schema.global,
      locations.globalPath(files),
      files.global.format,
      schema.reference('global'),
      datasource,
      codec,
    );
    final localScope = DefaultConfigScopeService(
      schema.local,
      await locations.localPath(files),
      files.local.format,
      schema.reference('local'),
      datasource,
      codec,
    );
    await globalScope.reload();
    await localScope.reload();
    global = globalScope;
    local = localScope;
    _loaded = true;
  }

  void _check() {
    if (!_loaded) throw StateError('Load configuration before reading it.');
  }

  /// Returns local value, global value, then default, for participating scopes.
  @override
  T? get<T>(ConfigSetting<T> setting) => explain(setting).value;

  /// Resolves a setting or throws a usage error if its effective value is absent.
  @override
  T require<T>(ConfigSetting<T> setting) =>
      get(setting) ??
      (throw CliUsageException('Missing setting ${setting.name}.'));

  /// Resolves a setting with provenance and the supplying file path.
  ///
  /// Requires prior loading and rejects undeclared setting handles.
  @override
  ConfigExplanation<T> explain<T>(ConfigSetting<T> setting) {
    _check();
    final inLocal = schema.local.contains(setting),
        inGlobal = schema.global.contains(setting);
    if (!inLocal && !inGlobal) {
      throw ArgumentError('Undeclared setting ${setting.name}.');
    }
    if (inLocal && local.contains(setting)) {
      return ConfigExplanation(
        local.get(setting),
        ConfigSource.local,
        file: local.path,
      );
    }
    if (inGlobal && global.contains(setting)) {
      return ConfigExplanation(
        global.get(setting),
        ConfigSource.global,
        file: global.path,
      );
    }
    return ConfigExplanation(
      setting.defaultValue,
      setting.hasDefault ? ConfigSource.defaultValue : ConfigSource.absent,
    );
  }

  @override
  bool get singelton => true;
  @override
  String get logTag => 'DefaultConfigService';
  @override
  Future<void> destroy() async {}
}
