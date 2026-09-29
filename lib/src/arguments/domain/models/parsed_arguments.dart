import 'package:grumpy/grumpy.dart';
import 'package:meta/meta.dart';
import 'package:grumpy_cli/src/arguments/domain/models/cli_argument.dart';
import 'package:grumpy_cli/src/shared/domain/exceptions/cli_usage_exception.dart';

/// Immutable explicit inputs indexed by their original typed declarations.
///
/// `provided` reads only explicit input. `get` adds declared defaults; `require`
/// also rejects missing values. All accessors reject handles outside this schema.
/// False, zero, empty strings, and empty lists remain present values.
///
/// {@category arguments}
class ParsedArguments extends Model {
  /// Snapshots declaration handles and explicit values produced by the parser.
  @internal
  ParsedArguments.internal(
    List<CliArgument<dynamic>> declarations,
    Map<CliArgument<dynamic>, Object?> values,
  ) : _declarations = Set.unmodifiable(declarations),
      _values = Map.unmodifiable(values);
  final Set<CliArgument<dynamic>> _declarations;
  final Map<CliArgument<dynamic>, Object?> _values;
  void _check(CliArgument<dynamic> argument) {
    if (!_declarations.contains(argument)) {
      throw ArgumentError(
        'Argument ${argument.name} is not part of this invocation.',
      );
    }
  }

  /// Returns only an explicitly supplied value, or null when omitted.
  ///
  /// Explicit false, zero and empty strings remain distinguishable from omission.
  T? provided<T>(CliArgument<T> argument) {
    _check(argument);
    return _values[argument] as T?;
  }

  /// Whether the declaration appeared explicitly, independently of its value.
  bool wasProvided(CliArgument<dynamic> argument) {
    _check(argument);
    return _values.containsKey(argument);
  }

  /// Returns explicit input, then the declared default, or null when neither exists.
  T? get<T>(CliArgument<T> argument) =>
      provided(argument) ?? argument.defaultValue;

  /// Resolves explicit input or default and throws a usage error when absent.
  T require<T>(CliArgument<T> argument) =>
      get(argument) ?? (throw CliUsageException('Missing ${argument.name}.'));
}
