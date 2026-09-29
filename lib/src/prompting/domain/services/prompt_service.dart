import 'package:grumpy/grumpy.dart';
import 'package:grumpy_cli/src/prompting/domain/models/multi_select_prompt.dart';
import 'package:grumpy_cli/src/prompting/domain/models/prompt.dart';
import 'package:grumpy_cli/src/prompting/domain/models/prompt_choice.dart';
import 'package:grumpy_cli/src/prompting/domain/models/select_prompt.dart';
import 'package:grumpy_cli/src/prompting/domain/models/value_prompt.dart';
import 'package:grumpy_cli/src/shared/domain/models/cli_value_type.dart';

/// Serializes typed questions while preserving cancellation and unattended-input rules.
///
/// Resolve the registered implementation with `PromptService()` or replace its app builder.
abstract class PromptService extends Service {
  /// Resolves the implementation registered under this domain contract.
  factory PromptService() => Service.get<PromptService>();

  /// Constructor for independently implemented adapters.
  PromptService.internal();

  @override
  bool get singelton => true;
  @override
  String get group => '${super.group}.PromptService';

  /// Whether all prompts must obey the non-interactive policy.
  bool get nonInteractive;

  /// Updates invocation-level unattended behavior before asking a question.
  set nonInteractive(bool value);

  /// Asks a definition once; implementations own queueing, validation and cleanup.
  Future<T> ask<T>(Prompt<T> prompt);

  /// Asks for text, optionally using custom string constraints and a default.
  Future<String> text(
    String label, {
    String? defaultValue,
    CliValueType<String>? type,
    String description = '',
    bool allowDefaultNonInteractive = false,
  }) => ask(
    ValuePrompt(
      label,
      type: type ?? CliValueType.string(),
      description: description,
      defaultValue: defaultValue,
      allowDefaultNonInteractive: allowDefaultNonInteractive,
    ),
  );

  /// Asks for secret text with echo disabled and sanitized validation errors.
  ///
  /// No default is accepted automatically; a real interactive terminal is required.
  Future<String> password(
    String label, {
    CliValueType<String>? type,
    String description = '',
  }) => ask(
    ValuePrompt(
      label,
      type: type ?? CliValueType.string(),
      description: description,
      secret: true,
    ),
  );

  /// Asks for a boolean; false is an ordinary answer, never cancellation.
  Future<bool> confirm(
    String label, {
    bool? defaultValue,
    String description = '',
    bool allowDefaultNonInteractive = false,
  }) => ask(
    ValuePrompt(
      label,
      type: CliValueType.boolean(),
      description: description,
      defaultValue: defaultValue,
      allowDefaultNonInteractive: allowDefaultNonInteractive,
    ),
  );

  /// Asks for an integer with optional inclusive bounds and a default.
  Future<int> integer(
    String label, {
    int? min,
    int? max,
    int? defaultValue,
    String description = '',
    bool allowDefaultNonInteractive = false,
  }) => ask(
    ValuePrompt(
      label,
      type: CliValueType.integer(min: min, max: max),
      description: description,
      defaultValue: defaultValue,
      allowDefaultNonInteractive: allowDefaultNonInteractive,
    ),
  );

  /// Asks for a finite double with optional inclusive bounds and a default.
  Future<double> decimal(
    String label, {
    double? min,
    double? max,
    double? defaultValue,
    String description = '',
    bool allowDefaultNonInteractive = false,
  }) => ask(
    ValuePrompt(
      label,
      type: CliValueType.decimal(min: min, max: max),
      description: description,
      defaultValue: defaultValue,
      allowDefaultNonInteractive: allowDefaultNonInteractive,
    ),
  );

  /// Asks for one enabled typed choice using keys or numbered line input.
  Future<T> select<T>(
    String label, {
    required List<PromptChoice<T>> choices,
    T? defaultValue,
    String description = '',
    bool allowDefaultNonInteractive = false,
  }) => ask(
    SelectPrompt(
      label,
      choices: choices,
      description: description,
      defaultValue: defaultValue,
      allowDefaultNonInteractive: allowDefaultNonInteractive,
    ),
  );

  /// Asks for unique enabled values and returns them in declaration order.
  ///
  /// Initial selections and inclusive bounds are checked by the definition.
  Future<List<T>> multiSelect<T>(
    String label, {
    required List<PromptChoice<T>> choices,
    List<T>? initialSelection,
    int minSelections = 0,
    int? maxSelections,
    String description = '',
    bool allowDefaultNonInteractive = false,
  }) => ask(
    MultiSelectPrompt(
      label,
      choices: choices,
      initialSelection: initialSelection,
      minSelections: minSelections,
      maxSelections: maxSelections,
      description: description,
      allowDefaultNonInteractive: allowDefaultNonInteractive,
    ),
  );
}
