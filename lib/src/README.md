# Create a CLI application

Extend `CliApp<AppConfig>` and pass the generated `AppConfig.defaults()` to its constructor. Declare commands and imports using the same module composition pattern as grumpy_flutter, then call `run(arguments)` and assign its result to the process exitCode.

The app handles help before loading configuration or activating modules. Normal invocations load global/local settings, resolve an immutable AppConfig snapshot, bootstrap dependencies, execute middleware and the selected handler, and await shutdown.

Use `AppConfig()` to access the injected snapshot. Use `ConfigService()` and generated setting handles for explicit persisted reads, writes, and provenance. Prompts and flags never write config automatically.

Override the app's service builders to change parsing, routing, config, prompts, filesystem access, terminal IO, signals, or runtime orchestration. Early dependencies receive declaration defaults; application bindings receive the resolved config. Keep declaration getters and constructors free of startup side effects.

Grumpy core owns module scopes and cleanup. One CLI app may run per isolate; use a fresh instance after shutdown. Commands should observe their cancellation token during long work and before side effects.

The package README and consuming example cover creating commands, generating configuration, sharing module config interfaces, and replacing infrastructure.
