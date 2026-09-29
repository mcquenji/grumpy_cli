import 'dart:async';
import 'package:grumpy_cli/src/prompting/domain/models/multi_select_prompt.dart';
import 'package:grumpy_cli/src/prompting/domain/models/prompt_choice.dart';
import 'package:grumpy_cli/src/prompting/domain/models/select_prompt.dart';
import 'package:grumpy_cli/src/prompting/domain/models/value_prompt.dart';
import 'package:grumpy_cli/src/prompting/domain/services/prompt_renderer_service.dart';
import 'package:grumpy_cli/src/shared/domain/exceptions/cli_cancelled.dart';
import 'package:grumpy_cli/src/shared/domain/exceptions/cli_usage_exception.dart';
import 'package:grumpy_cli/src/shared/domain/models/cancellation_token.dart';
import 'package:grumpy_cli/src/terminal/domain/models/terminal_key.dart';
import 'package:grumpy_cli/src/terminal/domain/services/terminal_service.dart';

/// Renders scalar, numbered, and keyboard prompts within an owned IO session.
///
/// The prompt service owns queueing and mode restoration; this implementation
/// owns retries and presentation. It never writes command output or persists
/// answers. Replace through promptRendererServiceBuilder; invoke through PromptService
/// so all render calls share the prompt queue.
class TerminalPromptRendererService extends PromptRendererService {
  /// Creates a renderer borrowing the terminal session and cancellation token.
  TerminalPromptRendererService(this.terminal, this.cancellation)
    : super.internal();
  @override
  String get logTag => 'TerminalPromptRendererService';

  /// Borrowed IO already acquired by the prompt service.
  final TerminalService terminal;

  /// Token observed on every read and before returning answers.
  final CancellationToken cancellation;
  Future<String> _line() async {
    final line = await terminal.readLine(cancellation: cancellation);
    if (line == null) throw const CliCancelled();
    cancellation.throwIfCancelled();
    return line;
  }

  Future<TerminalKey> _key() async {
    final key = await terminal.readKey(cancellation: cancellation);
    if (key == null || key == TerminalKey.escape) throw const CliCancelled();
    cancellation.throwIfCancelled();
    return key;
  }

  @override
  Future<T> readValue<T>(ValuePrompt<T> prompt) async {
    while (true) {
      terminal.writeError(
        '${prompt.label}${!prompt.secret && prompt.defaultValue != null ? ' [${prompt.defaultValue}]' : ''}: ',
      );
      final line = await _line();
      if (prompt.secret) terminal.errorln();
      try {
        return line.isEmpty && prompt.defaultValue != null
            ? prompt.validate(prompt.defaultValue as T)
            : prompt.type.parse(line);
      } on CliUsageException catch (e) {
        terminal.errorln(
          prompt.secret ? 'Invalid value. Please try again.' : e.message,
        );
      }
    }
  }

  void _list<T>(String label, List<PromptChoice<T>> choices) {
    terminal.errorln(label);
    for (var i = 0; i < choices.length; i++) {
      final c = choices[i];
      terminal.errorln(
        '  ${i + 1}. ${c.label}${c.disabled ? ' (disabled)' : ''}${c.description.isEmpty ? '' : ' — ${c.description}'}',
      );
    }
  }

  void _menu<T>(
    String label,
    List<PromptChoice<T>> choices,
    int index,
    Set<T>? selected,
    bool redraw,
    String? error,
  ) {
    if (redraw) terminal.writeError('\x1b[${choices.length + 2}A');
    terminal.writeError('\r\x1b[2K$label\n');
    for (var i = 0; i < choices.length; i++) {
      final c = choices[i];
      terminal.writeError(
        '\r\x1b[2K${i == index ? '>' : ' '} ${selected == null
            ? ''
            : selected.contains(c.value)
            ? '[x] '
            : '[ ] '}${c.label}${c.disabled ? ' (disabled)' : ''}${c.description.isEmpty ? '' : ' — ${c.description}'}\n',
      );
    }
    terminal.writeError(
      '\r\x1b[2K${error ?? (selected == null ? '↑/↓ move · Enter select' : '↑/↓ move · Space toggle · Enter confirm')}\n',
    );
  }

  int _move<T>(List<PromptChoice<T>> choices, int index, int direction) {
    do {
      index = (index + direction + choices.length) % choices.length;
    } while (choices[index].disabled);
    return index;
  }

  @override
  Future<T> readSelect<T>(SelectPrompt<T> prompt, bool raw) async {
    if (raw) {
      var index = prompt.defaultValue == null
          ? prompt.choices.indexWhere((c) => !c.disabled)
          : prompt.choices.indexWhere((c) => c.value == prompt.defaultValue);
      var redraw = false;
      while (true) {
        _menu(prompt.label, prompt.choices, index, null, redraw, null);
        redraw = true;
        switch (await _key()) {
          case TerminalKey.up:
            index = _move(prompt.choices, index, -1);
          case TerminalKey.down:
            index = _move(prompt.choices, index, 1);
          case TerminalKey.enter:
            return prompt.validate(prompt.choices[index].value);
          default:
            break;
        }
      }
    }
    _list(prompt.label, prompt.choices);
    while (true) {
      terminal.writeError(
        'Selection${prompt.defaultValue == null ? '' : ' [${prompt.choices.indexWhere((c) => c.value == prompt.defaultValue) + 1}]'}: ',
      );
      final line = await _line();
      if (line.isEmpty && prompt.defaultValue != null) {
        return prompt.validate(prompt.defaultValue as T);
      }
      final index = int.tryParse(line);
      if (index != null &&
          index > 0 &&
          index <= prompt.choices.length &&
          !prompt.choices[index - 1].disabled) {
        return prompt.choices[index - 1].value;
      }
      terminal.errorln('Enter the number of an enabled option.');
    }
  }

  @override
  Future<List<T>> readMultiSelect<T>(
    MultiSelectPrompt<T> prompt,
    bool raw,
  ) async {
    if (raw) {
      final selected = <T>{...?prompt.defaultValue};
      var index = prompt.choices.indexWhere((c) => !c.disabled), redraw = false;
      String? error;
      while (true) {
        _menu(prompt.label, prompt.choices, index, selected, redraw, error);
        redraw = true;
        error = null;
        switch (await _key()) {
          case TerminalKey.up:
            index = _move(prompt.choices, index, -1);
          case TerminalKey.down:
            index = _move(prompt.choices, index, 1);
          case TerminalKey.space:
            final value = prompt.choices[index].value;
            if (!selected.remove(value)) selected.add(value);
          case TerminalKey.enter:
            try {
              return prompt.validate(selected.toList());
            } on CliUsageException catch (e) {
              error = e.message;
            }
          default:
            break;
        }
      }
    }
    _list(prompt.label, prompt.choices);
    while (true) {
      terminal.writeError(
        'Selections (comma-separated numbers)${prompt.defaultValue == null ? '' : ' [${prompt.choices.indexed.where((e) => prompt.defaultValue!.contains(e.$2.value)).map((e) => e.$1 + 1).join(',')}]'}: ',
      );
      final line = await _line();
      try {
        if (line.isEmpty) return prompt.validate(prompt.defaultValue ?? <T>[]);
        final indexes = line
            .split(',')
            .map((s) => int.tryParse(s.trim()))
            .toList();
        if (indexes.any(
          (i) => i == null || i < 1 || i > prompt.choices.length,
        )) {
          throw const CliUsageException('Enter valid choice numbers.');
        }
        return prompt.validate(
          indexes.map((i) => prompt.choices[i! - 1].value).toList(),
        );
      } on CliUsageException catch (e) {
        terminal.errorln(e.message);
      }
    }
  }

  @override
  Future<void> destroy() async {}
}
