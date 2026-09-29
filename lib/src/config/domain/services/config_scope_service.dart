import 'package:grumpy/grumpy.dart';
import 'package:grumpy_cli/src/config/domain/models/config_edit.dart';
import 'package:grumpy_cli/src/config/domain/models/config_format.dart';
import 'package:grumpy_cli/src/config/domain/models/config_setting.dart';
import 'package:grumpy_cli/src/shared/domain/exceptions/cli_usage_exception.dart';

/// Storage-independent typed view of one explicitly selected config scope.
///
/// Reads do not apply other scopes or defaults. Implementations serialize edits,
/// validate before writing, and preserve the previous snapshot on failure.
abstract class ConfigScopeService extends Service {
  /// Resolves a scope explicitly registered by a host.
  factory ConfigScopeService() => Service.get<ConfigScopeService>();

  @override
  String get group => '${super.group}.ConfigScopeService';

  /// Constructor for scope implementations owned by a config service.
  ConfigScopeService.internal();

  /// Settings permitted in this scope.
  List<ConfigSetting<dynamic>> get settings;

  /// Location reported in diagnostics and provenance.
  String get path;

  /// Declared document format.
  ConfigFormat get format;

  /// Optional editor schema reference.
  String? get schemaReference;

  /// Reads a value explicitly present in this scope.
  T? get<T>(ConfigSetting<T> setting);

  /// Whether the setting is explicitly present, including empty values.
  bool contains(ConfigSetting<dynamic> setting);

  /// Requires an explicit value in this scope.
  T require<T>(ConfigSetting<T> setting) =>
      get(setting) ??
      (throw CliUsageException('Missing ${setting.name} in $path.'));

  /// Rejects handles not declared in this scope before accessing values.
  void checkSetting(ConfigSetting<dynamic> setting) {
    if (!settings.contains(setting)) {
      throw ArgumentError('Setting ${setting.name} does not belong to $path.');
    }
  }

  /// Reloads after queued writes complete; preserves the snapshot on failure.
  Future<void> reload();

  /// Writes one validated typed value to this scope.
  Future<void> set<T>(ConfigSetting<T> setting, T value) =>
      update((e) => e.set(setting, value));

  /// Removes an override, revealing lower-precedence effective values.
  Future<void> remove(ConfigSetting<dynamic> setting) =>
      update((e) => e.remove(setting));

  /// Persists a synchronous batch atomically; do not retain its edit object.
  Future<void> update(void Function(ConfigEdit edit) edit);
}
