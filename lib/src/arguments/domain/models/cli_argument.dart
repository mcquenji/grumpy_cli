import 'package:grumpy/grumpy.dart';
import 'package:grumpy_cli/src/shared/domain/models/cli_value_type.dart';

/// A typed declaration handle shared by a command schema and its consumer.
///
/// Reuse the same instance when reading `ParsedArguments`; names are for CLI
/// syntax, not runtime lookups. Conversion and constraints live in `type` and are
/// also reusable by configuration settings and prompts.
///
/// {@category arguments}
abstract class CliArgument<T> extends Model {
  /// Creates a declaration and validates its name and optional default.
  CliArgument(
    this.name, {
    required this.type,
    this.description = '',
    this.defaultValue,
    this.required = false,
  }) {
    if (name.isEmpty || !RegExp(r'^[a-zA-Z][a-zA-Z0-9_-]*$').hasMatch(name)) {
      throw ArgumentError.value(name, 'name', 'Invalid argument name');
    }
    if (defaultValue != null) type.check(defaultValue as T);
  }

  /// Long option name or positional label, without leading dashes.
  final String name;

  /// Shared text/config conversion and validation for this declaration.
  final CliValueType<T> type;

  /// Human-readable explanation used in help.
  final String description;

  /// Fallback used by resolved accessors; never counts as explicit input.
  final T? defaultValue;

  /// Whether parsing must obtain a value.
  ///
  /// A scalar default satisfies this requirement; repeated arguments require at
  /// least one explicit occurrence.
  final bool required;

  /// Whether values are consumed by position instead of an option name.
  bool get positional => false;

  /// Alternate long option names without leading dashes.
  List<String> get aliases => const [];

  /// Optional single-character spelling used after one dash.
  String? get abbreviation => null;

  /// Whether the declaration consumes a list of raw values.
  bool get multiple => false;

  /// Converts parser output through the declared codec.
  ///
  /// Adapter boundary: command code normally reads `ParsedArguments` instead.
  Object? parseRaw(Object? value) => type.parse(value as String);
}
