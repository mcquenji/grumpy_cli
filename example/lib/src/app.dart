import 'dart:io';
import 'package:grumpy_cli/grumpy_cli.dart';
import 'config/config_module.dart';
import 'shared/domain/models/app_config.g.dart';

/// Root module of the example setup application.
class App extends CliApp<AppConfig> {
  /// Creates an application with generated declaration defaults.
  App() : super(AppConfig.defaults());

  @override
  String get logTag => 'App';
  @override
  String get executableName => 'setup-demo';
  @override
  String get description => 'A guided project setup tool.';
  @override
  List<Route<CliCommand, AppConfig>> get commands => [
    CommandGroup(
      name: 'config',
      description: 'Initialize or inspect configuration',
      module: ConfigModule(),
    ),
  ];
  @override
  ConfigFiles get configFiles => ConfigFiles(
    applicationId: executableName,
    local: const ConfigFileOptions(
      filename: '.setup-demo.yaml',
      format: ConfigFormat.yaml,
    ),
    globalDirectory: Platform.environment['SETUP_DEMO_GLOBAL_DIR'],
    localDirectory: Platform.environment['SETUP_DEMO_LOCAL_DIR'],
  );
}
