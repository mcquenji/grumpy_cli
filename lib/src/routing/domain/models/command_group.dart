import 'package:grumpy/grumpy.dart';
import 'package:grumpy_cli/src/module/cli_module.dart';
import 'package:grumpy_cli/src/presentation/commands/cli_command.dart';

/// Mounts a CLI module as a visible group of subcommands.
///
/// The module's options are inherited by descendant commands. Invoking a group
/// without a command displays its usage. Imported modules only become visible
/// when explicitly mounted through a group declaration.
///
/// {@category routing}
class CommandGroup<C extends Object> extends ModuleRoute<CliCommand, C> {
  /// Mounts a CLI module under a literal group name and optional middleware.
  CommandGroup({
    required String name,
    required CliModule<C> module,
    this.description = '',
    super.middleware,
  }) : super(path: name, module: module);

  /// Literal CLI group token, bridged to the inherited route path.
  String get name => path;

  /// Group summary shown in help without activating the module.
  final String description;
}
