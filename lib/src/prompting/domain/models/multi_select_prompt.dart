import 'dart:async';
import 'package:grumpy_cli/src/prompting/domain/models/prompt.dart';
import 'package:grumpy_cli/src/prompting/domain/models/prompt_choice.dart';
import 'package:grumpy_cli/src/prompting/domain/services/prompt_renderer_service.dart';
import 'package:grumpy_cli/src/prompting/utils/validate_prompt_choices.dart';
import 'package:grumpy_cli/src/shared/domain/exceptions/cli_usage_exception.dart';

/// A bounded selection of enabled values in declaration order.
///
/// The result contains unique values regardless of selection order. Initial
/// selections must be enabled, and acceptance validates the configured bounds.
/// Keyboard terminals use Space to toggle and Enter to confirm; simpler terminals
/// accept comma-separated choice numbers.
///
/// {@category prompting}
class MultiSelectPrompt<T> extends Prompt<List<T>> {
  /// Declares choices, initial selections, and inclusive selection bounds.
  ///
  /// The maximum defaults to the count of enabled choices. Bounds and initial
  /// choice membership are checked before prompting.
  MultiSelectPrompt(
    super.label, {
    required List<PromptChoice<T>> choices,
    super.description,
    List<T>? initialSelection,
    this.minSelections = 0,
    int? maxSelections,
    super.allowDefaultNonInteractive,
  }) : choices = List.unmodifiable(choices),
       maxSelections =
           maxSelections ?? choices.where((c) => !c.disabled).length,
       super(
         defaultValue: initialSelection == null
             ? null
             : List.unmodifiable(initialSelection),
       ) {
    validatePromptChoices(this.choices);
    if (minSelections < 0 ||
        this.maxSelections < minSelections ||
        this.maxSelections > choices.where((c) => !c.disabled).length) {
      throw ArgumentError('Invalid selection bounds.');
    }
    if (initialSelection != null &&
        initialSelection.any(
          (v) => !choices.any((c) => !c.disabled && c.value == v),
        )) {
      throw ArgumentError('Initial selections must be enabled choices.');
    }
  }
  @override
  Future<List<T>> readWith(PromptRendererService renderer, bool raw) =>
      renderer.readMultiSelect<T>(this, raw);

  /// Immutable choices in display order and result ordering.
  final List<PromptChoice<T>> choices;

  /// Inclusive minimum and maximum number of selected enabled values.
  final int minSelections, maxSelections;

  /// Rejects duplicates, disabled values, or out-of-range counts.
  ///
  /// Returns a unique immutable list ordered by the choice declarations.
  @override
  List<T> validate(List<T> values) {
    if (values.toSet().length != values.length) {
      throw const CliUsageException('Selections must be unique.');
    }
    if (values.any((v) => !choices.any((c) => !c.disabled && c.value == v))) {
      throw const CliUsageException('Choose enabled options only.');
    }
    if (values.length < minSelections || values.length > maxSelections) {
      throw CliUsageException(
        'Select $minSelections to $maxSelections options.',
      );
    }
    return List.unmodifiable(
      choices.where((c) => values.contains(c.value)).map((c) => c.value),
    );
  }
}
