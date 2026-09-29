import 'package:grumpy_cli/src/arguments/domain/models/cli_argument.dart';

/// One named value converted to `T`, for example `--port=8080`.
///
/// A scalar option uses its last explicit occurrence. `defaultValue` applies only
/// through resolved argument access; it never marks the option as supplied.
///
/// {@category arguments}
class CliOption<T> extends CliArgument<T> {
  /// Declares one typed named option and optional aliases.
  CliOption(
    super.name, {
    required super.type,
    super.description,
    super.defaultValue,
    super.required,
    this.abbreviation,
    this.aliases = const [],
  });
  @override
  final String? abbreviation;
  @override
  final List<String> aliases;
}
