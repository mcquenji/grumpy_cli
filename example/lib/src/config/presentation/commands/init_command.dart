import 'package:grumpy_cli/grumpy_cli.dart';
import '../../../shared/domain/models/app_config.g.dart';

/// Guides first-run setup and explicitly saves local overrides.
class InitCommand extends CliCommand {
  static final _port = CliOption<int>(
    'port',
    type: AppConfig.settings.port.type,
  );
  static final _name = CliOption<String>(
    'name',
    type: CliValueType.string(minLength: 1),
  );
  @override
  ArgumentSchema get arguments => ArgumentSchema(arguments: [_port, _name]);

  @override
  Future<CommandResult> execute(CommandContext context) async {
    final config = AppConfig();
    final name =
        context.args.provided(_name) ??
        config.projectName ??
        await context.prompts.ask(
          ValuePrompt('Project name', type: CliValueType.string(minLength: 1)),
        );
    final port = context.args.provided(_port) ?? config.port;
    await context.config.local.update((edit) {
      edit.set(AppConfig.settings.projectName, name);
      edit.set(AppConfig.settings.port, port);
    });
    context.terminal.writeln('Saved local settings for $name on port $port.');
    return const CommandResult();
  }
}
