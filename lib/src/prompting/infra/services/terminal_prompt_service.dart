import 'package:grumpy_cli/src/prompting/domain/models/multi_select_prompt.dart';
import 'package:grumpy_cli/src/prompting/domain/models/prompt.dart';
import 'package:grumpy_cli/src/prompting/domain/models/select_prompt.dart';
import 'package:grumpy_cli/src/prompting/domain/models/value_prompt.dart';
import 'package:grumpy_cli/src/prompting/domain/services/prompt_renderer_service.dart';
import 'package:grumpy_cli/src/prompting/domain/services/prompt_service.dart';
import 'package:grumpy_cli/src/shared/domain/exceptions/cli_usage_exception.dart';
import 'package:grumpy_cli/src/shared/domain/models/cancellation_token.dart';
import 'package:grumpy_cli/src/terminal/domain/services/terminal_service.dart';

/// Serializes typed prompts over injectable terminal IO.
///
/// Use convenience methods or submit a definition through `ask`. Every prompt
/// pauses progress and restores terminal ownership in a finally block, including
/// validation errors, EOF, and cancellation. Prompts use the diagnostic stream,
/// leaving stdout available for command data.
///
/// A non-interactive prompt never reads input. It may return a validated default
/// only when that individual definition explicitly opts in.
///
/// {@category prompting}
class TerminalPromptService extends PromptService {
  /// Creates one prompt queue over the supplied terminal and cancellation token.
  TerminalPromptService(
    this.terminal, {
    required this.cancellation,
    required this.renderer,
    this.nonInteractive = false,
  }) : super.internal();

  /// IO session shared by this service's prompts and progress rendering.
  final TerminalService terminal;

  /// Cooperative token observed before and during input.
  final CancellationToken cancellation;

  /// Whether prompting is prohibited even when a terminal is attached.
  @override
  bool nonInteractive;

  /// Renderer borrowed from DI; swapping it changes terminal presentation only.
  final PromptRendererService renderer;
  Future<void> _pending = Future.value();
  @override
  bool get singelton => true;
  @override
  String get logTag => 'TerminalPromptService';

  /// Queues a typed question and returns its validated answer.
  ///
  /// Invalid input retries; EOF or Escape raises CliCancelled. Non-interactive
  /// input fails immediately unless the definition explicitly permits a default.
  /// Prompts queued after a failed prompt can still run unless cancellation is set.
  @override
  Future<T> ask<T>(Prompt<T> prompt) {
    final work = _pending.then((_) => _ask(prompt));
    _pending = work.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return work;
  }

  Future<T> _ask<T>(Prompt<T> prompt) async {
    cancellation.throwIfCancelled();
    if (nonInteractive || !terminal.interactive) {
      if (prompt.allowDefaultNonInteractive && prompt.defaultValue != null) {
        return prompt.validate(prompt.defaultValue as T);
      }
      throw CliUsageException(
        'Cannot prompt for "${prompt.label}" in non-interactive mode. Supply the value explicitly.',
      );
    }
    final isChoice = prompt is SelectPrompt || prompt is MultiSelectPrompt;
    final raw = isChoice && terminal.supportsAnsi;
    terminal.pauseProgress();
    var began = false;
    try {
      terminal.beginPrompt(
        raw: raw,
        secret: prompt is ValuePrompt && (prompt as ValuePrompt).secret,
      );
      began = true;
      if (prompt.description.isNotEmpty) terminal.errorln(prompt.description);
      return await prompt.readWith(renderer, raw);
    } finally {
      try {
        if (began) terminal.endPrompt();
      } finally {
        terminal.resumeProgress();
      }
    }
  }

  /// Cancels pending input and awaits the queue so terminal cleanup finishes.
  ///
  /// Does not destroy the terminal; its owner is responsible for final IO cleanup.
  @override
  Future<void> destroy() async {
    cancellation.cancel();
    await _pending;
  }
}
