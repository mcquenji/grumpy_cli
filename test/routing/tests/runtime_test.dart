import 'dart:async';
import 'dart:io';
import 'package:get_it/get_it.dart' hide Disposable;
import 'package:grumpy_cli/grumpy_cli.dart';
import 'package:test/test.dart';
import '../../shared/harness/fake_terminal.dart';

class TestConfig {}

class TestCommand extends CliCommand {
  TestCommand(this.action, {this.arguments = const ArgumentSchema()});
  final Future<CommandResult> Function(CommandContext) action;
  @override
  final ArgumentSchema arguments;
  @override
  Future<CommandResult> execute(CommandContext context) => action(context);
}

class TestModule extends CliModule<TestConfig> {
  TestModule(this.handler, {this.arguments = const ArgumentSchema()});
  final CliCommand handler;
  @override
  final ArgumentSchema arguments;
  int activations = 0, destructions = 0;
  @override
  String get logTag => 'TestModule';
  @override
  List<Route<CliCommand, TestConfig>> get commands => [
    Command(name: 'init', handler: handler, description: 'Initialize settings'),
  ];
  @override
  Future<void> activate() async {
    await super.activate();
    activations++;
  }

  @override
  Future<void> destroy() async {
    destructions++;
    await super.destroy();
  }
}

class TestApp extends CliApp<TestConfig> {
  TestApp(
    this.module,
    this.directory, {
    required super.terminal,
    this.failBinding = false,
    this.middleware = const [],
    this.arguments = const ArgumentSchema(),
  }) : super(TestConfig());
  final TestModule module;
  final String directory;
  final bool failBinding;
  final List<Middleware<CliCommand, TestConfig>> middleware;
  @override
  final ArgumentSchema arguments;
  @override
  String get logTag => 'TestApp';
  @override
  String get executableName => 'demo';
  @override
  String get description => 'Demo CLI';
  @override
  List<Route<CliCommand, TestConfig>> get commands => [
    CommandGroup(
      name: 'config',
      module: module,
      middleware: middleware,
      description: 'Configure local',
    ),
  ];
  @override
  ConfigFiles get configFiles => ConfigFiles(
    applicationId: 'demo',
    globalDirectory: directory,
    localDirectory: directory,
  );
  @override
  void bindExternalDeps(Bind<Object, TestConfig> bind) {
    super.bindExternalDeps(bind);
    if (failBinding) throw StateError('binding failed');
  }
}

class Reject extends Middleware<CliCommand, TestConfig> {
  @override
  String get logTag => 'Reject';
  @override
  Future<RouteContext> call(RouteContext context) async =>
      throw const CliUsageException('Denied');
  @override
  String toString() => 'Reject';
}

void main() {
  late Directory temp;
  setUp(() async {
    await GetIt.I.reset();
    temp = await Directory.systemTemp.createTemp('grumpy-cli-runtime-');
  });
  tearDown(() async {
    await GetIt.I.reset();
    await temp.delete(recursive: true);
  });
  test(
    'help and argument errors do not read config or activate modules',
    () async {
      await File('${temp.path}/config.json').writeAsString('broken');
      var executions = 0;
      final module = TestModule(
        TestCommand((_) async {
          executions++;
          return CommandResult.success;
        }),
      );
      final terminal = FakeTerminal();
      expect(
        await TestApp(
          module,
          temp.path,
          terminal: terminal,
        ).run(['config', 'init', '--help']),
        0,
      );
      expect(terminal.output.toString(), contains('Initialize settings'));
      expect(module.activations, 0);
      expect(executions, 0);
      expect(terminal.disposals, 1);
      expect(
        await TestApp(
          module,
          temp.path,
          terminal: FakeTerminal(),
        ).run(['config', 'init', '--unknown']),
        64,
      );
      expect(module.activations, 0);
    },
  );
  test(
    'typed inherited options, arguments and module lifecycle reach handler',
    () async {
      final verbose = CliFlag('verbose');
      final count = CliOption<int>('count', type: CliValueType.integer());
      final name = CliParameter<String>(
        'name',
        type: CliValueType.string(),
        required: true,
      );
      final events = <String>[];
      final module = TestModule(
        TestCommand((ctx) async {
          expect(ctx.args.get(verbose), true);
          expect(ctx.args.get(count), 3);
          expect(ctx.args.get(name), 'has spaces');
          expect(ctx.originalArguments, [
            '--verbose',
            'config',
            'init',
            'has spaces',
            '--count=3',
          ]);
          await DependencyReadinessFromDi.wait();
          events.add('executed');
          return const CommandResult(7);
        }, arguments: ArgumentSchema(arguments: [name])),
        arguments: ArgumentSchema(arguments: [count]),
      );
      final terminal = FakeTerminal();
      final app = TestApp(
        module,
        temp.path,
        terminal: terminal,
        arguments: ArgumentSchema(arguments: [verbose]),
      );
      expect(
        await app.run([
          '--verbose',
          'config',
          'init',
          'has spaces',
          '--count=3',
        ]),
        7,
      );
      expect(events, ['executed']);
      expect(module.activations, 1);
      expect(module.destructions, 1);
      expect(
        GetIt.I.isRegistered<RoutingService<CliCommand, TestConfig>>(),
        false,
      );
      expect(terminal.disposals, 1);
    },
  );
  test(
    'inherited repeated options preserve typed values across command levels',
    () async {
      final tags = CliMultiOption<int>(
        'tag',
        elementType: CliValueType.integer(),
      );
      final module = TestModule(
        TestCommand((ctx) async {
          final List<int> values = ctx.args.require(tags);
          expect(values, [1, 2, 3]);
          return CommandResult.success;
        }),
      );
      expect(
        await TestApp(
          module,
          temp.path,
          terminal: FakeTerminal(),
          arguments: ArgumentSchema(arguments: [tags]),
        ).run(['--tag=1', 'config', '--tag=2', 'init', '--tag=3']),
        0,
      );
    },
  );
  test(
    'sequential app instances execute identical arguments independently and preserve foreign DI',
    () async {
      GetIt.I.registerSingleton<String>('foreign');
      var executions = 0;
      for (var i = 0; i < 2; i++) {
        final module = TestModule(
          TestCommand((_) async {
            executions++;
            return CommandResult.success;
          }),
        );
        expect(
          await TestApp(
            module,
            temp.path,
            terminal: FakeTerminal(),
          ).run(['config', 'init']),
          0,
        );
        expect(GetIt.I<String>(), 'foreign');
      }
      expect(executions, 2);
      expect(GetIt.I.currentScopeName, 'baseScope');
    },
  );
  test('middleware rejection and command failure both clean up', () async {
    var executions = 0;
    final rejected = TestModule(
      TestCommand((_) async {
        executions++;
        return CommandResult.success;
      }),
    );
    expect(
      await TestApp(
        rejected,
        temp.path,
        terminal: FakeTerminal(),
        middleware: [Reject()],
      ).run(['config', 'init']),
      64,
    );
    expect(executions, 0);
    expect(rejected.destructions, 1);
    final failed = TestModule(
      TestCommand((_) async => throw StateError('command failed')),
    );
    expect(
      await TestApp(
        failed,
        temp.path,
        terminal: FakeTerminal(),
      ).run(['config', 'init']),
      1,
    );
    expect(failed.destructions, 1);
    expect(GetIt.I.isRegistered<ConfigService>(), false);
  });
  test(
    'partial startup releases root services and allows a fresh app',
    () async {
      final module = TestModule(
        TestCommand((_) async => CommandResult.success),
      );
      expect(
        await TestApp(
          module,
          temp.path,
          terminal: FakeTerminal(),
          failBinding: true,
        ).run(['config', 'init']),
        1,
      );
      expect(GetIt.I.isRegistered<ConfigService>(), false);
      expect(
        await TestApp(
          module,
          temp.path,
          terminal: FakeTerminal(),
        ).run(['config', 'init']),
        0,
      );
    },
  );
  test(
    'noninteractive prompt fails without reading input; cancellation returns 130',
    () async {
      final terminal = FakeTerminal(lines: ['should not read']);
      final module = TestModule(
        TestCommand((ctx) async {
          await ctx.prompts.text('Name');
          return CommandResult.success;
        }),
      );
      expect(
        await TestApp(
          module,
          temp.path,
          terminal: terminal,
        ).run(['config', 'init', '--non-interactive']),
        64,
      );
      expect(terminal.lines, ['should not read']);
      final cancelled = TestModule(
        TestCommand((ctx) async {
          ctx.cancellation.cancel();
          ctx.cancellation.throwIfCancelled();
          return CommandResult.success;
        }),
      );
      expect(
        await TestApp(
          cancelled,
          temp.path,
          terminal: FakeTerminal(),
        ).run(['config', 'init']),
        130,
      );
    },
  );
  test(
    'navigate only selects; repeated router run invokes each time',
    () async {
      var calls = 0;
      final module = TestModule(
        TestCommand((_) async {
          calls++;
          return CommandResult.success;
        }),
      );
      final app = TestApp(module, temp.path, terminal: FakeTerminal());
      await app.config.load();
      await app.bootstrap();
      final router =
          RoutingService<CliCommand, TestConfig>()
              as CliRoutingService<TestConfig>;
      await router.navigate('/config/init');
      expect(calls, 0);
      await router.run(['config', 'init']);
      await router.run(['config', 'init']);
      expect(calls, 2);
      await app.shutdown();
    },
  );
}

class DependencyReadinessFromDi {
  static Future<void> wait() =>
      GetIt.I<DependencyReadiness>().waitForPendingDependencies();
}
