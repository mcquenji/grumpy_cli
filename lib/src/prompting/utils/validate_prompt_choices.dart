import 'package:meta/meta.dart';
import 'package:grumpy_cli/src/prompting/domain/models/prompt_choice.dart';

/// Rejects duplicate values or a menu without an enabled choice.
///
/// Runs during declaration construction, before any terminal state is changed.
@internal
void validatePromptChoices<T>(List<PromptChoice<T>> choices) {
  if (!choices.any((c) => !c.disabled) ||
      choices.map((c) => c.value).toSet().length != choices.length) {
    throw ArgumentError(
      'Choices must have unique values and at least one enabled option.',
    );
  }
}
