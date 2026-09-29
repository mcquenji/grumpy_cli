import 'package:grumpy/grumpy.dart';
import 'package:meta/meta.dart';
import 'package:grumpy_cli/src/arguments/domain/models/argument_schema.dart';
import 'package:grumpy_cli/src/presentation/commands/cli_command.dart';

/// A command-group module with Grumpy dependency scopes and lifecycle.
///
/// Expose command declarations through `commands` and inherited named options
/// through `arguments`. Mount this module with a `CommandGroup` to make its
/// commands visible. An entry in `imports` only contributes dependencies.
/// Call the superclass when overriding lifecycle hooks so resources remain owned
/// by the adapter and are released at application shutdown.
///
/// {@category module}
abstract class CliModule<C extends Object> extends Module<CliCommand, C> {
  /// Commands and mounted groups exposed when this module is selected.
  List<Route<CliCommand, C>> get commands;

  /// Named options inherited by descendants of this module.
  ArgumentSchema get arguments => const ArgumentSchema();
  @override
  @nonVirtual
  List<Route<CliCommand, C>> get routes => commands;
  @override
  String get group => '${super.group}.CliModule';
}
