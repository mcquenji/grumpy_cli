import 'dart:async';
import 'package:grumpy_cli/grumpy_cli.dart';
import 'package:test/test.dart';
import '../../shared/harness/fake_terminal.dart';

enum Flavor { plain, mint, berry }

void main() {
  test('typed scalar prompts validate, retry and honor defaults', () async {
    final terminal = FakeTerminal(
      lines: ['hello', 'no', 'bad', '0', '42', '1.5', '', 'secret'],
    );
    final prompts = createPrompts(terminal);
    expect(await prompts.text('Name'), 'hello');
    expect(await prompts.confirm('Continue'), false);
    expect(await prompts.integer('Count', min: 1), 42);
    expect(await prompts.decimal('Ratio'), 1.5);
    expect(await prompts.text('Default', defaultValue: 'saved'), 'saved');
    expect(await prompts.password('Password'), 'secret');
    expect(terminal.secretInputs.last, true);
    expect(terminal.diagnostics.toString(), isNot(contains('secret')));
    expect(terminal.begins, 6);
    expect(terminal.ends, 6);
    expect(terminal.pauses, terminal.resumes);
    expect(terminal.output.isEmpty, true);
  });
  final choices = [
    const PromptChoice('Plain', Flavor.plain),
    const PromptChoice('Mint', Flavor.mint, disabled: true),
    const PromptChoice('Berry', Flavor.berry),
  ];
  test(
    'line selections reject disabled choices and return typed values',
    () async {
      final terminal = FakeTerminal(lines: ['2', '3', '3,1']);
      final prompts = createPrompts(terminal);
      expect(await prompts.select('Flavor', choices: choices), Flavor.berry);
      expect(
        await prompts.multiSelect(
          'Flavors',
          choices: choices,
          minSelections: 1,
        ),
        [Flavor.plain, Flavor.berry],
      );
    },
  );
  test(
    'keyboard menus skip disabled choices and multiselect follows declaration order',
    () async {
      final terminal = FakeTerminal(
        supportsAnsi: true,
        keys: [
          TerminalKey.down,
          TerminalKey.enter,
          TerminalKey.down,
          TerminalKey.space,
          TerminalKey.up,
          TerminalKey.space,
          TerminalKey.enter,
        ],
      );
      final prompts = createPrompts(terminal);
      expect(await prompts.select('Flavor', choices: choices), Flavor.berry);
      expect(await prompts.multiSelect('Flavors', choices: choices), [
        Flavor.plain,
        Flavor.berry,
      ]);
      expect(terminal.ends, 2);
    },
  );
  test(
    'multiselect retries selection bounds and validates initial values',
    () async {
      final prompts = createPrompts(FakeTerminal(lines: ['', '1,3']));
      expect(
        await prompts.multiSelect('Pick', choices: choices, minSelections: 2),
        [Flavor.plain, Flavor.berry],
      );
      expect(
        () => MultiSelectPrompt(
          'Bad',
          choices: choices,
          initialSelection: [Flavor.mint],
        ),
        throwsArgumentError,
      );
    },
  );
  test(
    'EOF, escape and cancellation are distinct from false or empty answers',
    () async {
      final terminal = FakeTerminal();
      await expectLater(
        createPrompts(terminal).confirm('Continue'),
        throwsA(isA<CliCancelled>()),
      );
      expect(terminal.ends, 1);
      expect(terminal.resumes, 1);
      final keyboard = FakeTerminal(
        supportsAnsi: true,
        keys: [TerminalKey.escape],
      );
      await expectLater(
        createPrompts(keyboard).select('Flavor', choices: choices),
        throwsA(isA<CliCancelled>()),
      );
      expect(keyboard.ends, 1);
      final pending = Completer<String?>();
      final token = CancellationToken();
      final blocked = FakeTerminal()..onRead = () => pending.future;
      final work = createPrompts(blocked, cancellation: token).text('Input');
      final assertion = expectLater(work, throwsA(isA<CliCancelled>()));
      await Future<void>.delayed(Duration.zero);
      token.cancel();
      await assertion;
      expect(blocked.ends, 1);
    },
  );
  test(
    'noninteractive input requires explicit permission to use a default',
    () async {
      final terminal = FakeTerminal(interactive: false);
      final prompts = createPrompts(terminal);
      await expectLater(
        prompts.integer('Port', defaultValue: 80),
        throwsA(isA<CliUsageException>()),
      );
      expect(
        await prompts.integer(
          'Port',
          defaultValue: 80,
          allowDefaultNonInteractive: true,
        ),
        80,
      );
      await expectLater(
        prompts.integer(
          'Port',
          defaultValue: 0,
          min: 1,
          allowDefaultNonInteractive: true,
        ),
        throwsA(isA<CliUsageException>()),
      );
      expect(terminal.begins, 0);
    },
  );
  test('queued prompts cannot overlap terminal ownership', () async {
    final terminal = FakeTerminal(lines: ['first', 'second']);
    final prompts = createPrompts(terminal);
    expect(await Future.wait([prompts.text('One'), prompts.text('Two')]), [
      'first',
      'second',
    ]);
    expect(terminal.begins, 2);
    expect(terminal.ends, 2);
  });
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
