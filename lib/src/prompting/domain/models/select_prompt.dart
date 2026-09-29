import 'dart:async';
import 'package:grumpy_cli/src/prompting/domain/models/prompt.dart';
import 'package:grumpy_cli/src/prompting/domain/models/prompt_choice.dart';
import 'package:grumpy_cli/src/prompting/domain/services/prompt_renderer_service.dart';
import 'package:grumpy_cli/src/prompting/utils/validate_prompt_choices.dart';
import 'package:grumpy_cli/src/shared/domain/exceptions/cli_usage_exception.dart';

/// One enabled choice returned as its typed value.
///
/// Choices must have distinct values and at least one enabled entry. A default
/// must itself be an enabled choice. The terminal renderer uses arrow keys when
/// ANSI is supported and numbered line input otherwise.
///
/// {@category prompting}
class SelectPrompt<T> extends Prompt<T> {
  /// Declares enabled choices and validates any supplied default.
  SelectPrompt(
    super.label, {
    required List<PromptChoice<T>> choices,
    super.description,
    super.defaultValue,
    super.allowDefaultNonInteractive,
  }) : choices = List.unmodifiable(choices) {
    validatePromptChoices(this.choices);
    if (defaultValue != null) validate(defaultValue as T);
  }
  @override
  Future<T> readWith(PromptRendererService renderer, bool raw) =>
      renderer.readSelect<T>(this, raw);

  /// Immutable choices in display order; values must be unique.
  final List<PromptChoice<T>> choices;
  @override
  T validate(T value) {
    if (!choices.any((c) => !c.disabled && c.value == value)) {
      throw const CliUsageException('Choose an enabled option.');
    }
    return value;
  }
}
