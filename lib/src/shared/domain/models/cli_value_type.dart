import 'package:grumpy/grumpy.dart';
import 'package:grumpy_io/grumpy_io.dart';
import 'dart:convert';
import 'package:grumpy_cli/src/shared/domain/exceptions/cli_usage_exception.dart';
import 'package:grumpy_cli/src/shared/domain/models/value_validator.dart';

/// Shared conversion, validation, serialization, and JSON Schema metadata.
///
/// Text arguments and prompts use `parse`; config files use `decode` and `encode`.
/// All three validate using the same rules. Built-in factories generate constraints
/// for editor schemas; custom validators must document rules that cannot be
/// expressed there using `runtimeValidationDescription`.
///
/// ```dart
/// final portType = CliValueType.integer(min: 1, max: 65535);
/// final port = portType.parse('8080');
/// ```
///
/// {@category shared}
/// Shared text conversion, config serialization, validation and schema metadata.
class CliValueType<T> extends Model {
  /// Creates a custom codec with JSON Schema metadata and an optional validator.
  ///
  /// The callbacks must agree on the representation of `T`; `encode` must produce
  /// JSON-compatible data. Describe non-schema rules for generated documentation.
  CliValueType({
    required T Function(String) parse,
    required T Function(Object?) decode,
    required Object? Function(T) encode,
    required Map<String, Object?> schema,
    this.validate,
    this.runtimeValidationDescription,
  }) : _parse = parse,
       _decode = decode,
       _encode = encode,
       schema = Map.unmodifiable(schema);

  final T Function(String) _parse;
  final T Function(Object?) _decode;
  final Object? Function(T) _encode;

  /// Immutable top-level JSON Schema constraints emitted for this value type.
  final Map<String, Object?> schema;

  /// Optional runtime check returning an actionable error message or null.
  final ValueValidator<T>? validate;

  /// Description of rules editors cannot enforce through JSON Schema.
  final String? runtimeValidationDescription;

  /// Validates an already typed value and returns it unchanged.
  ///
  /// Throws a usage error when the runtime validator returns a message.
  T check(T value) {
    final error = validate?.call(value);
    if (error != null) throw CliUsageException(error);
    return value;
  }

  /// Parses text and validates it, normalizing conversion failures to usage errors.
  T parse(String text) => _convert(() => check(_parse(text)));

  /// Decodes a config value and validates it without coercing arbitrary strings.
  T decode(Object? value) => _convert(() => check(_decode(value)));

  /// Validates and serializes a typed value for configuration or schema defaults.
  Object? encode(T value) => _encode(check(value));

  T _convert(T Function() action) {
    try {
      return action();
    } on CliUsageException {
      rethrow;
    } on FormatException catch (e) {
      throw CliUsageException(e.message);
    } on TypeError {
      throw const CliUsageException('Value has the wrong type.');
    } on ArgumentError catch (e) {
      throw CliUsageException('${e.message}');
    }
  }

  /// Accepts explicit null while retaining the non-null value's conversion rules.
  CliValueType<T?> nullable() => CliValueType<T?>(
    parse: (text) => text == 'null' ? null : parse(text),
    decode: (value) => value == null ? null : decode(value),
    encode: (value) => value == null ? null : encode(value),
    schema: {
      'anyOf': [
        schema,
        {'type': 'null'},
      ],
    },
    runtimeValidationDescription: runtimeValidationDescription,
  );

  /// Adds schema constraints and an optional explicitly documented runtime rule.
  CliValueType<T> constrained(
    Map<String, Object?> constraints, {
    String? Function(T)? validator,
    String? runtimeDescription,
  }) {
    T checked(T value) {
      final encoded = encode(value);
      String? error;
      if (encoded is num) {
        final min = constraints['minimum'] as num?,
            max = constraints['maximum'] as num?;
        if (min != null && encoded < min) error = 'Must be at least $min.';
        if (max != null && encoded > max) error = 'Must be at most $max.';
      }
      final int? length = encoded is String
          ? encoded.runes.length
          : encoded is List
          ? encoded.length
          : encoded is Map
          ? encoded.length
          : null;
      if (length != null) {
        final suffix = encoded is String
            ? 'Length'
            : encoded is List
            ? 'Items'
            : 'Properties';
        final min = constraints['min$suffix'] as int?,
            max = constraints['max$suffix'] as int?;
        if (min != null && length < min) {
          error = 'Length must be at least $min.';
        }
        if (max != null && length > max) error = 'Length must be at most $max.';
      }
      final pattern = constraints['pattern'] as String?;
      if (pattern != null &&
          encoded is String &&
          !RegExp(pattern).hasMatch(encoded)) {
        error = 'Must match $pattern.';
      }
      final choices = constraints['enum'] as List?;
      if (choices != null &&
          !choices.any((choice) => jsonEncode(choice) == jsonEncode(encoded))) {
        error = 'Choose one of ${choices.join(', ')}.';
      }
      error ??= validator?.call(value);
      if (error != null) throw CliUsageException(error);
      return value;
    }

    return CliValueType<T>(
      parse: (text) => checked(parse(text)),
      decode: (value) => checked(decode(value)),
      encode: (value) => encode(checked(value)),
      schema: {...schema, ...constraints},
      runtimeValidationDescription:
          runtimeDescription ?? runtimeValidationDescription,
    );
  }

  /// Typed filesystem path without implicit resolution or filesystem access.
  static CliValueType<IoPath> ioPath() => CliValueType<IoPath>(
    parse: (value) => IoPath(string(minLength: 1).parse(value)),
    decode: (value) => IoPath(string(minLength: 1).decode(value)),
    encode: (value) => string(minLength: 1).encode(value.value),
    schema: {'type': 'string', 'minLength': 1},
  );

  /// Immutable string-keyed map whose values share one declared type.
  static CliValueType<Map<String, V>> map<V>(CliValueType<V> valueType) {
    Map<String, V> decode(Object? value) {
      if (value is! Map || value.keys.any((key) => key is! String)) {
        throw const CliUsageException('Expected an object with string keys.');
      }
      return Map.unmodifiable(
        value.map(
          (key, item) => MapEntry(key as String, valueType.decode(item)),
        ),
      );
    }

    return CliValueType<Map<String, V>>(
      parse: (text) => decode(jsonDecode(text)),
      decode: decode,
      encode: (value) =>
          value.map((key, item) => MapEntry(key, valueType.encode(item))),
      schema: {'type': 'object', 'additionalProperties': valueType.schema},
    );
  }

  /// String codec with Unicode character-count bounds, a regex, and optional choices.
  ///
  /// Patterns use regular-expression search semantics; anchor them explicitly
  /// when the entire value must match.
  static CliValueType<String> string({
    int? minLength,
    int? maxLength,
    String? pattern,
    List<String>? choices,
  }) {
    if (minLength != null && minLength < 0 ||
        maxLength != null && (maxLength < 0 || maxLength < (minLength ?? 0))) {
      throw ArgumentError('Invalid string length bounds.');
    }
    final regex = pattern == null ? null : RegExp(pattern);
    return CliValueType<String>(
      parse: (v) => v,
      decode: (v) =>
          v is String ? v : throw const CliUsageException('Expected a string.'),
      encode: (v) => v,
      schema: {
        'type': 'string',
        'minLength': ?minLength,
        'maxLength': ?maxLength,
        'pattern': ?pattern,
        'enum': ?choices,
      },
      validate: (v) {
        final length = v.runes.length;
        if (minLength != null && length < minLength) {
          return 'Use at least $minLength characters.';
        }
        if (maxLength != null && length > maxLength) {
          return 'Use at most $maxLength characters.';
        }
        if (regex != null && !regex.hasMatch(v)) {
          return 'Value must match $pattern.';
        }
        if (choices != null && !choices.contains(v)) {
          return 'Choose one of: ${choices.join(', ')}.';
        }
        return null;
      },
    );
  }

  /// Boolean codec accepting true/false, yes/no, y/n and 1/0 as text.
  ///
  /// Text matching ignores case; configuration values must be actual booleans.
  static CliValueType<bool> boolean() => CliValueType<bool>(
    parse: (v) => switch (v.toLowerCase()) {
      'true' || 'yes' || 'y' || '1' => true,
      'false' || 'no' || 'n' || '0' => false,
      _ => throw const CliUsageException('Expected true or false.'),
    },
    decode: (v) =>
        v is bool ? v : throw const CliUsageException('Expected a boolean.'),
    encode: (v) => v,
    schema: {'type': 'boolean'},
  );

  /// Integer codec with inclusive bounds; config input must be a Dart integer.
  static CliValueType<int> integer({int? min, int? max}) {
    if (min != null && max != null && min > max) {
      throw ArgumentError('Invalid integer bounds.');
    }
    return CliValueType<int>(
      parse: int.parse,
      decode: (v) =>
          v is int ? v : throw const CliUsageException('Expected an integer.'),
      encode: (v) => v,
      schema: {'type': 'integer', 'minimum': ?min, 'maximum': ?max},
      validate: (v) => min != null && v < min
          ? 'Must be at least $min.'
          : max != null && v > max
          ? 'Must be at most $max.'
          : null,
    );
  }

  /// Finite double codec with inclusive bounds; config numeric values become doubles.
  static CliValueType<double> decimal({double? min, double? max}) {
    if (min != null && (!min.isFinite || max != null && min > max) ||
        max != null && !max.isFinite) {
      throw ArgumentError('Invalid decimal bounds.');
    }
    return CliValueType<double>(
      parse: double.parse,
      decode: (v) => v is num
          ? v.toDouble()
          : throw const CliUsageException('Expected a number.'),
      encode: (v) => v,
      schema: {'type': 'number', 'minimum': ?min, 'maximum': ?max},
      validate: (v) => !v.isFinite
          ? 'Must be a finite number.'
          : min != null && v < min
          ? 'Must be at least $min.'
          : max != null && v > max
          ? 'Must be at most $max.'
          : null,
    );
  }

  /// Serializes enum values using their names; parsing is case-sensitive.
  static CliValueType<E> enumeration<E extends Enum>(List<E> values) =>
      choice({for (final value in values) value.name: value});

  /// Maps distinct text names to distinct typed values and back.
  ///
  /// The map must be nonempty and its values unique. Names become schema choices.
  static CliValueType<T> choice<T>(Map<String, T> choices) {
    if (choices.isEmpty || choices.values.toSet().length != choices.length) {
      throw ArgumentError('Choices must be nonempty with unique values.');
    }
    final options = Map<String, T>.unmodifiable(choices);
    T parse(String v) => options.containsKey(v)
        ? options[v] as T
        : throw CliUsageException('Choose one of: ${options.keys.join(', ')}.');
    return CliValueType<T>(
      parse: parse,
      decode: (v) => v is String
          ? parse(v)
          : throw const CliUsageException('Expected a choice name.'),
      encode: (v) => options.entries.firstWhere((e) => e.value == v).key,
      validate: (v) => options.containsValue(v) ? null : 'Unknown choice.',
      schema: {'type': 'string', 'enum': options.keys.toList()},
    );
  }

  /// URI codec serialized as a string, optionally requiring an absolute URI.
  ///
  /// No network lookup or filesystem access is performed.
  static CliValueType<Uri> uri({bool absolute = false}) => CliValueType<Uri>(
    parse: Uri.parse,
    decode: (v) => v is String
        ? Uri.parse(v)
        : throw const CliUsageException('Expected a URI string.'),
    encode: (v) => v.toString(),
    validate: (v) =>
        absolute && !v.hasScheme ? 'Expected an absolute URI.' : null,
    schema: {'type': 'string', 'format': absolute ? 'uri' : 'uri-reference'},
  );

  /// Nonempty string path without automatic resolution or existence checks.
  /// Paths remain strings; resolving against a working directory is explicit.
  static CliValueType<String> path() => string(minLength: 1);

  /// List codec with optional size and serialized-value uniqueness constraints.
  ///
  /// Text input is a JSON array. Decoding validates each element and returns an
  /// immutable typed list; repeated CLI options parse elements individually.
  static CliValueType<List<T>> list<T>(
    CliValueType<T> element, {
    int? minItems,
    int? maxItems,
    bool unique = false,
  }) {
    if (minItems != null && minItems < 0 ||
        maxItems != null && maxItems < (minItems ?? 0)) {
      throw ArgumentError('Invalid list bounds.');
    }
    List<T> decode(Object? v) => v is List
        ? List.unmodifiable(v.map(element.decode))
        : throw const CliUsageException('Expected a list.');
    return CliValueType<List<T>>(
      parse: (v) => decode(jsonDecode(v)),
      decode: decode,
      encode: (v) => v.map(element.encode).toList(),
      schema: {
        'type': 'array',
        'items': element.schema,
        'minItems': ?minItems,
        'maxItems': ?maxItems,
        if (unique) 'uniqueItems': true,
      },
      validate: (v) {
        for (final item in v) {
          element.check(item);
        }
        if (minItems != null && v.length < minItems) {
          return 'Select at least $minItems values.';
        }
        if (maxItems != null && v.length > maxItems) {
          return 'Select at most $maxItems values.';
        }
        if (unique &&
            v.map((e) => jsonEncode(element.encode(e))).toSet().length !=
                v.length) {
          return 'Values must be unique.';
        }
        return null;
      },
    );
  }

  /// Structured-object codec with declared fields and explicit application conversion.
  ///
  /// Unknown keys and missing required keys are rejected. `fromJson` receives the
  /// validated serialized map; it remains responsible for constructing `T` and
  /// converting fields such as enums or URIs. `toJson` must return the matching
  /// serialized representation. Text input is a JSON object.
  /// Declares a structured object with a field schema and typed conversion.
  static CliValueType<T> object<T>({
    required Map<String, CliValueType<dynamic>> properties,
    required T Function(Map<String, Object?>) fromJson,
    required Map<String, Object?> Function(T) toJson,
    List<String> required = const [],
  }) {
    if (required.any((k) => !properties.containsKey(k))) {
      throw ArgumentError('Unknown required property.');
    }
    Map<String, Object?> validateMap(Object? value) {
      if (value is! Map || value.keys.any((k) => k is! String)) {
        throw const CliUsageException('Expected an object with string keys.');
      }
      final map = Map<String, Object?>.from(value);
      for (final key in map.keys) {
        final type = properties[key];
        if (type == null) throw CliUsageException('Unknown property: $key.');
        type.decode(map[key]);
      }
      for (final key in required) {
        if (!map.containsKey(key)) {
          throw CliUsageException('Missing property: $key.');
        }
      }
      return map;
    }

    T decode(Object? value) => fromJson(validateMap(value));
    return CliValueType<T>(
      parse: (s) => decode(jsonDecode(s)),
      decode: decode,
      encode: (v) => validateMap(toJson(v)),
      validate: (v) {
        validateMap(toJson(v));
        return null;
      },
      schema: {
        'type': 'object',
        'properties': {
          for (final e in properties.entries) e.key: e.value.schema,
        },
        'additionalProperties': false,
        if (required.isNotEmpty) 'required': required,
      },
    );
  }
}
