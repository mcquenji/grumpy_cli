import 'package:grumpy/grumpy.dart';
import 'package:meta/meta.dart';
import 'package:args/args.dart';
import 'package:grumpy_cli/src/arguments/domain/models/cli_argument.dart';
import 'package:grumpy_cli/src/arguments/domain/models/cli_flag.dart';
import 'package:grumpy_cli/src/arguments/domain/models/parsed_arguments.dart';
import 'package:grumpy_cli/src/shared/domain/exceptions/cli_usage_exception.dart';

/// Declarations, help metadata, and presence-based argument relationships.
///
/// The command tree combines root, group, and leaf schemas before parsing.
/// Validation rejects conflicting names or aliases, reserved help switches,
/// invalid positional ordering, and relationships to undeclared handles.
/// The adapter owns `args` parser integration; command authors use typed handles.
///
/// ```dart
/// final port = CliOption<int>('port', type: CliValueType.integer(min: 1));
/// final schema = ArgumentSchema(arguments: [port]);
/// final value = schema.parse(['--port=8080']).require(port);
/// ```
///
/// {@category arguments}
class ArgumentSchema extends Model {
  /// Declares inputs and relationships; validation occurs before parser use.
  const ArgumentSchema({
    this.arguments = const [],
    this.exclusive = const [],
    this.dependencies = const {},
  });

  /// Ordered declarations, including positional assignment order.
  final List<CliArgument<dynamic>> arguments;

  /// Groups of handles for which at most one may be explicitly supplied.
  final List<List<CliArgument<dynamic>>> exclusive;

  /// Explicit-presence dependencies from one handle to its required companions.
  ///
  /// A negated flag still counts as supplied; declared defaults do not.
  final Map<CliArgument<dynamic>, List<CliArgument<dynamic>>> dependencies;

  /// Combines parent options and relationships with this schema.
  ///
  /// Name and alias conflicts are rejected when the combined schema is validated.
  ArgumentSchema inherit(ArgumentSchema parent) => ArgumentSchema(
    arguments: [...parent.arguments, ...arguments],
    exclusive: [...parent.exclusive, ...exclusive],
    dependencies: {...parent.dependencies, ...dependencies},
  );

  /// Rejects conflicting names, invalid positional order, and invalid relationships.
  ///
  /// Throws `ArgumentError` for developer declaration mistakes, before input parsing.
  void validateDeclaration() {
    final names = <String>{'help', 'h'};
    var optionalPositional = false;
    var restSeen = false;
    for (final arg in arguments) {
      for (final name in [
        arg.name,
        ...arg.aliases,
        if (arg.abbreviation != null) arg.abbreviation!,
        if (arg is CliFlag && arg.negatable)
          ...[arg.name, ...arg.aliases].map((n) => 'no-$n'),
      ]) {
        if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9_-]*$').hasMatch(name) ||
            !names.add(name)) {
          throw ArgumentError(
            'Invalid or conflicting argument name/alias: $name.',
          );
        }
      }
      if (arg.abbreviation != null && arg.abbreviation!.length != 1) {
        throw ArgumentError('Abbreviations must be one character.');
      }
      if (arg.positional) {
        if (restSeen) throw ArgumentError('A rest parameter must be last.');
        if (arg.required && optionalPositional) {
          throw ArgumentError(
            'Required parameters must precede optional parameters.',
          );
        }
        optionalPositional |= !arg.required;
        restSeen = arg.multiple;
      }
    }
    for (final group in exclusive) {
      if (group.length < 2 || group.toSet().length != group.length) {
        throw ArgumentError('Exclusive groups require distinct arguments.');
      }
    }
    for (final arg in [
      ...exclusive.expand((g) => g),
      ...dependencies.keys,
      ...dependencies.values.expand((g) => g),
    ]) {
      if (!arguments.contains(arg)) {
        throw ArgumentError(
          'Relationship references undeclared argument ${arg.name}.',
        );
      }
    }
  }

  /// Builds the internal `args` parser after validating declarations.
  ///
  /// Adds `--help`/`-h`, preserves commas in repeated options, and keeps declared
  /// defaults out of raw parser results so explicit presence is retained.
  /// Internal adapter boundary. Commands normally consume [ParsedArguments].
  @internal
  ArgParser buildParser() {
    validateDeclaration();
    final parser = ArgParser();
    parser.addFlag('help', abbr: 'h', negatable: false, help: 'Show usage.');
    for (final arg in arguments.where((a) => !a.positional)) {
      if (arg is CliFlag) {
        parser.addFlag(
          arg.name,
          abbr: arg.abbreviation,
          aliases: arg.aliases,
          negatable: arg.negatable,
          defaultsTo: false,
          help: arg.description,
        );
      } else if (arg.multiple) {
        parser.addMultiOption(
          arg.name,
          abbr: arg.abbreviation,
          aliases: arg.aliases,
          splitCommas: false,
          help: arg.description,
        );
      } else {
        parser.addOption(
          arg.name,
          abbr: arg.abbreviation,
          aliases: arg.aliases,
          help: arg.description,
        );
      }
    }
    return parser;
  }

  /// Parses original argv tokens into typed values and validates relationships.
  ///
  /// Do not join, split, or reconstruct tokens before calling this method. `--`
  /// ends option parsing. Invalid user input throws a `CliUsageException`.
  ParsedArguments parse(List<String> argv) {
    try {
      final result = buildParser().parse(argv);
      return fromResults([result], result.rest);
    } on FormatException catch (e) {
      throw CliUsageException(e.message);
    }
  }

  /// Combines root-to-leaf parser results with the leaf's positional tokens.
  ///
  /// Internal adapter boundary: scalar values use the last occurrence, while
  /// repeated values preserve their order across command levels.
  @internal
  ParsedArguments fromResults(List<ArgResults> results, List<String> rest) {
    final values = <CliArgument<dynamic>, Object?>{};
    var position = 0;
    for (final arg in arguments) {
      try {
        if (arg.positional) {
          if (position < rest.length) {
            values[arg] = arg.parseRaw(
              arg.multiple ? rest.sublist(position) : rest[position],
            );
            position = arg.multiple ? rest.length : position + 1;
          }
        } else {
          final repeated = <String>[];
          var supplied = false;
          for (final result in results) {
            if (result.options.contains(arg.name) &&
                result.wasParsed(arg.name)) {
              supplied = true;
              if (arg.multiple) {
                repeated.addAll(result[arg.name] as List<String>);
              } else {
                values[arg] = arg.parseRaw(result[arg.name]);
              }
            }
          }
          if (arg.multiple && supplied) values[arg] = arg.parseRaw(repeated);
        }
      } on CliUsageException catch (e) {
        throw CliUsageException('${arg.name}: ${e.message}');
      }
    }
    if (position < rest.length) {
      throw CliUsageException(
        'Unexpected positional arguments: ${rest.sublist(position).join(' ')}',
      );
    }
    return _checkedValues(values);
  }

  /// Binds already typed explicit values from an alternate parser or input source.
  ///
  /// Validates handle membership, value constraints, required inputs and argument
  /// relationships. Defaults are not inserted, preserving explicit presence.
  /// This boundary does not construct or call a package:args parser.
  ParsedArguments bind(Map<CliArgument<dynamic>, Object?> values) {
    validateDeclaration();
    for (final entry in values.entries) {
      if (!arguments.contains(entry.key)) {
        throw ArgumentError('Undeclared argument ${entry.key.name}.');
      }
      try {
        entry.key.type.check(entry.value);
      } on TypeError {
        throw CliUsageException('${entry.key.name}: Value has the wrong type.');
      }
    }
    return _checkedValues(values);
  }

  ParsedArguments _checkedValues(Map<CliArgument<dynamic>, Object?> values) {
    for (final arg in arguments) {
      if (arg.required &&
          !values.containsKey(arg) &&
          arg.defaultValue == null) {
        throw CliUsageException('Missing required argument ${arg.name}.');
      }
      if (arg.required && arg.multiple && !values.containsKey(arg)) {
        throw CliUsageException('Provide at least one value for ${arg.name}.');
      }
      if (arg.required &&
          arg.multiple &&
          values[arg] is List &&
          (values[arg] as List).isEmpty) {
        throw CliUsageException('Provide at least one value for ${arg.name}.');
      }
    }
    for (final group in exclusive) {
      if (group.where(values.containsKey).length > 1) {
        throw CliUsageException(
          'Arguments are mutually exclusive: ${group.map((a) => a.name).join(', ')}',
        );
      }
    }
    for (final entry in dependencies.entries) {
      if (values.containsKey(entry.key)) {
        for (final dependency in entry.value) {
          if (!values.containsKey(dependency)) {
            throw CliUsageException(
              '${entry.key.name} requires ${dependency.name}.',
            );
          }
        }
      }
    }
    return ParsedArguments.internal(arguments, values);
  }
}
