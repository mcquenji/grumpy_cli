import 'package:grumpy_io/grumpy_io.dart';
import 'dart:convert';
import 'dart:io';
import 'package:grumpy_cli/grumpy_cli.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

class FailingStore extends FileConfigDatasource {
  FailingStore() : super(fileSystemService: DefaultFileSystemService());
  @override
  String get logTag => 'FailingStore';
  @override
  Future<void> replace(String path, String contents, {String? expected}) async {
    throw const FileSystemException('simulated replacement failure');
  }
}

void main() {
  late Directory temp;
  final port = ConfigSetting(
    'port',
    type: CliValueType.integer(min: 1, max: 65535),
    defaultValue: 8080,
    description: 'Listening port',
  );
  final checks = ConfigSetting('checks', type: CliValueType.boolean());
  final name = ConfigSetting('name', type: CliValueType.string());
  final schema = ConfigSchema(
    global: [port, checks],
    local: [name],
    schemaUri: Uri.parse('https://example.com/schema.json'),
  );
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('grumpy-cli-config-');
  });
  tearDown(() async {
    await temp.delete(recursive: true);
  });
  ConfigService service({
    ConfigFormat format = ConfigFormat.json,
    ConfigDatasource? store,
    bool discover = false,
  }) => DefaultConfigService(
    schema: schema,
    datasource:
        store ??
        FileConfigDatasource(fileSystemService: DefaultFileSystemService()),
    locations: PlatformConfigLocationService(
      store ??
          FileConfigDatasource(fileSystemService: DefaultFileSystemService()),
    ),
    codec: JsonYamlConfigCodecService(),
    files: ConfigFiles(
      applicationId: 'demo',
      globalDirectory: p.join(temp.path, 'global'),
      localDirectory: discover ? null : p.join(temp.path, 'local'),
      workingDirectory: p.join(temp.path, 'local', 'nested'),
      global: ConfigFileOptions(
        filename: 'config.${format.name}',
        format: format,
      ),
      local: ConfigFileOptions(
        filename: '.demo.${format.name}',
        format: format,
      ),
    ),
  );

  for (final format in ConfigFormat.values) {
    test(
      '${format.name} typed scoped reads, false values, precedence and removal',
      () async {
        final config = service(format: format);
        await config.load();
        expect(config.get(port), 8080);
        expect(config.global.get(port), isNull);
        expect(config.explain(port).source, ConfigSource.defaultValue);
        await config.global.update((e) {
          e.set(port, 9000);
          e.set(checks, false);
        });
        expect(config.get(checks), false);
        await config.local.set(port, 8000);
        expect(config.get(port), 8000);
        expect(config.explain(port).file, config.local.path);
        await config.local.remove(port);
        expect(config.get(port), 9000);
        await config.local.set(name, '');
        expect(config.get(name), '');
        final loaded = service(format: format);
        await loaded.load();
        expect(loaded.get(port), 9000);
        expect(loaded.get(checks), false);
        expect(() => loaded.global.get(name), throwsArgumentError);
        await loaded.local.set(checks, true);
        expect(loaded.get(checks), true);
      },
    );
  }
  test('explicit local null overrides a global nullable value', () async {
    final token = ConfigSetting<String?>(
      'token',
      type: CliValueType.string().nullable(),
      defaultValue: 'fallback',
    );
    final store = FileConfigDatasource(
      fileSystemService: DefaultFileSystemService(),
    );
    final config = DefaultConfigService(
      schema: ConfigSchema(global: [token]),
      files: ConfigFiles(
        applicationId: 'nullable',
        globalDirectory: '${temp.path}/global',
        localDirectory: '${temp.path}/local',
      ),
      datasource: store,
      locations: PlatformConfigLocationService(store),
      codec: JsonYamlConfigCodecService(),
    );
    await config.load();
    await config.global.set(token, 'global');
    await config.local.set(token, null);
    expect(config.local.contains(token), true);
    expect(config.get(token), isNull);
    expect(config.explain(token).source, ConfigSource.local);
    await config.local.remove(token);
    expect(config.get(token), 'global');
  });
  test('YAML updates preserve surrounding comments and style', () async {
    final config = service(format: ConfigFormat.yaml);
    final file = File(
      await PlatformConfigLocationService(
        FileConfigDatasource(fileSystemService: DefaultFileSystemService()),
      ).localPath(config.files),
    );
    await file.parent.create(recursive: true);
    await file.writeAsString(
      '# my local\nname: "demo" # keep this\nport: 8080 # local port\n',
    );
    await config.load();
    await config.local.set(port, 9001);
    final content = await file.readAsString();
    expect(content, contains('# my local'));
    expect(content, contains('name: "demo" # keep this'));
    expect(content, contains('# local port'));
    expect(
      content,
      contains(
        r'# yaml-language-server: $schema=https://example.com/schema.json#/$defs/local',
      ),
    );
    await config.local.reload();
    expect(config.get(port), 9001);
  });
  test(
    'invalid writes and replacement failure preserve disk and memory',
    () async {
      final config = service();
      await config.load();
      await config.local.set(port, 9000);
      final before = await File(config.local.path).readAsString();
      await expectLater(
        config.local.set(port, 0),
        throwsA(isA<CliUsageException>()),
      );
      expect(await File(config.local.path).readAsString(), before);
      final broken = service(store: FailingStore());
      await broken.load();
      await expectLater(
        broken.local.set(port, 7000),
        throwsA(isA<FileSystemException>()),
      );
      expect(broken.get(port), 9000);
      expect(await File(config.local.path).readAsString(), before);
    },
  );
  test(
    'batch validation is atomic and concurrent writes are serialized',
    () async {
      final config = service();
      await config.load();
      await expectLater(
        config.local.update((e) {
          e.set(name, 'demo');
          e.set(port, -1);
        }),
        throwsA(isA<CliUsageException>()),
      );
      expect(await File(config.local.path).exists(), false);
      await Future.wait([
        config.local.set(name, 'demo'),
        config.local.set(port, 9090),
      ]);
      await config.local.reload();
      expect(config.get(name), 'demo');
      expect(config.get(port), 9090);
    },
  );
  test('manual edits are not overwritten by stale snapshots', () async {
    final config = service();
    await config.load();
    await config.local.set(port, 9000);
    await File(config.local.path).writeAsString('{"port":9001}');
    await expectLater(
      config.local.set(port, 9002),
      throwsA(isA<CliUsageException>()),
    );
    expect(await File(config.local.path).readAsString(), '{"port":9001}');
  });
  test('discovery chooses nearest local ancestor', () async {
    final config = service(discover: true);
    final file = File(p.join(temp.path, 'local', '.demo.json'));
    await file.parent.create(recursive: true);
    await file.writeAsString('{"port":1234}');
    await Directory(p.join(temp.path, 'local', 'nested')).create();
    await config.load();
    expect(config.local.path, file.path);
    expect(config.get(port), 1234);
  });
  test(
    'malformed, unknown and wrong-scope properties fail with file paths',
    () async {
      final config = service();
      final file = File(
        await PlatformConfigLocationService(
          FileConfigDatasource(fileSystemService: DefaultFileSystemService()),
        ).localPath(config.files),
      );
      await file.parent.create(recursive: true);
      for (final content in ['{', '{"port":"bad"}', '{"unknown":0}']) {
        await file.writeAsString(content);
        await expectLater(
          config.load(),
          throwsA(
            isA<CliUsageException>().having(
              (e) => e.message,
              'path',
              contains(file.path),
            ),
          ),
        );
      }
    },
  );
  test(
    'schema and docs are deterministic and stale checks detect changes',
    () async {
      final file = p.join(temp.path, 'schema.json'),
          docs = p.join(temp.path, 'config.md');
      await DefaultConfigSchemaService(
        FileConfigDatasource(fileSystemService: DefaultFileSystemService()),
      ).generate(schema, schemaPath: file, docsPath: docs);
      expect(
        await DefaultConfigSchemaService(
          FileConfigDatasource(fileSystemService: DefaultFileSystemService()),
        ).generate(schema, schemaPath: file, docsPath: docs, check: true),
        true,
      );
      final json = jsonDecode(await File(file).readAsString()) as Map;
      final definitions = json[r'$defs'] as Map;
      expect(
        (definitions['global']['properties'] as Map).keys,
        contains('checks'),
      );
      expect(
        (definitions['local']['properties'] as Map).keys,
        contains('checks'),
      );
      expect(definitions['local']['properties']['port']['minimum'], 1);
      expect(definitions['local'].containsKey('required'), false);
      expect(await File(docs).readAsString(), contains('Listening port'));
      await File(file).writeAsString('{}');
      expect(
        await DefaultConfigSchemaService(
          FileConfigDatasource(fileSystemService: DefaultFileSystemService()),
        ).generate(schema, schemaPath: file, check: true),
        false,
      );
    },
  );
  test('overlapping declaration names are rejected', () {
    expect(
      () => ConfigSchema(
        global: [port],
        local: [ConfigSetting('port', type: CliValueType.string())],
      ),
      throwsArgumentError,
    );
  });
  test('global paths follow supplied platform environment', () {
    expect(
      PlatformConfigLocationService(
        FileConfigDatasource(fileSystemService: DefaultFileSystemService()),
      ).globalPath(
        ConfigFiles(
          applicationId: 'demo',
          environment: {'HOME': '/home/test'},
          operatingSystem: 'linux',
        ),
      ),
      '/home/test/.config/demo/config.json',
    );
    expect(
      PlatformConfigLocationService(
        FileConfigDatasource(fileSystemService: DefaultFileSystemService()),
      ).globalPath(
        ConfigFiles(
          applicationId: 'demo',
          environment: {'XDG_CONFIG_HOME': '/config'},
          operatingSystem: 'linux',
        ),
      ),
      '/config/demo/config.json',
    );
    expect(
      PlatformConfigLocationService(
        FileConfigDatasource(fileSystemService: DefaultFileSystemService()),
      ).globalPath(
        ConfigFiles(
          applicationId: 'demo',
          environment: {'HOME': '/home/test'},
          operatingSystem: 'macos',
        ),
      ),
      '/home/test/Library/Application Support/demo/config.json',
    );
  });
}
