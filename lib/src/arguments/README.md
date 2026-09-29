# Typed command arguments

`domain/models` contains declaration handles, `ArgumentSchema`, and the immutable
`ParsedArguments` result. Import the package facade in application code; the
feature and layer barrels follow the same organization as Grumpy core.

## Declare once, read by handle

```dart
final port = CliOption<int>(
  'port',
  type: CliValueType.integer(min: 1, max: 65535),
  defaultValue: 8080,
);
final feature = CliFlag('feature', defaultValue: true);
final schema = ArgumentSchema(arguments: [port, feature]);
final args = schema.parse(['--no-feature']);
assert(args.provided(port) == null);
assert(args.get(port) == 8080);
assert(args.provided(feature) == false);
```

Handles are compared by identity. `provided` reads explicit input only; `get`
adds a default; `require` raises a usage error when neither supplies a value.
Presence relationships also use explicit input, including a negated flag.

## Parsing contracts

- App and group declarations contribute named options to their descendants.
- Names, aliases, abbreviations and generated `no-` aliases cannot conflict.
- Required positional values precede optional values; rest parameters come last.
- Scalar options use the final occurrence. Repeated options retain input order
  across command levels and never split values on commas.
- `--` ends option parsing. Pass original argv tokens without reconstruction.
- Mutually exclusive and dependent arguments reference the original handles.

`buildParser` and `fromResults` are adapter integration boundaries. Application
commands should use typed declarations rather than constructing an `args` parser.
Declaration mistakes throw `ArgumentError`; invalid user input throws a
`CliUsageException`. Declaration access must remain free of DI and file IO so
help works before application startup.

## Alternate command parsers

Implement `CommandParserService` and exchange public `CommandInvocation` values.
Use `ArgumentSchema.bind({handle: typedValue})` to validate already converted
values, required inputs and relationships without using the default args parser.
It retains explicit presence and leaves declared defaults for resolved accessors.
