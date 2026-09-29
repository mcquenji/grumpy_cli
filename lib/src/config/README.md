# Application configuration

Declare `@config` and optional `@Config(.local)` models, then run grumpy_gen. The generated AppConfig implements your models and their inherited interfaces. Resolve it anywhere after bootstrap with `AppConfig()`.

Use nullable settings for first-run values a command will obtain from a flag or prompt. Non-nullable settings require statically evaluable defaults. Local files override all global values and may add local-only properties; duplicate declarations are rejected.

AppConfig is an immutable invocation snapshot. Use `ConfigService().global` or `.local` to explicitly read and change persisted scopes with generated `AppConfig.settings` handles. `explain` reports the effective source and file. Scope writes validate before persistence and never implicitly save CLI input.

Choose filenames, formats, and directory overrides in `ConfigFiles`. Local discovery searches ancestors and uses the invocation directory when creating a new file. JSON writes are formatted consistently; targeted YAML edits retain comments. Failed storage writes preserve the previous document and scope snapshot.

Replace configuration behavior through the app's config service, datasource, location, codec, or schema builders. Replace file access through `fileSystemServiceBuilder`, using the standard grumpy_io contract.

See the package README and the consuming example for generation, schema checks, explicit overrides, and guided setup.
