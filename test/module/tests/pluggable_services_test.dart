import 'dart:async';
import 'dart:convert';
import 'package:get_it/get_it.dart' hide Disposable;
import 'package:grumpy_cli/grumpy_cli.dart';
import 'package:test/test.dart';
import '../../shared/harness/fake_terminal.dart';

class AppOptions {}

final setting = ConfigSetting('name', type: CliValueType.string());

class MemoryStorage extends ConfigDatasource {
  MemoryStorage(this.events) : super.internal();
  final List<String> events;
  final documents = <String, String>{};
  bool failRead = false;
  int disposals = 0;
  @override
  String get logTag => 'MemoryStorage';
  @override
  Future<bool> exists(String path) async => documents.containsKey(path);
  @override
  Future<String?> read(String path) async {
    events.add('read:$path');
    if (failRead) throw StateError('storage unavailable');
    return documents[path];
  }

  @override
  Future<void> replace(String path, String contents, {String? expected}) async {
    expect(documents[path], expected);
    events.add('write:$path');
    documents[path] = contents;
  }

  @override
  Future<void> destroy() async {
    disposals++;
    events.add('dispose:storage');
  }
}

class VirtualLocations extends ConfigLocationService {
  VirtualLocations() : super.internal();
  @override
  String get logTag => 'VirtualLocations';
  @override
  String globalPath(ConfigFiles files) => 'virtual:global';
  @override
  Future<String> localPath(ConfigFiles files) async => 'virtual:local';
  @override
  Future<void> destroy() async {}
}

class TaggedCodec extends ConfigCodecService {
  TaggedCodec() : super.internal();
  int encodes = 0, decodes = 0;
  @override
  String get logTag => 'TaggedCodec';
  @override
  Map<String, Object?> decode(
    String? text, {
    required ConfigFormat format,
    required String source,
  }) {
    decodes++;
    return text == null
        ? {}
        : Map<String, Object?>.from(jsonDecode(text.substring(4)) as Map);
  }

  @override
  String encode(
    Map<String, Object?> values, {
    required ConfigFormat format,
    String? original,
    String? schemaReference,
  }) {
    encodes++;
    return 'mem:${jsonEncode(values)}';
  }

  @override
  Future<void> destroy() async {}
}

class HostSignals extends SignalDatasource {
  HostSignals() : super.internal();
  final controller = StreamController<void>();
  int disposals = 0;
  @override
  String get logTag => 'HostSignals';
  @override
  Stream<void> get cancellations => controller.stream;
  @override
  Future<void> destroy() async {
    disposals++;
    unawaited(controller.close());
  }
}

class ProgramCommand extends CliCommand {
  ProgramCommand(this.action);
  final Future<CommandResult> Function(CommandContext) action;
  @override
  Future<CommandResult> execute(CommandContext context) => action(context);
}

class PluginApp extends CliApp<AppOptions> {
  @override
  String get logTag => 'PluginApp';
  PluginApp(
    this.handler,
    this.storage,
    this.io, {
    this.codec,
    this.prompts,
    this.renderer,
    this.parser,
    this.router,
    this.registry,
    this.configOverride,
    this.failBinding = false,
  }) : super(AppOptions());
  final CliCommand handler;
  final MemoryStorage storage;
  final FakeTerminal io;
  final TaggedCodec? codec;
  final PromptService? prompts;
  final PromptRendererService? renderer;
  final CommandParserService<AppOptions>? parser;
  final CliRoutingService<AppOptions>? router;
  final ModuleRegistryService<CliCommand, AppOptions>? registry;
  final ConfigService? configOverride;
  final bool failBinding;
  final signals = HostSignals();
  @override
  String get executableName => 'plugins';
  @override
  List<Route<CliCommand, AppOptions>> get commands => [
    Command(name: 'run', handler: handler),
  ];
  @override
  ConfigSchema get configuration => ConfigSchema(global: [setting]);
  @override
  InjectableFactory<TerminalService, AppOptions> get terminalServiceBuilder =>
      (_, _) => io;
  @override
  InjectableFactory<ConfigDatasource, AppOptions> get configDatasourceBuilder =>
      (_, _) => storage;
  @override
  InjectableFactory<ConfigLocationService, AppOptions>
  get configLocationServiceBuilder =>
      (_, _) => VirtualLocations();
  @override
  InjectableFactory<ConfigCodecService, AppOptions>
  get configCodecServiceBuilder =>
      codec == null ? super.configCodecServiceBuilder : (_, _) => codec!;
  @override
  InjectableFactory<SignalDatasource, AppOptions> get signalDatasourceBuilder =>
      (_, _) => signals;
  @override
  InjectableFactory<PromptService, AppOptions> get promptServiceBuilder =>
      prompts == null ? super.promptServiceBuilder : (_, _) => prompts!;
  @override
  InjectableFactory<PromptRendererService, AppOptions>
  get promptRendererServiceBuilder => renderer == null
      ? super.promptRendererServiceBuilder
      : (_, _) => renderer!;
  @override
  InjectableFactory<CommandParserService<AppOptions>, AppOptions>
  get commandParserServiceBuilder =>
      parser == null ? super.commandParserServiceBuilder : (_, _) => parser!;
  @override
  InjectableFactory<CliRoutingService<AppOptions>, AppOptions>
  get routingServiceBuilder =>
      router == null ? super.routingServiceBuilder : (_, _) => router!;
  @override
  InjectableFactory<ModuleRegistryService<CliCommand, AppOptions>, AppOptions>
  get moduleRegistryServiceBuilder => registry == null
      ? super.moduleRegistryServiceBuilder
      : (_, _) => registry!;
  @override
  InjectableFactory<ConfigService, AppOptions> get configServiceBuilder =>
      configOverride == null
      ? super.configServiceBuilder
      : (_, _) => configOverride!;
  @override
  void bindExternalDeps(Bind<Object, AppOptions> bind) {
    super.bindExternalDeps(bind);
    if (failBinding) throw StateError('binding failure');
  }
}

class SuppliedAnswers extends PromptService {
  SuppliedAnswers() : super.internal();
  int calls = 0, disposals = 0;
  @override
  bool nonInteractive = false;
  @override
  String get logTag => 'SuppliedAnswers';
  @override
  Future<T> ask<T>(Prompt<T> prompt) async {
    calls++;
    return prompt.validate('service answer' as T);
  }

  @override
  Future<void> destroy() async {
    disposals++;
  }
}

class SuppliedRenderer extends PromptRendererService {
  SuppliedRenderer() : super.internal();
  int calls = 0, disposals = 0;
  @override
  String get logTag => 'SuppliedRenderer';
  @override
  Future<T> readValue<T>(ValuePrompt<T> prompt) async {
    calls++;
    return prompt.type.parse('rendered answer');
  }

  @override
  Future<T> readSelect<T>(SelectPrompt<T> prompt, bool raw) async =>
      prompt.choices.first.value;
  @override
  Future<List<T>> readMultiSelect<T>(
    MultiSelectPrompt<T> prompt,
    bool raw,
  ) async => prompt.validate([]);
  @override
  Future<void> destroy() async {
    disposals++;
  }
}

class AliasParser extends CommandParserService<AppOptions> {
  AliasParser(this.command) : super.internal();
  final Command<AppOptions> command;
  int calls = 0, disposals = 0;
  @override
  String get logTag => 'AliasParser';
  @override
  CommandInvocation<AppOptions> parse(List<String> arguments) {
    calls++;
    return CommandInvocation(
      path: ['run'],
      original: arguments,
      command: command,
      args: const ArgumentSchema().bind({}),
      help: arguments.contains('usage'),
      nonInteractive: true,
    );
  }

  @override
  CommandInvocation<AppOptions> select(String path) => parse([path]);
  @override
  String usage(CommandInvocation<AppOptions> invocation) => 'custom usage';
  @override
  Future<void> destroy() async {
    disposals++;
  }
}

class AlternateRouter extends CliRoutingService<AppOptions> {
  AlternateRouter() : super.internal();
  int calls = 0, disposals = 0;
  @override
  String get logTag => 'AlternateRouter';
  @override
  Route<CliCommand, AppOptions> get root => const Route(path: '/');
  @override
  RouteContext? get currentContext => null;
  @override
  Future<void> get currentNavigation async {}
  @override
  Future<void> navigate(
    String path, {
    bool skipPreview = false,
    void Function(CliCommand, bool) callback = RoutingService.noopCallback,
  }) async {}
  @override
  Future<CommandResult> run(List<String> arguments) async {
    calls++;
    return const CommandResult(23);
  }

  @override
  Future<CommandResult> executeInvocation(
    CommandInvocation<AppOptions> invocation,
  ) async {
    expect(CliRoutingService<AppOptions>(), same(this));
    expect(RoutingService<CliCommand, AppOptions>(), same(this));
    calls++;
    return const CommandResult(23);
  }

  @override
  bool isActive(String path, {bool exact = true, bool ignoreParams = false}) =>
      false;
  @override
  void addListener(void Function(Route<CliCommand, AppOptions>) listener) {}
  @override
  void removeListener(void Function(Route<CliCommand, AppOptions>) listener) {}
  @override
  Stream<ViewChangedEvent<CliCommand, AppOptions>> get viewStream =>
      const Stream.empty();
  @override
  StreamSubscription<ViewChangedEvent<CliCommand, AppOptions>> onViewChanged(
    void Function(ViewChangedEvent<CliCommand, AppOptions>) callback,
  ) => viewStream.listen(callback);
  @override
  Future<void> destroy() async {
    disposals++;
  }
}

// Independently implemented contract, not a subclass of the native registry.
class AlternateRegistry extends ModuleRegistryService<CliCommand, AppOptions> {
  AlternateRegistry() : super.internal();
  Module<CliCommand, AppOptions>? active;
  int stops = 0, disposals = 0;
  @override
  String get logTag => 'AlternateRegistry';
  @override
  Module<CliCommand, AppOptions> canonicalize(
    Module<CliCommand, AppOptions> module,
  ) => module;
  @override
  Module<CliCommand, AppOptions>? getByType(Type type) =>
      active?.runtimeType == type ? active : null;
  @override
  Map<Type, Module<CliCommand, AppOptions>> get modulesByType => {
    active.runtimeType: ?active,
  };
  @override
  Set<Module<CliCommand, AppOptions>> get activeModules => {?active};
  @override
  Map<Module<CliCommand, AppOptions>, Set<Module<CliCommand, AppOptions>>>
  get dependencyGraph => {};
  @override
  bool isActive(Module<CliCommand, AppOptions> module) =>
      identical(active, module);
  @override
  Set<Module<CliCommand, AppOptions>> resolveDependencies(
    Iterable<Module<CliCommand, AppOptions>> modules,
  ) => modules.toSet();
  @override
  Future<void> ensureActive(Module<CliCommand, AppOptions> module) async {
    active = module;
    await module.activate();
  }

  @override
  Future<void> ensureInactive(Module<CliCommand, AppOptions> module) async {
    await module.deactivate();
    active = null;
  }

  @override
  Future<void> forceDispose(Module<CliCommand, AppOptions> module) async {
    await module.destroy();
  }

  @override
  Future<void> sync(
    Iterable<Module<CliCommand, AppOptions>> requiredModules,
  ) async {
    expect(requiredModules, isEmpty);
  }

  @override
  Future<void> shutdown() async {
    stops++;
    await active?.deactivate();
    active = null;
  }

  @override
  Future<void> destroy() async {
    disposals++;
  }
}

class SuppliedConfig extends ConfigService {
  SuppliedConfig() : super.internal();
  bool loaded = false;
  int disposals = 0;
  @override
  String get logTag => 'SuppliedConfig';
  @override
  ConfigSchema get schema => ConfigSchema(local: [setting]);
  @override
  ConfigFiles get files => ConfigFiles(applicationId: 'supplied');
  @override
  ConfigScopeService get global => throw UnsupportedError('read-only');
  @override
  ConfigScopeService get local => throw UnsupportedError('read-only');
  @override
  Future<void> load() async {
    loaded = true;
  }

  @override
  ConfigExplanation<T> explain<T>(ConfigSetting<T> key) {
    expect(loaded, true);
    return ConfigExplanation(
      'remote config' as T,
      ConfigSource.local,
      file: 'remote:settings',
    );
  }

  @override
  Future<void> destroy() async {
    disposals++;
  }
}

class BrokenBuilderApp extends PluginApp {
  BrokenBuilderApp(
    super.handler,
    super.storage,
    super.io, {
    this.cycle = false,
  });
  final bool cycle;
  @override
  String get logTag => 'BrokenBuilderApp';
  @override
  InjectableFactory<ConfigService, AppOptions> get configServiceBuilder =>
      (_, resolve) {
        resolve<ConfigDatasource>();
        if (cycle) resolve<PromptService>();
        throw StateError('config builder failed');
      };
  @override
  InjectableFactory<PromptService, AppOptions> get promptServiceBuilder =>
      (_, resolve) {
        resolve<ConfigService>();
        throw StateError('unreachable cycle');
      };
}

void main() {
  setUp(() => GetIt.I.reset());
  tearDown(() => GetIt.I.reset());
  test(
    'storage, discovery and codec are replaceable and DI/context share instances',
    () async {
      final events = <String>[];
      final storage = MemoryStorage(events);
      final codec = TaggedCodec();
      storage.documents['virtual:global'] = 'mem:{"name":"global"}';
      final io = FakeTerminal();
      final command = ProgramCommand((ctx) async {
        expect(ConfigService(), same(ctx.config));
        expect(PromptService(), same(ctx.prompts));
        expect(TerminalService(), same(ctx.terminal));
        expect(ConfigDatasource(), same(storage));
        expect(ConfigCodecService(), same(codec));
        expect(ctx.config.get(setting), 'global');
        await ctx.config.local.set(setting, 'local');
        expect(ctx.config.get(setting), 'local');
        await ConfigSchemaService().generate(
          ctx.config.schema,
          schemaPath: 'virtual:schema',
        );
        expect(storage.documents['virtual:schema'], contains(r'$defs'));
        return CommandResult.success;
      });
      expect(
        await PluginApp(command, storage, io, codec: codec).run(['run']),
        0,
      );
      expect(storage.documents['virtual:local'], 'mem:{"name":"local"}');
      expect(codec.encodes, 1);
      expect(codec.decodes, greaterThan(1));
      expect(storage.disposals, 1);
      expect(io.disposals, 1);
    },
  );
  test(
    'entire config service can be replaced independently of default config implementation',
    () async {
      final supplied = SuppliedConfig();
      final storage = MemoryStorage([])..failRead = true;
      final command = ProgramCommand((ctx) async {
        expect(ctx.config, same(supplied));
        expect(ConfigService(), same(supplied));
        expect(ctx.config.require(setting), 'remote config');
        return CommandResult.success;
      });
      expect(
        await PluginApp(
          command,
          storage,
          FakeTerminal(),
          configOverride: supplied,
        ).run(['run']),
        0,
      );
      expect(storage.events, ['dispose:storage']);
      expect(supplied.disposals, 1);
    },
  );
  test(
    'replacing prompt service changes convenience methods and receives invocation policy',
    () async {
      final supplied = SuppliedAnswers();
      final io = FakeTerminal();
      final command = ProgramCommand((ctx) async {
        expect(ctx.prompts, same(supplied));
        expect(supplied.nonInteractive, true);
        expect(await ctx.prompts.text('Name'), 'service answer');
        return CommandResult.success;
      });
      expect(
        await PluginApp(
          command,
          MemoryStorage([]),
          io,
          prompts: supplied,
        ).run(['run', '--non-interactive']),
        0,
      );
      expect(supplied.calls, 1);
      expect(supplied.disposals, 1);
      expect(io.begins, 0);
    },
  );
  test(
    'replacing renderer keeps default queue and terminal ownership',
    () async {
      final renderer = SuppliedRenderer();
      final io = FakeTerminal();
      final command = ProgramCommand((ctx) async {
        expect(PromptRendererService(), same(renderer));
        expect(await ctx.prompts.text('Name'), 'rendered answer');
        return CommandResult.success;
      });
      expect(
        await PluginApp(
          command,
          MemoryStorage([]),
          io,
          renderer: renderer,
        ).run(['run']),
        0,
      );
      expect(renderer.calls, 1);
      expect(renderer.disposals, 1);
      expect(io.begins, 1);
      expect(io.ends, 1);
    },
  );
  test(
    'custom parser supplies a public invocation without default tree or flag handles',
    () async {
      var executions = 0;
      final command = ProgramCommand((ctx) async {
        expect(ctx.originalArguments, ['anything']);
        expect(ctx.prompts.nonInteractive, true);
        executions++;
        return CommandResult.success;
      });
      final parser = AliasParser(Command(name: 'run', handler: command));
      expect(
        await PluginApp(
          command,
          MemoryStorage([]),
          FakeTerminal(),
          parser: parser,
        ).run(['anything']),
        0,
      );
      expect(parser.calls, 1);
      expect(parser.disposals, 1);
      expect(executions, 1);
    },
  );
  test(
    'custom help does not construct config, prompts, signals or activate DI',
    () async {
      final command = ProgramCommand((_) async => fail('must not execute'));
      final parser = AliasParser(Command(name: 'run', handler: command));
      final storage = MemoryStorage([]);
      final io = FakeTerminal();
      final prompts = SuppliedAnswers();
      final app = PluginApp(
        command,
        storage,
        io,
        parser: parser,
        prompts: prompts,
      );
      GetIt.I.registerSingleton<String>('unrelated');
      expect(await app.run(['usage']), 0);
      expect(io.output.toString(), 'custom usage\n');
      expect(parser.disposals, 1);
      expect(storage.disposals, 0);
      expect(prompts.disposals, 0);
      expect(app.signals.disposals, 0);
      expect(GetIt.I<String>(), 'unrelated');
      expect(GetIt.I.currentScopeName, 'baseScope');
    },
  );
  test(
    'independent router and registry implementations replace defaults with no casts',
    () async {
      final router = AlternateRouter();
      final registry = AlternateRegistry();
      final command = ProgramCommand(
        (_) async => fail('replacement owns execution'),
      );
      final app = PluginApp(
        command,
        MemoryStorage([]),
        FakeTerminal(),
        router: router,
        registry: registry,
      );
      expect(await app.run(['run']), 23);
      expect(router.calls, 1);
      expect(router.disposals, 1);
      expect(registry.stops, 1);
      expect(registry.disposals, 1);
    },
  );
  test(
    'pre-bootstrap config failure and binding failure dispose replacements once',
    () async {
      for (final beforeBootstrap in [true, false]) {
        final storage = MemoryStorage([])..failRead = beforeBootstrap;
        final io = FakeTerminal();
        final app = PluginApp(
          ProgramCommand((_) async => CommandResult.success),
          storage,
          io,
          failBinding: !beforeBootstrap,
        );
        expect(await app.run(['run']), 1);
        expect(storage.disposals, 1);
        expect(io.disposals, 1);
        expect(app.signals.disposals, 1);
        expect(GetIt.I.isRegistered<ConfigService>(), false);
      }
    },
  );
  test('host signal datasource cancels commands and is cleaned up', () async {
    late PluginApp app;
    final command = ProgramCommand((ctx) async {
      expect(SignalDatasource(), same(app.signals));
      app.signals.controller.add(null);
      await ctx.cancellation.whenCancelled;
      ctx.cancellation.throwIfCancelled();
      return CommandResult.success;
    });
    app = PluginApp(command, MemoryStorage([]), FakeTerminal());
    expect(await app.run(['run']), 130);
    expect(app.signals.disposals, 1);
  });
  test(
    'failed and cyclic builders clean partially composed services without recursion',
    () async {
      for (final cycle in [false, true]) {
        final storage = MemoryStorage([]);
        final io = FakeTerminal();
        final app = BrokenBuilderApp(
          ProgramCommand((_) async => fail('must not execute')),
          storage,
          io,
          cycle: cycle,
        );
        expect(await app.run(['run']), 1);
        expect(storage.disposals, 1);
        expect(io.disposals, 1);
        expect(
          io.diagnostics.toString(),
          contains(
            cycle ? 'Circular CLI service dependency' : 'config builder failed',
          ),
        );
        expect(GetIt.I.isRegistered<ConfigService>(), false);
      }
    },
  );
}
