import 'package:grumpy/grumpy.dart';
import 'package:grumpy_cli/src/presentation/commands/cli_command.dart';

/// A named executable leaf in a CLI module's command tree.
///
/// `name` maps to the inherited route path and `handler` to its leaf view. Names
/// are literal command tokens, not URI patterns. Middleware runs after module
/// activation and before the handler executes.
///
/// {@category routing}
class Command<C extends Object> extends LeafRoute<CliCommand, C> {
  /// Declares a literal command token and its handler.
  ///
  /// Names must be unique within the parent and match `[a-zA-Z][a-zA-Z0-9_-]*`.
  /// The reserved `help` token is rejected during tree validation.
  const Command({
    required String name,
    required CliCommand handler,
    this.description = '',
    super.middleware,
  }) : super(path: name, view: handler);

  /// Literal CLI command token, bridged to the inherited route path.
  String get name => path;

  /// Executable handler, bridged to the inherited leaf view.
  CliCommand get handler => view as CliCommand;

  /// Command summary shown in parent and command-specific help.
  final String description;
}
