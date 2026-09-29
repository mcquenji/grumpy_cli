// GENERATED CODE - DO NOT MODIFY BY HAND.

import 'package:grumpy_cli/grumpy_cli.dart';
import "package:grumpy_cli_example/src/shared/domain/models/global_config.dart"
    as _c0;
import "package:grumpy_cli_example/src/shared/domain/models/local_config.dart"
    as _c1;

/// Immutable configuration resolved for the current application invocation.
final class AppConfig extends CliConfig<AppConfig>
    implements _c0.GlobalConfig, _c1.LocalConfig {
  AppConfig._({
    required this.checkForUpdates,
    required this.features,
    required this.port,
    required this.projectName,
  });

  /// Resolves the configuration registered by your root module.
  factory AppConfig() => RootModule.getConfig<AppConfig>();

  /// Creates a snapshot using the defaults declared by your config models.
  factory AppConfig.defaults() => AppConfig._(
    checkForUpdates: settings.checkForUpdates.defaultValue as bool,
    features: settings.features.defaultValue as List<String>,
    port: settings.port.defaultValue as int,
    projectName: settings.projectName.defaultValue as String?,
  );

  /// Typed handles for explicit scope writes, provenance and shared value types.
  static final settings = AppConfigSettings();

  /// Whether the tool may check for updates.
  @override
  final bool checkForUpdates;

  /// Enabled optional features.
  @override
  final List<String> features;

  /// Port on which the application listens.
  @override
  final int port;

  /// Display name of this project.
  @override
  final String? projectName;
  @override
  ConfigSchema get configSchema => _schema;
  static final _schema = ConfigSchema(
    global: [settings.checkForUpdates, settings.port],
    local: [settings.features, settings.projectName],
    schemaUri: Uri.parse("https://example.com/setup-demo/schema.json"),
  );

  @override
  AppConfig resolveConfig(ConfigService service) => AppConfig._(
    checkForUpdates: service.get(settings.checkForUpdates) as bool,
    features: service.get(settings.features) as List<String>,
    port: service.get(settings.port) as int,
    projectName: service.get(settings.projectName) as String?,
  );
}

/// Generated typed setting declarations; use AppConfig.settings.
final class AppConfigSettings extends Model {
  /// Creates the generated settings collection.
  AppConfigSettings();

  /// Whether the tool may check for updates.
  final checkForUpdates = ConfigSetting<bool>(
    "checkForUpdates",
    type: CliValueType.boolean(),
    description: "Whether the tool may check for updates.",
    defaultValue: CliValueType.boolean().decode(true),
    examples: [],
    hasDefault: true,
    deprecated: false,
  );

  /// Enabled optional features.
  final features = ConfigSetting<List<String>>(
    "features",
    type: CliValueType.list(CliValueType.string()),
    description: "Enabled optional features.",
    defaultValue: CliValueType.list(CliValueType.string()).decode([]),
    examples: [],
    hasDefault: true,
    deprecated: false,
  );

  /// Port on which the application listens.
  final port = ConfigSetting<int>(
    "port",
    type: CliValueType.integer().constrained({"minimum": 1, "maximum": 65535}),
    description: "Port on which the application listens.",
    defaultValue: CliValueType.integer()
        .constrained({"minimum": 1, "maximum": 65535})
        .decode(8080),
    examples: [
      CliValueType.integer()
          .constrained({"minimum": 1, "maximum": 65535})
          .decode(8080),
      CliValueType.integer()
          .constrained({"minimum": 1, "maximum": 65535})
          .decode(9000),
    ],
    hasDefault: true,
    deprecated: false,
  );

  /// Display name of this project.
  final projectName = ConfigSetting<String?>(
    "projectName",
    type: CliValueType.string().constrained({"minLength": 1}).nullable(),
    description: "Display name of this project.",
    defaultValue: CliValueType.string()
        .constrained({"minLength": 1})
        .nullable()
        .decode(null),
    examples: [],
    hasDefault: true,
    deprecated: false,
  );
}
