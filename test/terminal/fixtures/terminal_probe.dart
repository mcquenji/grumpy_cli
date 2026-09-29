import 'dart:convert';
import 'dart:io';
import 'package:grumpy_cli/grumpy_cli.dart';

Future<void> main() async {
  final terminal = StdioTerminalService();
  final prompts = createPrompts(terminal);
  try {
    final name = await prompts.text('Name');
    final password = await prompts.password('Password');
    final choices = [
      const PromptChoice('First', 1),
      const PromptChoice('Disabled', 2, disabled: true),
      const PromptChoice('Third', 3),
    ];
    final selected = await prompts.select('Choose one', choices: choices);
    final multiple = await prompts.multiSelect('Choose many', choices: choices);
    terminal.writeln(
      jsonEncode({
        'name': name,
        'passwordLength': password.length,
        'selected': selected,
        'multiple': multiple,
      }),
    );
  } on CliCancelled {
    exitCode = 130;
  } finally {
    await prompts.destroy();
    await terminal.destroy();
  }
}

PromptService createPrompts(
  TerminalService terminal, {
  CancellationToken? cancellation,
  bool nonInteractive = false,
}) {
  final token = cancellation ?? CancellationToken();
  return TerminalPromptService(
    terminal,
    cancellation: token,
    nonInteractive: nonInteractive,
    renderer: TerminalPromptRendererService(terminal, token),
  );
}
