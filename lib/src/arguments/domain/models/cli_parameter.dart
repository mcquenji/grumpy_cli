import 'package:grumpy_cli/src/arguments/domain/models/cli_argument.dart';

/// One positional argument, assigned in declaration order.
///
/// Required positional parameters must precede optional parameters. Use a
/// `CliRestParameter` as the final positional declaration to consume the rest.
///
/// {@category arguments}
class CliParameter<T> extends CliArgument<T> {
  /// Declares one positional input and its optional default.
  CliParameter(
    super.name, {
    required super.type,
    super.description,
    super.defaultValue,
    super.required,
  });
  @override
  bool get positional => true;
}
