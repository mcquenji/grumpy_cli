# Terminal IO

`domain/services/TerminalService` is the injectable IO contract and
`domain/models/TerminalKey` normalizes keyboard input.
`infra/services/StdioTerminalService` is the native backend. Tests provide a fake
under `test/shared/harness` and use real POSIX pseudo terminals for native checks.

## Streams and capability detection

Command data goes to stdout. Prompts, progress, and diagnostics go to stderr.
Interactive capability requires stdin and diagnostics to be terminals; ANSI menu
support additionally depends on terminal escape support and TERM. Embedders may
supply explicit capability overrides. Non-interactive pipes never receive secret
prompt input automatically.

## Input ownership

A prompt saves echo/line modes, disables native echo, and owns stdin until its
finally cleanup. Scalar prompts manually echo only non-secret text, support
Backspace and Ctrl-U, and handle Ctrl-D as cancellation before the platform can
close the descriptor. UTF-8 input is decoded incrementally. Arrow escape sequences
are normalized for menu selection; Escape remains distinct from ordinary input.

`pauseProgress` and `resumeProgress` prevent progress output from interfering with
prompts. Cleanup restores modes and cursor visibility, cancels the input listener,
and flushes both output streams without closing process stdout/stderr.

## Native verification

```sh
fvm dart compile exe test/terminal/fixtures/terminal_probe.dart -o /tmp/grumpy-terminal-probe
python3 tool/test_terminal.py /tmp/grumpy-terminal-probe
```

The POSIX checks exercise numbered and keyboard menus, Unicode input, secret echo
suppression, cancellation, and terminal-mode restoration. Portable fake-IO tests
cover every public prompt type and the non-interactive contract.

## Replacing IO

Override `terminalServiceBuilder` with an implementation extending
`TerminalService.internal()`. `TerminalService()` resolves the registered instance
after bootstrap. Prompts, renderers and command contexts all borrow it; the app
retains ownership until final diagnostics are flushed. The optional app constructor
terminal is only a convenience input to the default builder.

Process signals use the separate `SignalDatasource` contract. Its default
`ProcessSignalDatasource` observes native signals lazily; embedded hosts can supply
their own cancellation stream without modifying command execution.
