import 'package:grumpy/grumpy.dart';

/// A display label and description associated with a typed selection value.
///
/// Labels are presentation only; callers receive `value`. Disabled choices remain
/// visible but cannot be selected or used as a default.
///
/// {@category prompting}
class PromptChoice<T> extends Model {
  /// Associates a typed value with its label, explanation, and enabled state.
  const PromptChoice(
    this.label,
    this.value, {
    this.description = '',
    this.disabled = false,
  });

  /// Visible label and optional additional explanation; neither is a return value.
  final String label, description;

  /// Typed result returned when this choice is selected.
  final T value;

  /// Whether the choice is visible but unavailable for selection.
  final bool disabled;
}
