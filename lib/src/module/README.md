# Modules and application lifetime

Extend CliModule with your generated AppConfig type. Declare dependencies in `imports`, register implementations through `bindServices`, `bindDatasources`, and `bindRepos`, and expose handlers through `commands`.

Mount a module using CommandGroup to make its commands visible. Importing a module contributes dependencies without adding a command group. Named module arguments are inherited by descendant commands.

CliModule uses the normal core lifecycle and canonical registry. Dependencies activate before their dependents. Application shutdown reverses that order, awaits disposal, and preserves unrelated DI scopes. Call super when overriding binding or lifecycle hooks.

Normally call `CliApp.run(arguments)` and return its exit code. The app loads generated configuration before activating application modules. Help only needs command declarations and output. A fresh application instance is required after shutdown; concurrent invocations are unsupported.

Override `cliRuntimeServiceBuilder` to replace invocation orchestration or `routingServiceBuilder` to replace command selection. Other service builders independently control parsing, config, prompts, terminal access, and signals.
