import 'package:grumpy/grumpy.dart';
import 'dart:async';
import 'package:grumpy_cli/src/prompting/domain/services/prompt_renderer_service.dart';

/// A typed question definition, independent of terminal input ownership.
///
/// Submit definitions to `PromptService.ask`, which serializes prompts, pauses
/// progress, and restores terminal state. Non-interactive use fails unless the
/// definition explicitly permits a supplied default.
///
/// {@category prompting}
abstract class Prompt<T> extends Model {
  /// Defines a label, optional explanation/default, and non-interactive policy.
  const Prompt(
    this.label, {
    this.description = '',
    this.defaultValue,
    this.allowDefaultNonInteractive = false,
  });

  /// Question label and optional explanatory text shown on the diagnostic stream.
  final String label, description;

  /// Typed answer used for empty input or explicitly permitted unattended use.
  final T? defaultValue;

  /// Whether a supplied, validated default may be used without reading a terminal.
  final bool allowDefaultNonInteractive;

  /// Validates a typed answer, returning its normalized representation.
  ///
  /// Throws a usage error for invalid answers, allowing the service to retry.
  T validate(T value);

  /// Dispatches to a typed renderer within the service-owned session.
  ///
  /// Application code must call PromptService.ask so input remains serialized.
  Future<T> readWith(PromptRendererService renderer, bool raw);
}
