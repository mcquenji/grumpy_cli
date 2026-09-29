import 'package:grumpy/grumpy.dart';
import 'package:grumpy_cli/src/prompting/domain/models/multi_select_prompt.dart';
import 'package:grumpy_cli/src/prompting/domain/models/select_prompt.dart';
import 'package:grumpy_cli/src/prompting/domain/models/value_prompt.dart';

/// Typed rendering within the prompt service's serialized input session.
///
/// Resolve the registered implementation with `PromptRendererService()` or replace its app builder.
abstract class PromptRendererService extends Service {
  /// Resolves the implementation registered under this domain contract.
  factory PromptRendererService() => Service.get<PromptRendererService>();

  /// Constructor for independently implemented adapters.
  PromptRendererService.internal();

  @override
  bool get singelton => true;
  @override
  String get group => '${super.group}.PromptRendererService';

  /// Reads and validates a scalar; must never acquire a competing input session.
  Future<T> readValue<T>(ValuePrompt<T> prompt);

  /// Reads an enabled typed choice, using keyboard input when raw is true.
  Future<T> readSelect<T>(SelectPrompt<T> prompt, bool raw);

  /// Reads unique enabled values in declaration order, validating count bounds.
  Future<List<T>> readMultiSelect<T>(MultiSelectPrompt<T> prompt, bool raw);
}
