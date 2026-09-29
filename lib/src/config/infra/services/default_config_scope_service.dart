import 'package:grumpy_cli/src/config/domain/datasources/config_datasource.dart';
import 'package:grumpy_cli/src/config/domain/models/config_edit.dart';
import 'package:grumpy_cli/src/config/domain/models/config_format.dart';
import 'package:grumpy_cli/src/config/domain/services/config_scope_service.dart';
import 'package:grumpy_cli/src/config/domain/models/config_setting.dart';
import 'package:grumpy_cli/src/config/domain/services/config_codec_service.dart';
import 'package:grumpy_cli/src/shared/domain/exceptions/cli_usage_exception.dart';

/// Typed reads and explicit, serialized writes for a single config file.
///
/// Reads return only the scope's stored value, without applying defaults. Batch
/// updates validate before replacing the file and update the in-memory snapshot
/// only after a successful write. YAML edits preserve surrounding formatting and
/// comments; JSON writes use consistent indentation.
///
/// Obtain scope instances from a loaded `ConfigService`.
///
/// {@category config}
class DefaultConfigScopeService extends ConfigScopeService {
  /// Creates the internal view of a declared scope; callers use ConfigService.
  DefaultConfigScopeService(
    this.settings,
    this.path,
    this.format,
    this.schemaReference,
    this.datasource,
    this.codec,
  ) : super.internal();

  @override
  String get logTag => 'DefaultConfigScopeService';

  @override
  Future<void> destroy() async {}

  /// Setting handles permitted in this scope.
  @override
  final List<ConfigSetting<dynamic>> settings;

  /// Resolved path used for reads, diagnostics, provenance, and writes.
  @override
  final String path;

  /// Encoding used for this scope's file.
  @override
  final ConfigFormat format;

  /// Optional editor URI including this scope's reusable schema definition.
  @override
  final String? schemaReference;

  /// Filesystem boundary used for loading and safe replacement.
  final ConfigDatasource datasource;

  /// Codec borrowed from DI.
  final ConfigCodecService codec;
  Map<String, Object?> _values = {};
  String? _original;
  Future<void> _pending = Future.value();

  /// Returns this file's explicit typed value, without defaults or other scopes.
  @override
  T? get<T>(ConfigSetting<T> setting) {
    checkSetting(setting);
    return _values.containsKey(setting.name)
        ? setting.type.decode(_values[setting.name])
        : null;
  }

  /// Internal presence check that distinguishes stored values from absence.
  @override
  bool contains(ConfigSetting<dynamic> setting) {
    checkSetting(setting);
    return _values.containsKey(setting.name);
  }

  /// Returns this file's explicit value or reports which setting/file is missing.
  @override
  T require<T>(ConfigSetting<T> setting) =>
      get(setting) ??
      (throw CliUsageException('Missing ${setting.name} in $path.'));

  /// Rejects a handle that is not declared for this scope before reading or editing.
  @override
  void checkSetting(ConfigSetting<dynamic> setting) {
    if (!settings.contains(setting)) {
      throw ArgumentError('Setting ${setting.name} does not belong to $path.');
    }
  }

  Map<String, Object?> _parse(String? content) =>
      codec.decode(content, format: format, source: path);

  void _validate(Map<String, Object?> values) {
    final byName = {for (final s in settings) s.name: s};
    for (final entry in values.entries) {
      if (entry.key == r'$schema') {
        if (entry.value is! String) {
          throw CliUsageException('$path: ${entry.key} must be a string.');
        }
        continue;
      }
      final setting = byName[entry.key];
      if (setting == null) {
        throw CliUsageException(
          '$path: unknown setting ${entry.key} for this scope.',
        );
      }
      try {
        setting.type.decode(entry.value);
      } on CliUsageException catch (e) {
        throw CliUsageException('$path: ${entry.key}: ${e.message}');
      }
    }
  }

  /// Waits for queued edits and reloads the file as a validated snapshot.
  ///
  /// A failed reload keeps the current in-memory snapshot.
  @override
  Future<void> reload() async {
    await _pending;
    final content = await datasource.read(path);
    final values = _parse(content);
    _validate(values);
    _original = content;
    _values = values;
  }

  /// Validates and persists one typed value in this scope.
  @override
  Future<void> set<T>(ConfigSetting<T> setting, T value) =>
      update((edit) => edit.set(setting, value));

  /// Removes this scope's explicit value.
  ///
  /// Removing a local override reveals a global value or declared default during
  /// effective resolution; it never copies that fallback into this file.
  @override
  Future<void> remove(ConfigSetting<dynamic> setting) =>
      update((edit) => edit.remove(setting));

  /// Serializes a synchronous batch, validates it, and replaces the file safely.
  ///
  /// Failed validation or IO leaves both disk contents and this snapshot unchanged.
  /// The callback must not perform asynchronous work or retain its edit object.
  @override
  Future<void> update(void Function(ConfigEdit edit) edit) {
    final operation = _pending.then((_) async {
      final changes = ConfigEdit.forScope(this);
      edit(changes);
      final values = Map<String, Object?>.from(_values);
      for (final key in changes.removals) {
        values.remove(key);
      }
      values.addAll(changes.values);
      if (schemaReference != null && format == ConfigFormat.json) {
        values[r'$schema'] = schemaReference;
      }
      _validate(values);
      final content = codec.encode(
        values,
        format: format,
        original: _original,
        schemaReference: schemaReference,
      );
      // Verify the edited document before touching the original file.
      _validate(_parse(content));
      await datasource.replace(path, content, expected: _original);
      _original = content;
      _values = values;
    });
    _pending = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }
}
