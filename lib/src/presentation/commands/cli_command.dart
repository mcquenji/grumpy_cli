import 'package:grumpy_annotations/grumpy_annotations.dart';
import 'dart:async';
import 'package:grumpy/grumpy.dart';
import 'package:meta/meta.dart';
import 'package:grumpy_cli/src/arguments/domain/models/argument_schema.dart';
import 'package:grumpy_cli/src/routing/domain/models/command_context.dart';
import 'package:grumpy_cli/src/routing/domain/models/command_result.dart';

/// An executable leaf whose arguments are declared before application startup.
///
/// Override `arguments` with reusable typed handles and put side effects in
/// `execute`. Grumpy's `preview` and `content` return this handler without running
/// it, so navigation and help inspection cannot execute the command.
///
/// {@category presentation}
@BaseClass(
  allowedLayers: {.presentation},
  typeDirectory: 'commands',
  forceSuffix: false,
)
abstract class CliCommand extends Leaf<CliCommand> {
  /// Creates a side-effect-free handler declaration.
  const CliCommand();

  /// Typed declarations read during help and parsing, before module activation.
  ArgumentSchema get arguments => const ArgumentSchema();

  /// Runs the command once using validated inputs and active dependencies.
  ///
  /// Return an exit result or throw an actionable usage/cancellation error. Respect
  /// cooperative cancellation during long operations and before side effects.
  Future<CommandResult> execute(CommandContext context);

  /// Returns this handler without executing it or accessing dependencies.
  @override
  @nonVirtual
  CliCommand preview(RouteContext ctx) => this;

  /// Returns this handler without executing it; only explicit CLI runs execute.
  @override
  @nonVirtual
  CliCommand content(RouteContext ctx) => this;
}
