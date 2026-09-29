import 'dart:async';
import 'dart:io';
import 'package:get_it/get_it.dart' hide Disposable;
import 'package:grumpy_cli/grumpy_cli.dart';
import 'package:test/test.dart';
import '../../shared/harness/fake_terminal.dart';

class AppSettings {}

class OwnedService extends Service with LifecycleMixin {
  OwnedService(
    this.events, {
    this.failDestroy = false,
    this.failDeactivate = false,
  });
  final List<String> events;
  final bool failDestroy, failDeactivate;
  @override
  bool get singelton => true;
  @override
  String get logTag => 'OwnedService';
  @override
  void initialize() {
    events.add('initialize');
  }

  @override
  void activate() {
    events.add('activate');
  }

  @override
  void deactivate() {
    events.add('deactivate');
    if (failDeactivate) throw StateError('deactivate failure');
  }

  @override
  void dependenciesChanged() {}
  @override
  Future<void> destroy() async {
    events.add('destroy');
    await super.destroy();
    if (failDestroy) throw StateError('destroy failure');
  }
}

class FeatureModule extends CliModule<AppSettings> {
  FeatureModule(
    this.events, {
    this.failDestroy = false,
    this.failDeactivate = false,
  });
  final List<String> events;
  final bool failDestroy, failDeactivate;
  @override
  String get logTag => 'FeatureModule';
  @override
  List<Route<CliCommand, AppSettings>> get commands => [];
  @override
  void bindServices(Bind<Service, AppSettings> bind) {
    bind<OwnedService>(
      (_, _) => OwnedService(
        events,
        failDestroy: failDestroy,
        failDeactivate: failDeactivate,
      ),
    );
  }
}

class LifecycleApp extends CliApp<AppSettings> {
  LifecycleApp(this.feature, this.directory, {this.failBinding = false})
    : super(AppSettings(), terminal: FakeTerminal());
  final FeatureModule feature;
  final String directory;
  final bool failBinding;
  @override
  String get logTag => 'LifecycleApp';
  @override
  String get executableName => 'lifecycle-demo';
  @override
  List<Route<CliCommand, AppSettings>> get commands => [];
  @override
  List<Module<CliCommand, AppSettings>> get imports => [feature];
  @override
  ConfigFiles get configFiles => ConfigFiles(
    applicationId: executableName,
    globalDirectory: directory,
    localDirectory: directory,
  );
  @override
  void bindExternalDeps(Bind<Object, AppSettings> bind) {
    super.bindExternalDeps(bind);
    bind<int>((_, _) => 123);
    if (failBinding) throw StateError('binding failure');
  }
}

void main() {
  late Directory temp;
  setUp(() async {
    await GetIt.I.reset();
    temp = await Directory.systemTemp.createTemp('grumpy-cli-life-');
  });
  tearDown(() async {
    await GetIt.I.reset();
    await temp.delete(recursive: true);
  });
  test(
    'shutdown preserves unrelated outer and later scopes and disposes once',
    () async {
      GetIt.I.registerSingleton<String>('outer');
      final events = <String>[];
      final app = LifecycleApp(FeatureModule(events), temp.path);
      await app.bootstrap();
      GetIt.I.pushNewScope(scopeName: 'unrelated');
      GetIt.I.registerSingleton<double>(3.14);
      await app.shutdown();
      await app.shutdown();
      expect(events, ['initialize', 'activate', 'deactivate', 'destroy']);
      expect(GetIt.I<String>(), 'outer');
      expect(GetIt.I<double>(), 3.14);
      expect(GetIt.I.isRegistered<AppSettings>(), false);
      expect(GetIt.I.isRegistered<OwnedService>(), false);
      expect(app.isDisposed, true);
      expect(app.isActive, false);
      final next = LifecycleApp(FeatureModule([]), temp.path);
      await next.bootstrap();
      await next.shutdown();
    },
  );
  for (final phase in ['deactivate', 'destroy']) {
    test('$phase failure still releases every owned scope', () async {
      final events = <String>[];
      final app = LifecycleApp(
        FeatureModule(
          events,
          failDestroy: phase == 'destroy',
          failDeactivate: phase == 'deactivate',
        ),
        temp.path,
      );
      await app.bootstrap();
      await expectLater(app.shutdown(), throwsStateError);
      expect(events.where((e) => e == 'destroy').length, 1);
      expect(GetIt.I.isRegistered<OwnedService>(), false);
      expect(GetIt.I.isRegistered<AppSettings>(), false);
      final next = LifecycleApp(FeatureModule([]), temp.path);
      await next.bootstrap();
      await next.shutdown();
    });
  }
  test(
    'partial startup propagates without leaking root registrations',
    () async {
      final app = LifecycleApp(FeatureModule([]), temp.path, failBinding: true);
      await expectLater(app.bootstrap(), throwsStateError);
      expect(GetIt.I.isRegistered<int>(), false);
      expect(GetIt.I.isRegistered<AppSettings>(), false);
      final next = LifecycleApp(FeatureModule([]), temp.path);
      await next.bootstrap();
      await next.shutdown();
    },
  );
  test(
    'a competing application cannot dispose the active application',
    () async {
      final app = LifecycleApp(FeatureModule([]), temp.path);
      await app.bootstrap();
      final competitor = LifecycleApp(FeatureModule([]), temp.path);
      await expectLater(competitor.bootstrap(), throwsStateError);
      expect(app.isActive, true);
      expect(GetIt.I<int>(), 123);
      await app.shutdown();
    },
  );
}
