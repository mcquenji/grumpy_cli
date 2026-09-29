import 'package:grumpy_cli/grumpy_cli.dart';
import '../shared/domain/models/app_config.g.dart';
import 'presentation/commands/init_command.dart';
import 'presentation/commands/show_command.dart';

/// Commands for setting up and inspecting application configuration.
class ConfigModule extends CliModule<AppConfig> {
  @override
  String get logTag => 'ConfigModule';
  @override
  List<Route<CliCommand, AppConfig>> get commands => [
    Command(
      name: 'init',
      description: 'Create local settings',
      handler: InitCommand(),
    ),
    Command(
      name: 'show',
      description: 'Show resolved settings',
      handler: ShowCommand(),
    ),
  ];
}
