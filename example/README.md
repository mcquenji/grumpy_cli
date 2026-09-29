# Setup example

This is a consuming package with its own build_runner setup. Start in this directory:

```sh
fvm dart pub get
fvm dart run build_runner build
fvm dart run bin/main.dart --help
fvm dart run bin/main.dart config init
fvm dart run bin/main.dart config show
```

For unattended setup, supply `config init --name demo --port 9000`. Run `bin/memory.dart` instead of `bin/main.dart` to replace file access with in-memory storage.

The global and local models live under `lib/src/shared/domain/models`. `ServerConfig` illustrates a reusable package's required interface; generated `AppConfig` implements it through the global model. The generator also writes `schema.json` and `docs/configuration.md`.

`SETUP_DEMO_GLOBAL_DIR` and `SETUP_DEMO_LOCAL_DIR` override config directories for isolated runs. They are explicit example-app choices, not automatic environment-variable bindings in the adapter.

Run `fvm dart test` and `fvm dart run tool/generate_config_schema.dart --check` to verify generated config and persistence. In CI, regenerate with build_runner and reject diffs to the committed generated model, schema, and reference.
