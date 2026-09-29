import 'package:grumpy/grumpy.dart';
import 'dart:convert';
import 'package:grumpy_cli/src/config/domain/models/config_setting.dart';

/// Configuration descriptors generated from global and local model declarations.
///
/// Local files accept every global setting plus local-only settings. Use generated
/// AppConfig.settings handles for reads and explicit writes; application authors
/// normally do not need to construct this schema manually.
///
/// {@category config}
class ConfigSchema extends Model {
  /// Declares global and additional local properties with an editor schema URI.
  ///
  /// Duplicate property declarations and URI fragments are rejected.
  ConfigSchema({
    List<ConfigSetting<dynamic>> global = const [],
    List<ConfigSetting<dynamic>> local = const [],
    this.schemaUri,
  }) : global = List.unmodifiable(global),
       local = List.unmodifiable([...global, ...local]) {
    for (final scope in [this.global, this.local]) {
      if (scope.map((s) => s.name).toSet().length != scope.length) {
        throw ArgumentError('Duplicate config keys.');
      }
    }
    final globalNames = this.global.map((s) => s.name).toSet();
    for (final setting in local) {
      if (globalNames.contains(setting.name)) {
        throw ArgumentError('Duplicate config property ${setting.name}.');
      }
    }
    if (schemaUri?.hasFragment ?? false) {
      throw ArgumentError('schemaUri must not contain a fragment.');
    }
  }

  /// Settings permitted in the global configuration file.
  final List<ConfigSetting<dynamic>> global;

  /// All settings permitted locally, including global declarations.
  final List<ConfigSetting<dynamic>> local;

  /// Optional URI of the committed or hosted schema, without a fragment.
  ///
  /// Used only for editor references; runtime validation never fetches it.
  final Uri? schemaUri;

  /// Returns a scope-specific `$defs` reference, or null without a schema URI.
  ///
  /// The adapter passes `global` or `local` as the scope.
  String? reference(String scope) =>
      schemaUri == null ? null : '${schemaUri!}#/${r'$defs'}/$scope';

  /// Creates deterministic JSON Schema 2020-12 definitions for both scopes.
  Map<String, Object?> toJsonSchema() {
    Map<String, Object?> scope(List<ConfigSetting<dynamic>> settings) => {
      'type': 'object',
      'additionalProperties': false,
      'properties': {
        r'$schema': {
          'type': 'string',
          'description': 'Editor schema reference.',
        },
        for (final s in [...settings]..sort((a, b) => a.name.compareTo(b.name)))
          s.name: s.toSchema(),
      },
    };
    return {
      r'$schema': 'https://json-schema.org/draft/2020-12/schema',
      if (schemaUri != null && schemaUri!.isAbsolute)
        r'$id': schemaUri.toString(),
      'title': 'CLI configuration',
      r'$defs': {'global': scope(global), 'local': scope(local)},
      'anyOf': [
        {r'$ref': r'#/$defs/global'},
        {r'$ref': r'#/$defs/local'},
      ],
    };
  }

  /// Formats the generated schema with two-space indentation and a final newline.
  String jsonSchemaDocument() =>
      '${const JsonEncoder.withIndent('  ').convert(toJsonSchema())}\n';

  /// Generates a settings reference including constraints, defaults, and runtime rules.
  String markdownDocument() {
    final out = StringBuffer(
      '# Configuration\n\nLocal values override global values. Declared defaults apply last.\n',
    );
    String cell(Object? value) =>
        '$value'.replaceAll('|', r'\|').replaceAll('\n', ' ');
    for (final entry in {'Global': global, 'Local': local}.entries) {
      out.writeln(
        '\n## ${entry.key}\n\n| Setting | Description | Default | Constraints |\n| --- | --- | --- | --- |',
      );
      for (final setting in [
        ...entry.value,
      ]..sort((a, b) => a.name.compareTo(b.name))) {
        out.writeln(
          '| `${setting.name}` | ${cell(setting.description)} | `${cell(jsonEncode(setting.defaultValue == null ? null : setting.type.encode(setting.defaultValue)))}` | `${cell(jsonEncode(setting.toSchema()))}` |',
        );
      }
    }
    return out.toString();
  }
}
