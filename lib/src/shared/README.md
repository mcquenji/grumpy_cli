# Shared value and cancellation contracts

`domain/models` contains `CliValueType`, `ValueValidator`, and `CancellationToken`.
`domain/exceptions` contains the user-correctable usage and cancellation errors.
These contracts are shared by arguments, persisted settings, and prompts; they
must not depend on application startup or terminal presentation.

## Value conversion

Use one value type for every input source that represents the same concept:

```dart
final portType = CliValueType.integer(min: 1, max: 65535);
final port = portType.parse(environment['PORT']!);
```

`parse` consumes text, `decode` consumes serialized configuration values, and
`encode` produces configuration/schema values. Built-ins reject wrong config
types rather than coercing strings. Lists accept JSON text; repeated CLI options
parse individual elements instead. Object codecs validate serialized maps, then
call the developer's conversion functions.

Custom codecs supply JSON Schema constraints and an optional validator returning
an error string or null. Describe rules that cannot be represented by JSON Schema
with `runtimeValidationDescription`; those rules remain enforced at runtime.

## Cancellation

A token is one-shot and cooperative. `throwIfCancelled` guards a side effect;
`race` interrupts waiting but does not stop the underlying operation. Command code
must arrange its own cleanup. `CliCancelled` maps to 130 and must never be treated
as a false confirmation or empty selection. `CliUsageException` maps to 64.
