# Command presentation

Like Flutter's `presentation/screens`, `presentation/commands` contains leaf
handlers. Execution context/result value types live in routing domain models. Route declarations live in the
routing feature; terminal presentation is handled by prompting and terminal IO.

```dart
class VersionCommand extends CliCommand {
  @override
  Future<CommandResult> execute(CommandContext context) async {
    context.terminal.writeln('1.0.0');
    return CommandResult.success;
  }
}
```

Declare typed arguments on the handler. Its `preview` and `content` methods return
itself without side effects. Only explicit command execution calls `execute`.

A `CommandContext` carries the original argv, typed parsed values, the middleware
route context, loaded configuration, prompts, terminal IO, and cancellation token.
Keep input fallback decisions explicit:

```dart
final port = context.args.provided(portOption) ??
    context.config.get(AppConfig.settings.port) ??
    await context.prompts.ask(ValuePrompt('Port', type: portType));
```

Returning a `CommandResult` does not terminate the process. The runner waits for
cleanup and returns an exit code. Put command data on stdout and interactive or
diagnostic text on stderr through the supplied terminal boundary.
