import 'package:grumpy/grumpy.dart';
import 'package:grumpy_cli/src/arguments/domain/models/argument_schema.dart';
import 'package:grumpy_cli/src/arguments/domain/models/cli_flag.dart';
import 'package:grumpy_cli/src/presentation/commands/cli_command.dart';
import 'package:grumpy_cli/src/routing/domain/models/command_invocation.dart';
import 'package:grumpy_cli/src/routing/domain/services/command_parser_service.dart';
import 'package:grumpy_cli/src/routing/infra/utils/command_tree.dart';

/// Default command parser using typed schemas and package:args internally.
class ArgsCommandParserService<C extends Object>
    extends CommandParserService<C> {
  /// Builds declarations only; config and DI are not accessed.
  ArgsCommandParserService({
    required String executable,
    required String description,
    required List<Route<CliCommand, C>> commands,
    required ArgumentSchema arguments,
    CliFlag? nonInteractiveFlag,
  }) : _nonInteractiveFlag = nonInteractiveFlag,
       _tree = CommandTree(executable, description, commands, arguments),
       super.internal();
  final CommandTree<C> _tree;
  final CliFlag? _nonInteractiveFlag;
  @override
  String get logTag => 'ArgsCommandParserService';
  @override
  CommandInvocation<C> parse(List<String> arguments) {
    final selection = _tree.parse(arguments);
    return CommandInvocation(
      path: selection.path,
      original: selection.original,
      args: selection.args,
      command: selection.command,
      help: selection.help,
      modules: selection.modules,
      lineage: selection.lineage,
      nonInteractive: _nonInteractiveFlag == null
          ? false
          : selection.args?.get(_nonInteractiveFlag) ?? false,
    );
  }

  @override
  CommandInvocation<C> select(String path) => _tree.select(path);
  @override
  String usage(CommandInvocation<C> invocation) => _tree.usage(invocation);
  @override
  Future<void> destroy() async {}
}
