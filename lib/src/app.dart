import 'package:grumpy_io/grumpy_io.dart';
import 'config/domain/models/cli_config.dart';
import 'module/domain/services/cli_runtime_service.dart';
import 'module/infra/services/default_cli_runtime_service.dart';
import 'package:grumpy/grumpy.dart';
import 'package:grumpy_cli/src/arguments/domain/models/argument_schema.dart';
import 'package:grumpy_cli/src/arguments/domain/models/cli_flag.dart';
import 'package:grumpy_cli/src/config/domain/datasources/config_datasource.dart';
import 'package:grumpy_cli/src/config/domain/models/config_files.dart';
import 'package:grumpy_cli/src/config/domain/models/config_schema.dart';
import 'package:grumpy_cli/src/config/domain/services/config_codec_service.dart';
import 'package:grumpy_cli/src/config/domain/services/config_location_service.dart';
import 'package:grumpy_cli/src/config/domain/services/config_schema_service.dart';
import 'package:grumpy_cli/src/config/domain/services/config_service.dart';
import 'package:grumpy_cli/src/config/infra/datasources/file_config_datasource.dart';
import 'package:grumpy_cli/src/config/infra/services/default_config_schema_service.dart';
import 'package:grumpy_cli/src/config/infra/services/default_config_service.dart';
import 'package:grumpy_cli/src/config/infra/services/json_yaml_config_codec_service.dart';
import 'package:grumpy_cli/src/config/infra/services/platform_config_location_service.dart';
import 'module/domain/services/cli_binding_service.dart';
import 'module/infra/services/default_cli_binding_service.dart';
import 'package:grumpy_cli/src/presentation/commands/cli_command.dart';
import 'package:grumpy_cli/src/prompting/domain/services/prompt_renderer_service.dart';
import 'package:grumpy_cli/src/prompting/domain/services/prompt_service.dart';
import 'package:grumpy_cli/src/prompting/infra/services/terminal_prompt_renderer_service.dart';
import 'package:grumpy_cli/src/prompting/infra/services/terminal_prompt_service.dart';
import 'package:grumpy_cli/src/routing/domain/services/cli_routing_service.dart';
import 'package:grumpy_cli/src/routing/domain/services/command_parser_service.dart';
import 'package:grumpy_cli/src/routing/infra/services/args_command_parser_service.dart';
import 'package:grumpy_cli/src/routing/infra/services/default_cli_routing_service.dart';
import 'package:grumpy_cli/src/shared/domain/datasources/signal_datasource.dart';
import 'package:grumpy_cli/src/shared/domain/models/cancellation_token.dart';
import 'package:grumpy_cli/src/shared/infra/datasources/process_signal_datasource.dart';
import 'package:grumpy_cli/src/terminal/domain/services/terminal_service.dart';
import 'package:grumpy_cli/src/terminal/infra/services/stdio_terminal_service.dart';
import 'dart:async';
import 'package:get_it/get_it.dart' hide Disposable;
import 'package:meta/meta.dart';

/// Root module and process-lifecycle entry point for a command-line application.
///
/// Declare commands and imports in a subclass and pass AppConfig.defaults() to
/// its constructor. Generated configuration is resolved before modules activate.
/// `run` handles help before file access or DI, loads configuration, activates the
/// selected module graph, executes once, and awaits cleanup. Only one app may be
/// active per isolate; construct a fresh instance after shutdown.
///
/// ```dart
/// Future<void> main(List<String> arguments) async {
///   exitCode = await MyApp().run(arguments);
/// }
/// ```
///
/// {@category application}
abstract class CliApp<C extends Object> extends RootModule<CliCommand, C> {
  @override
  String get group => '${super.group}.CliApp';

  /// Creates an app; builders control runtime behavior and datasource selection.
  ///
  /// A supplied terminal is the default terminal builder's owned instance.
  CliApp(
    super.cfg, {
    TerminalService? terminal,
    CancellationToken? cancellation,
  }) : _suppliedTerminal = terminal,
       cancellation = cancellation ?? CancellationToken();
  final TerminalService? _suppliedTerminal;
  late final _services = _createBindings();
  CliBindingService<C> _createBindings() {
    final bindings = cliBindingServiceBuilder(cfg, GetIt.I.get);
    bindings.value<C>(cfg);
    bindings.value<CancellationToken>(cancellation);
    bindings.add<FileSystemService>(fileSystemServiceBuilder);
    bindings.add<TerminalService>(terminalServiceBuilder);
    bindings.add<CommandParserService<C>>(commandParserServiceBuilder);
    bindings.add<ConfigDatasource>(configDatasourceBuilder);
    bindings.add<ConfigLocationService>(configLocationServiceBuilder);
    bindings.add<ConfigCodecService>(configCodecServiceBuilder);
    bindings.add<ConfigSchemaService>(configSchemaServiceBuilder);
    bindings.add<ConfigService>(configServiceBuilder);
    bindings.add<PromptRendererService>(promptRendererServiceBuilder);
    bindings.add<PromptService>(promptServiceBuilder);
    bindings.add<SignalDatasource>(signalDatasourceBuilder);
    return bindings;
  }

  C? _resolvedConfig;
  @override
  C get cfg => _resolvedConfig ?? super.cfg;

  /// Installs the immutable snapshot before application bootstrap.
  void resolveConfiguration() {
    final defaults = cfg;
    if (defaults is CliConfig<C>) {
      _resolvedConfig = (defaults as CliConfig<C>).resolveConfig(config);
      _services.updateConfig(_resolvedConfig!);
    }
  }

  /// Supplies the configured CLI contracts to ordinary Grumpy module bindings.
  @override
  @mustCallSuper
  void bindServices(Bind<Service, C> bind) {
    super.bindServices(bind);
    bind<FileSystemService>((_, _) => _services.transfer<FileSystemService>());

    bind<CommandParserService<C>>(
      (_, _) => _services.transfer<CommandParserService<C>>(),
    );
    bind<ConfigLocationService>(
      (_, _) => _services.transfer<ConfigLocationService>(),
    );
    bind<ConfigCodecService>(
      (_, _) => _services.transfer<ConfigCodecService>(),
    );
    bind<ConfigSchemaService>(
      (_, _) => _services.transfer<ConfigSchemaService>(),
    );
    bind<ConfigService>((_, _) => _services.transfer<ConfigService>());
    bind<PromptRendererService>(
      (_, _) => _services.transfer<PromptRendererService>(),
    );
    bind<PromptService>((_, _) => _services.transfer<PromptService>());
  }

  @override
  @mustCallSuper
  void bindDatasources(Bind<Datasource, C> bind) {
    super.bindDatasources(bind);
    bind<ConfigDatasource>((_, _) => _services.transfer<ConfigDatasource>());
    bind<SignalDatasource>((_, _) => _services.transfer<SignalDatasource>());
  }

  @override
  @mustCallSuper
  void bindExternalDeps(Bind<Object, C> bind) {
    super.bindExternalDeps(bind);
    bindInstance<CancellationToken>(cancellation, owned: false);
    bindInstance<TerminalService>(terminal, owned: false);
    bindInstance<CliRuntimeService<C>>(runtime, owned: false);
    bindInstance<CliBindingService<C>>(_services, owned: false);
    GetIt.I.registerFactory<CliRoutingService<C>>(
      () => RoutingService<CliCommand, C>() as CliRoutingService<C>,
    );
  }

  /// Runs preflight, execution, and cleanup through the selected runtime service.
  Future<int> run(List<String> arguments) async {
    try {
      return await runtime.run(this, arguments);
    } finally {
      await runtime.onDispose();
    }
  }

  /// Application-owned execution coordinator, replaceable through its builder.
  late final CliRuntimeService<C> runtime = cliRuntimeServiceBuilder(
    cfg,
    _services.resolve,
  );

  /// Selects preflight assembly and ownership transfer into Grumpy modules.
  InjectableFactory<CliBindingService<C>, C> get cliBindingServiceBuilder =>
      (cfg, _) => DefaultCliBindingService<C>(cfg);

  /// Selects invocation orchestration without replacing modules or routing.
  InjectableFactory<CliRuntimeService<C>, C> get cliRuntimeServiceBuilder =>
      (_, _) => DefaultCliRuntimeService<C>();

  /// Releases resources created before bootstrap that were not transferred to DI.
  Future<void> releasePreflight() async => await _services.destroy();

  /// Cancellation events selected by the signal datasource builder.
  Stream<void> get cancellationEvents =>
      _services.resolve<SignalDatasource>().cancellations;

  /// Executable label for help and the default configuration application ID.
  String get executableName;

  /// Summary shown in root help output.
  String get description => '';

  /// Visible top-level commands and command groups, in help display order.
  List<Route<CliCommand, C>> get commands;

  /// Named options inherited by every command; positional app arguments are invalid.
  ArgumentSchema get arguments => const ArgumentSchema();

  /// Generated config declarations; override when supplying a custom config model.
  ConfigSchema get configuration =>
      cfg is CliConfig<C> ? (cfg as CliConfig<C>).configSchema : ConfigSchema();

  /// Formats and discovery policy for persisted settings.
  ConfigFiles get configFiles => ConfigFiles(applicationId: executableName);

  /// IO shared by command output, diagnostics, prompts, and progress.
  TerminalService get terminal => _services.resolve<TerminalService>();

  /// Cooperative cancellation token used by signals, prompts, and command code.
  final CancellationToken cancellation;

  /// Built-in `--non-interactive` handle inherited by all commands.
  ///
  /// This flag prohibits input; defaults still require per-prompt opt-in.
  static final nonInteractiveFlag = CliFlag(
    'non-interactive',
    negatable: false,
    description: 'Never ask interactive questions.',
  );

  /// Config service assembled by its builder, also registered in DI at bootstrap.
  ConfigService get config => _services.resolve<ConfigService>();

  /// Parser used before bootstrap; help never constructs config or prompt services.
  CommandParserService<C> get commandParser =>
      _services.resolve<CommandParserService<C>>();

  /// Shared prompt queue selected by promptServiceBuilder.
  PromptService get promptService => _services.resolve<PromptService>();
  @override
  @nonVirtual
  List<Route<CliCommand, C>> get routes => commands;
  @override
  Route<CliCommand, C> get root => Route(path: '/', children: routes);
  @override
  String get logTag => runtimeType.toString();

  /// Selects terminal IO; all prompts, diagnostics and output use this instance.
  InjectableFactory<TerminalService, C> get terminalServiceBuilder =>
      (_, _) => _suppliedTerminal ?? StdioTerminalService();

  /// Selects parsing/help behavior; constructed before config or module activation.
  InjectableFactory<CommandParserService<C>, C>
  get commandParserServiceBuilder =>
      (_, _) => ArgsCommandParserService<C>(
        executable: executableName,
        description: description,
        commands: List.unmodifiable(commands),
        nonInteractiveFlag: nonInteractiveFlag,
        arguments: arguments.inherit(
          ArgumentSchema(arguments: [nonInteractiveFlag]),
        ),
      );

  /// Selects the filesystem backend used for config discovery and persistence.
  InjectableFactory<FileSystemService, C> get fileSystemServiceBuilder =>
      (_, _) => DefaultFileSystemService();

  /// Selects persistence IO; custom stores may use memory, a database or remote IO.
  InjectableFactory<ConfigDatasource, C> get configDatasourceBuilder =>
      (_, resolve) =>
          FileConfigDatasource(fileSystemService: resolve<FileSystemService>());

  /// Selects path discovery independently from persistence and encoding.
  InjectableFactory<ConfigLocationService, C>
  get configLocationServiceBuilder =>
      (_, resolve) =>
          PlatformConfigLocationService(resolve<ConfigDatasource>());

  /// Selects config serialization and formatting.
  InjectableFactory<ConfigCodecService, C> get configCodecServiceBuilder =>
      (_, _) => JsonYamlConfigCodecService();

  /// Selects config artifact generation, sharing the chosen storage boundary.
  InjectableFactory<ConfigSchemaService, C> get configSchemaServiceBuilder =>
      (_, resolve) => DefaultConfigSchemaService(resolve<ConfigDatasource>());

  /// Selects effective config resolution and scope management.
  ///
  /// Loading occurs before module activation. Use the supplied resolver for CLI
  /// dependencies; constructors and load must not require module lifecycle hooks.
  InjectableFactory<ConfigService, C> get configServiceBuilder =>
      (_, resolve) => DefaultConfigService(
        schema: configuration,
        files: configFiles,
        datasource: resolve<ConfigDatasource>(),
        locations: resolve<ConfigLocationService>(),
        codec: resolve<ConfigCodecService>(),
      );

  /// Selects typed question rendering without replacing queue/lifecycle policy.
  InjectableFactory<PromptRendererService, C>
  get promptRendererServiceBuilder =>
      (_, resolve) => TerminalPromptRendererService(
        resolve<TerminalService>(),
        cancellation,
      );

  /// Selects prompt queueing/input behavior; contexts never construct fallback services.
  InjectableFactory<PromptService, C> get promptServiceBuilder =>
      (_, resolve) => TerminalPromptService(
        resolve<TerminalService>(),
        cancellation: cancellation,
        renderer: resolve<PromptRendererService>(),
      );

  /// Selects process/host cancellation events; help never subscribes to them.
  InjectableFactory<SignalDatasource, C> get signalDatasourceBuilder =>
      (_, _) => ProcessSignalDatasource();

  /// Replaces routing using the public CLI contract, with no concrete-type casts.
  @override
  InjectableFactory<CliRoutingService<C>, C> get routingServiceBuilder =>
      (_, resolve) => DefaultCliRoutingService<C>(
        root: root,
        bootstrapConfig: cfg,
        registry: resolve<ModuleRegistryService<CliCommand, C>>(),
        parser: resolve<CommandParserService<C>>(),
        config: resolve<ConfigService>(),
        prompts: resolve<PromptService>(),
        terminal: resolve<TerminalService>(),
        cancellation: cancellation,
      );
}
