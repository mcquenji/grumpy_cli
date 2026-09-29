import 'dart:async';
import 'package:grumpy_cli/src/prompting/domain/models/prompt.dart';
import 'package:grumpy_cli/src/prompting/domain/services/prompt_renderer_service.dart';
import 'package:grumpy_cli/src/shared/domain/models/cli_value_type.dart';

/// A scalar or custom typed question using a shared value codec.
///
/// Invalid input displays a validation error and retries. Empty input accepts a
/// supplied default. Set `secret` to suppress echo, default display, and detailed
/// validation diagnostics that might disclose the value.
///
/// {@category prompting}
class ValuePrompt<T> extends Prompt<T> {
  /// Declares a typed value question with optional secret input.
  const ValuePrompt(
    super.label, {
    required this.type,
    super.description,
    super.defaultValue,
    super.allowDefaultNonInteractive,
    this.secret = false,
  });
  @override
  Future<T> readWith(PromptRendererService renderer, bool raw) =>
      renderer.readValue<T>(this);

  /// Shared codec applied to input text and default validation.
  final CliValueType<T> type;

  /// Suppresses echo, default display, and detailed validation error contents.
  final bool secret;
  @override
  T validate(T value) => type.check(value);
}
