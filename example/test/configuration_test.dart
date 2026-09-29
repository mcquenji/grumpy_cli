import 'dart:convert';
import 'package:grumpy_cli/grumpy_cli.dart';
import 'package:grumpy_io/grumpy_io.dart';
import 'package:grumpy_cli_example/src/app.dart';
import 'package:grumpy_cli_example/src/shared/domain/models/app_config.g.dart';
import 'package:grumpy_cli_example/src/shared/domain/models/server_config.dart';
import 'package:grumpy_cli_example/src/shared/infra/services/memory_file_system_service.dart';
import 'package:test/test.dart';
import '../../test/shared/harness/fake_terminal.dart';

class InspectCommand extends CliCommand {
  InspectCommand(this.inspect);
  final Future<void> Function(CommandContext) inspect;
  @override
  Future<CommandResult> execute(CommandContext context) async {
    await inspect(context);
    return const CommandResult();
  }
}

class InspectionApp extends App {
  InspectionApp(this.store, this.inspect);
  final MemoryFileSystemService store;
  final Future<void> Function(CommandContext) inspect;
  final terminalOutput = FakeTerminal();
  int? boundPort;
  @override
  String get logTag => 'InspectionApp';
  @override
  ConfigFiles get configFiles => ConfigFiles(
    applicationId: 'example',
    globalDirectory: '/global',
    localDirectory: '/local',
    local: const ConfigFileOptions(
      filename: 'config.json',
      format: ConfigFormat.json,
    ),
  );
  @override
  InjectableFactory<FileSystemService, AppConfig>
  get fileSystemServiceBuilder =>
      (_, _) => store;
  @override
  InjectableFactory<TerminalService, AppConfig> get terminalServiceBuilder =>
      (_, _) => terminalOutput;
  @override
  void bindExternalDeps(Bind<Object, AppConfig> bind) {
    super.bindExternalDeps(bind);
    boundPort = cfg.port;
  }

  @override
  List<Route<CliCommand, AppConfig>> get commands => [
    Command(name: 'inspect', handler: InspectCommand(inspect)),
  ];
}

void main() {
  test(
    'DI and module builders receive the immutable resolved snapshot',
    () async {
      final store = MemoryFileSystemService();
      store.files['/global/config.json'] = Bytes.fromList(
        utf8.encode('{"port":9000,"checkForUpdates":false}'),
      );
      store.files['/local/config.json'] = Bytes.fromList(
        utf8.encode('{"port":9100,"projectName":null}'),
      );
      final app = InspectionApp(store, (context) async {
        final snapshot = AppConfig();
        expect(snapshot, isA<ServerConfig>());
        expect(snapshot.port, 9100);
        expect(snapshot.checkForUpdates, false);
        expect(snapshot.projectName, isNull);
        expect(
          context.config.explain(AppConfig.settings.port).source,
          ConfigSource.local,
        );
        await context.config.local.set(AppConfig.settings.port, 9200);
        expect(context.config.get(AppConfig.settings.port), 9200);
        expect(AppConfig(), same(snapshot));
        expect(snapshot.port, 9100);
        expect(() => snapshot.features.add('mutable'), throwsUnsupportedError);
      });
      expect(
        await app.run(['inspect']),
        0,
        reason: app.terminalOutput.diagnostics.toString(),
      );
      expect(app.boundPort, 9100);
      final next = InspectionApp(store, (_) async {
        expect(AppConfig().port, 9200);
      });
      expect(await next.run(['inspect']), 0);
    },
  );
  test(
    'local-only properties are rejected globally with a useful diagnostic',
    () async {
      final store = MemoryFileSystemService();
      store.files['/global/config.json'] = Bytes.fromList(
        utf8.encode('{"projectName":"invalid"}'),
      );
      final app = InspectionApp(store, (_) async => fail('must not execute'));
      expect(await app.run(['inspect']), 64);
      expect(
        app.terminalOutput.diagnostics.toString(),
        contains('projectName'),
      );
      expect(app.boundPort, isNull);
    },
  );
}
