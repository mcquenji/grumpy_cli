import 'package:grumpy/grumpy.dart';
import 'package:grumpy_cli/src/arguments/domain/models/parsed_arguments.dart';
import 'package:grumpy_cli/src/presentation/commands/cli_command.dart';
import 'package:grumpy_cli/src/routing/domain/models/command.dart';

/// Parser-independent selection consumed by CLI routing implementations.
///
/// A help selection has no args/command. Navigation may select a command without
/// arguments; execution requires validated args. Lists are immutable snapshots.
class CommandInvocation<C extends Object> extends Model {
  /// Creates a selection without requiring the default parser's internal nodes.
  CommandInvocation({
    required List<String> path,
    required List<String> original,
    this.args,
    this.command,
    this.help = false,
    this.nonInteractive = false,
    List<Module<CliCommand, C>> modules = const [],
    List<Route<CliCommand, C>> lineage = const [],
  }) : path = List.unmodifiable(path),
       original = List.unmodifiable(original),
       modules = List.unmodifiable(modules),
       lineage = List.unmodifiable(lineage);

  /// Selected literal command path segments.
  final List<String> path;

  /// Original argv tokens without reconstruction.
  final List<String> original;

  /// Typed input for execution; absent for help and navigation-only selections.
  final ParsedArguments? args;

  /// Executable declaration; absent for a group-only help selection.
  final Command<C>? command;

  /// Whether this selection only displays help.
  final bool help;

  /// Invocation policy supplied by the parser, independent of flag-handle identity.
  final bool nonInteractive;

  /// Group modules needed by this command.
  final List<Module<CliCommand, C>> modules;

  /// Route ancestry in middleware order.
  final List<Route<CliCommand, C>> lineage;
}
