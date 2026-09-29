import 'package:grumpy_cli/grumpy_cli.dart';
import '../../../shared/domain/models/app_config.g.dart';

/// Prints the immutable configuration resolved for this invocation.
class ShowCommand extends CliCommand {
  @override
  Future<CommandResult> execute(CommandContext context) async {
    final config = AppConfig();
    context.terminal.writeln('name=${config.projectName}, port=${config.port}');
    return const CommandResult();
  }
}
