# Typed prompts

`domain/models` contains typed definitions. `domain/services/PromptService` is the
DI contract and provides convenience methods in terms of its abstract `ask`.
`TerminalPromptService` supplies queueing and terminal-session ownership by default.
`PromptRendererService` is a separate public service contract; its default
`TerminalPromptRendererService` supplies scalar, numbered, and keyboard rendering.

Replace `promptServiceBuilder` for a different prompt policy, or replace
`promptRendererServiceBuilder` to change rendering while retaining queueing and
mode restoration. Both receive the same `TerminalService` selected by its builder.
Constructors are not used as implicit fallbacks in command execution.

## Definitions and values

Use `text`, `password`, `confirm`, `integer`, `decimal`, `select`, `multiSelect`, or
`ask(ValuePrompt(...))` for a shared custom codec. Choices pair display labels with
typed values. Disabled choices stay visible but cannot be selected or used as a
default. Multi-selection returns unique values in declaration order and validates
inclusive count bounds.

ANSI terminals use arrows, Enter, and Space. Other interactive terminals receive
numbered line input. Validation errors retry without losing ownership of stdin.
Initial choices and defaults are validated; a negative confirmation remains an
ordinary false value.

## IO lifecycle

The service serializes all prompts. It pauses progress, acquires the terminal,
reads through a renderer, and restores terminal/cursor state in finally blocks.
Custom renderers run within the session owned by PromptService. Applications
should invoke prompts through that service rather than call a renderer directly.

Non-interactive prompts fail without reading stdin unless that individual prompt
explicitly allows its supplied default. EOF, Escape, and cancellation throw
`CliCancelled`, never an empty or false answer. Password prompts suppress echo,
default display, and potentially sensitive validation diagnostics.

Destroying the prompt service cancels and drains its queue but does not close the
borrowed terminal. Prompting never persists answers; writes remain explicit.
