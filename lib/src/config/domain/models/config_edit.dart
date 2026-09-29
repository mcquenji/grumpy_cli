import 'package:grumpy/grumpy.dart';
import 'package:grumpy_cli/src/config/domain/services/config_scope_service.dart';
import 'package:grumpy_cli/src/config/domain/models/config_setting.dart';

/// Validated synchronous changes consumable by any ConfigScopeService implementation.
class ConfigEdit extends Model {
  /// Creates a batch for a declared scope; scope implementations call this.
  ConfigEdit.forScope(this._scope);
  final ConfigScopeService _scope;
  final _values = <String, Object?>{};
  final _removals = <String>{};

  /// Serialized values to set, exposed as an immutable snapshot.
  Map<String, Object?> get values => Map.unmodifiable(_values);

  /// Keys explicitly removed, exposed as an immutable snapshot.
  Set<String> get removals => Set.unmodifiable(_removals);

  /// Validates scope membership and serializes one typed value.
  void set<T>(ConfigSetting<T> setting, T value) {
    _scope.checkSetting(setting);
    _values[setting.name] = setting.type.encode(value);
    _removals.remove(setting.name);
  }

  /// Removes an override rather than persisting a fallback value.
  void remove(ConfigSetting<dynamic> setting) {
    _scope.checkSetting(setting);
    _values.remove(setting.name);
    _removals.add(setting.name);
  }
}
