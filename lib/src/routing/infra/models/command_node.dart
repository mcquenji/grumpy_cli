import 'package:args/args.dart';
import 'package:grumpy/grumpy.dart';
import 'package:meta/meta.dart';
import 'package:grumpy_cli/src/arguments/domain/models/argument_schema.dart';
import 'package:grumpy_cli/src/presentation/commands/cli_command.dart';
import 'package:grumpy_cli/src/routing/domain/models/command.dart';

/// Internal parser node with inherited argument schema and module lineage.
///
/// A null leaf route identifies a help-only group; children preserve declaration
/// order for deterministic help output.
@internal
class CommandNode<C extends Object> {
  /// Captures one validated declaration and its inherited parser context.
  CommandNode(
    this.name,
    this.description,
    this.schema,
    this.parser,
    this.lineage,
    this.modules,
    this.route,
  );

  /// Command token and help summary for this node.
  final String name, description;

  /// Combined root/group/leaf argument declarations.
  final ArgumentSchema schema;

  /// Internal args parser for this node's inherited options.
  final ArgParser parser;

  /// Routes traversed from root to this node, in middleware order.
  final List<Route<CliCommand, C>> lineage;

  /// Group modules required to activate this selection.
  final List<Module<CliCommand, C>> modules;

  /// Executable leaf declaration, or null for a group/help node.
  final Command<C>? route;

  /// Child nodes in declaration order, indexed by literal command token.
  final Map<String, CommandNode<C>> children = {};
}
