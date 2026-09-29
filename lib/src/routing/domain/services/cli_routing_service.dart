import 'package:grumpy/grumpy.dart';
import 'package:grumpy_cli/src/presentation/commands/cli_command.dart';
import 'package:grumpy_cli/src/routing/domain/models/command_result.dart';
import 'package:grumpy_cli/src/routing/domain/models/command_invocation.dart';

/// Grumpy routing contract extended with independent explicit CLI execution.
///
/// Implementations select handlers through navigate without executing them.
/// Readiness must track dependency activation, never command completion.
abstract class CliRoutingService<C extends Object>
    extends RoutingService<CliCommand, C> {
  @override
  String get group => '${super.group}.CliRoutingService';

  /// Resolves the same router registered under the core RoutingService contract.
  factory CliRoutingService() => Service.get<CliRoutingService<C>>();

  /// Constructor for custom CLI routing implementations.
  // Core's extension constructor is currently marked package-internal.
  // ignore: invalid_use_of_internal_member
  CliRoutingService.internal() : super.internal();

  /// Parses and executes an invocation on an already bootstrapped application.
  Future<CommandResult> run(List<String> arguments);

  /// Executes an already parsed selection; does not repeat parsing or bootstrap.
  Future<CommandResult> executeInvocation(CommandInvocation<C> invocation);
}
