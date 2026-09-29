# grumpy_cli

Build CLI tools with Grumpy modules, typed arguments, generated configuration, and prompts. Commands use the same dependency binding and service replacement patterns as a Grumpy Flutter application.

## Create an application

Define a global configuration model in your application's `lib/` source. Add a local model when the project needs additional settings:

```dart
@config
class GlobalConfig extends Model {
  const GlobalConfig({this.port = 8080});

  /// Port used by the server.
  @ConfigField(min: 1, max: 65535)
  final int port;
}

@Config(.local)
class LocalConfig extends Model {
  const LocalConfig({this.projectName});

  /// Display name of this project.
  final String? projectName;
}
```

Add `grumpy_gen` and `build_runner` as development dependencies, then run `fvm dart run build_runner build`. Import the generated `lib/src/shared/domain/models/app_config.g.dart` in your app and modules.

```dart
class App extends CliApp<AppConfig> {
  App() : super(AppConfig.defaults());

  @override
  String get executableName => 'my-tool';

  @override
  String get logTag => 'App';

  @override
  List<Route<CliCommand, AppConfig>> get commands => [
    CommandGroup(name: 'config', module: ConfigModule()),
  ];
}

Future<void> main(List<String> arguments) async {
  exitCode = await App().run(arguments);
}
```

See the complete [example application](example/lib/src/app.dart). Run it from `example/`:

```sh
fvm dart pub get
fvm dart run build_runner build
fvm dart run bin/main.dart --help
fvm dart run bin/main.dart config init --name demo --port 9000
fvm dart run bin/main.dart config show
fvm dart run tool/generate_config_schema.dart --check
```

## Modules and commands

Extend `CliModule<AppConfig>` to declare a feature's `commands`, `imports`, and dependency bindings. Mount it through `CommandGroup` to expose its commands. An imported service module supplies dependencies without adding a visible command group.

Extend `CliCommand` and implement `execute(CommandContext)`. Declare arguments with `CliFlag`, `CliOption<T>`, `CliMultiOption<T>`, `CliParameter<T>`, and `CliRestParameter<T>`. App and group options are inherited. Help and navigation never execute a handler.

```dart
final verbose = CliFlag('verbose', abbreviation: 'v');
final port = CliOption<int>('port', type: AppConfig.settings.port.type);

// In execute(): flags override config only when you explicitly choose that policy.
final selectedPort = context.args.provided(port) ?? AppConfig().port;
```

`provided()` reads explicit input only; `get()` also applies argument defaults, and `require()` reports missing values. An omitted flag differs from explicit `--no-feature`. Repeated options keep input order without implicitly splitting commas. `--` ends option parsing.

## Configuration

The generator discovers exactly one global model and an optional local model in your package's handwritten `lib/` source. It does not discover dependency models. Reusable packages expose interfaces and default mixins; your models implement those contracts, and generated `AppConfig` preserves them.

Property names must be unique across declarations. Every property needs a default or a nullable type. Descriptions come from Dartdoc, defaults from constant declarations or constructor parameters, and optional constraints from `@ConfigField`.

Local files can override **every** global setting and contain additional local settings. Resolution is local → global → declared default. False, zero, empty collections, and explicit nullable null remain values. Lists and objects replace the entire lower-precedence value.

```dart
final config = AppConfig(); // Same immutable snapshot injected into module builders.
final source = ConfigService().explain(AppConfig.settings.port);

await ConfigService().local.set(AppConfig.settings.port, 9000);
await ConfigService().local.remove(AppConfig.settings.port);
```

Writes always name a scope. They update the persisted view, while the injected `AppConfig` stays unchanged until the next invocation. Flags and prompt answers are never saved automatically.

Choose JSON/YAML filenames and directory overrides with `ConfigFiles`. Local discovery searches the nearest ancestor containing the configured file; new files use the invocation directory. Global discovery uses the platform user configuration directory. YAML edits preserve comments. IO uses the configured `grumpy_io` filesystem service and safe replacement.

Generated `schema.json` has global/local definitions for editor completion; `docs/configuration.md` lists the same settings. Configure artifact paths and a hosted schema URI in `grumpy_gen` builder options. Runtime validation never fetches the URI.

## Prompts

Use `context.prompts` for text, passwords, confirmations, integers, decimals, typed selections, multiselections, or custom `ValuePrompt` questions. Choices carry typed values independently of their display labels.

```dart
final name = AppConfig().projectName ?? await context.prompts.text('Project name');
final save = await context.prompts.confirm('Save these settings?');
if (save) await context.config.local.set(AppConfig.settings.projectName, name);
```

Prompts serialize access to stdin, restore terminal modes, and pause progress output. Interactive menus use keys when supported and numbered input otherwise. Cancellation/EOF raise `CliCancelled`. Noninteractive prompts fail unless that prompt explicitly allows its supplied default.

## Replace behavior

Override a builder to replace a domain contract. Constructors receive the app config and a resolver for dependencies; commands keep using the same contract.

```dart
@override
InjectableFactory<FileSystemService, AppConfig> get fileSystemServiceBuilder =>
    (_, _) => MemoryFileSystemService();
```

The [memory example](example/lib/src/shared/infra/services/memory_file_system_service.dart) replaces filesystem access while retaining the normal configuration service. Other builders replace routing, parsing, config storage/location/encoding, prompts/rendering, terminal IO, signals, or the invocation runtime. The module registry is the standard core registry.

Early parser/config-loading dependencies must work before module activation and receive declaration defaults. Dependencies constructed after config loading receive the resolved snapshot. Service constructors should only construct objects; initialize resources through lifecycle hooks where appropriate.

## Lifetime and checks

`run()` handles help, loads configuration, activates dependencies, executes once, and awaits shutdown. Use a fresh app for another process invocation. One application may run per isolate. Core owns module scopes and preserves unrelated DI registrations.

Command output goes to stdout; prompts and diagnostics go to stderr. Standard exit codes are success `0`, execution failure `1`, usage error `64`, and cancellation `130`.

`grumpy_lints` and public API documentation checks are enabled. Run `fvm dart analyze --fatal-infos`, `fvm dart test`, and the example's schema `--check` helper. CI should regenerate with build_runner and reject changes to committed generated artifacts.

## Sister packages

Explore the other packages in the Grumpy ecosystem:

| Package | Purpose |
| --- | --- |
| [grumpy](https://github.com/mcquenji/grumpy) | Core modules, repositories, routing, and lifecycle management. |
| [grumpy_annotations](https://github.com/mcquenji/grumpy_annotations) | Annotations for architecture rules and code generation. |
| [grumpy_flutter](https://github.com/mcquenji/grumpy_flutter) | Flutter components, screens, routing, and responsive views. |
| [grumpy_io](https://github.com/mcquenji/grumpy_io) | File system, networking, and other IO utilities. |
| [grumpy_gen](https://github.com/mcquenji/grumpy_gen) | Route and typed configuration code generation. |
| [grumpy_lints](https://github.com/mcquenji/grumpy_lints) | Analyzer rules for Grumpy architecture conventions. |
| [grumpy_context](https://github.com/mcquenji/grumpy_context) | Project discovery and shared generation configuration. |
| [grumpy_bricks](https://github.com/mcquenji/grumpy_bricks) | Mason bricks for generating Grumpy architecture units. |
| [grumpy_posthog](https://github.com/mcquenji/grumpy_posthog) | PostHog integration package scaffold (not yet implemented). |
| [grumpy_sentry](https://github.com/mcquenji/grumpy_sentry) | Sentry integration package scaffold (not yet implemented). |
