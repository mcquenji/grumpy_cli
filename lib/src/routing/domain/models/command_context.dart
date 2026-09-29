import 'package:grumpy/grumpy.dart';
import 'package:grumpy_cli/src/arguments/domain/models/parsed_arguments.dart';
import 'package:grumpy_cli/src/config/domain/services/config_service.dart';
import 'package:grumpy_cli/src/prompting/domain/services/prompt_service.dart';
import 'package:grumpy_cli/src/shared/domain/models/cancellation_token.dart';
import 'package:grumpy_cli/src/terminal/domain/services/terminal_service.dart';

/// Typed inputs and services for one explicit command invocation.
///
/// Bindings are deliberately explicit: read `args.provided(option)`, then a config
/// setting, then prompt when necessary. Prompt answers and argument values are
/// never persisted automatically. Check `cancellation` before committing changes.
///
/// {@category presentation}
class CommandContext extends Model {
  /// Creates a context with a defensive copy of the original argv tokens.
  CommandContext({
    required List<String> originalArguments,
    required this.args,
    required this.route,
    required this.config,
    required this.terminal,
    required this.prompts,
    required this.cancellation,
  }) : originalArguments = List.unmodifiable(originalArguments);

  /// Original unsplit argv tokens, including command names and option syntax.
  final List<String> originalArguments;

  /// Validated typed arguments with explicit-presence tracking.
  final ParsedArguments args;

  /// Selected core route context after middleware has run.
  final RouteContext route;

  /// Loaded persistent settings; writes require an explicitly named scope.
  final ConfigService config;

  /// Output and progress boundary shared with the application.
  final TerminalService terminal;

  /// Serialized typed prompt service for missing interactive input.
  final PromptService prompts;

  /// Shared token to check during long-running work and before writes.
  final CancellationToken cancellation;
}
