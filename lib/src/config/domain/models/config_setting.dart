import 'package:grumpy/grumpy.dart';
import 'package:grumpy_cli/src/shared/domain/models/cli_value_type.dart';

/// A typed persisted setting and its documentation metadata.
///
/// Generated as AppConfig.settings handles. Reuse a handle's value type in flags
/// or prompts to apply the same conversion and validation rules everywhere.
///
/// {@category config}
class ConfigSetting<T> extends Model {
  /// Declares a setting and validates its default and examples immediately.
  ConfigSetting(
    this.name, {
    required this.type,
    this.description = '',
    this.defaultValue,
    bool hasDefault = false,
    this.examples = const [],
    this.deprecated = false,
  }) : hasDefault = hasDefault || defaultValue != null {
    if (name.isEmpty || name == r'$schema') {
      throw ArgumentError('Invalid config key: $name.');
    }
    if (defaultValue != null) type.encode(defaultValue as T);
    for (final example in examples) {
      type.encode(example);
    }
  }

  /// Persisted property key; empty names and the reserved `$schema` key are invalid.
  final String name;

  /// Shared codec used for config validation, serialization, and generated schemas.
  final CliValueType<T> type;

  /// Setting explanation shown in schema completion and generated documentation.
  final String description;

  /// Whether a default is declared, including an explicit nullable default.
  final bool hasDefault;

  /// Effective fallback when neither participating scope supplies a value.
  final T? defaultValue;

  /// Validated typed examples serialized into the schema and settings reference.
  final List<T> examples;

  /// Whether editors and generated documentation mark this setting deprecated.
  final bool deprecated;

  /// Reified Dart type carried by this setting handle.
  Type get valueType => T;

  /// Builds the property schema including descriptions, defaults, and examples.
  Map<String, Object?> toSchema() => {
    ...type.schema,
    'description': description,
    if (hasDefault) 'default': type.encode(defaultValue as T),
    if (examples.isNotEmpty) 'examples': examples.map(type.encode).toList(),
    if (deprecated) 'deprecated': true,
    if (type.runtimeValidationDescription != null)
      'x-runtime-validation': type.runtimeValidationDescription,
  };
}
