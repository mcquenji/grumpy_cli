import 'package:args/args.dart';
import 'package:grumpy/grumpy.dart';
import 'package:meta/meta.dart';
import 'package:grumpy_cli/src/arguments/domain/models/argument_schema.dart';
import 'package:grumpy_cli/src/module/cli_module.dart';
import 'package:grumpy_cli/src/presentation/commands/cli_command.dart';
import 'package:grumpy_cli/src/routing/domain/models/command.dart';
import 'package:grumpy_cli/src/routing/domain/models/command_group.dart';
import 'package:grumpy_cli/src/routing/domain/models/command_invocation.dart';
import 'package:grumpy_cli/src/routing/infra/models/command_node.dart';
import 'package:grumpy_cli/src/shared/domain/exceptions/cli_usage_exception.dart';

/// Validates command declarations and builds parser/help state without DI.
///
/// Constructed lazily from the app's declarations. Keeping discovery free of
/// configuration reads and module activation lets help succeed even when config
/// files are malformed or dependency startup would fail.
@internal
class CommandTree<C extends Object> {
  /// Builds validated command and parser declarations without config or DI access.
  CommandTree(
    this.executable,
    this.description,
    this.routes,
    ArgumentSchema arguments,
  ) {
    if (arguments.arguments.any((a) => a.positional)) {
      throw ArgumentError('Application arguments must be flags/options.');
    }
    root = CommandNode(
      '',
      description,
      arguments,
      arguments.buildParser(),
      [],
      [],
      null,
    );
    _build(root, routes, <Type>{});
  }

  /// Executable label and root description used by help output.
  final String executable, description;

  /// Original CLI route declarations used for core integration.
  final List<Route<CliCommand, C>> routes;

  /// Root parser node carrying inherited application options.
  late final CommandNode<C> root;
  void _build(
    CommandNode<C> parent,
    List<Route<CliCommand, C>> routes,
    Set<Type> visiting,
  ) {
    for (final route in routes) {
      if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9_-]*$').hasMatch(route.path) ||
          route.path == 'help' ||
          parent.children.containsKey(route.path)) {
        throw ArgumentError(
          'Invalid or duplicate command name: ${route.path}.',
        );
      }
      final ArgumentSchema own;
      final String description;
      final modules = [...parent.modules];
      if (route is Command<C>) {
        own = route.handler.arguments;
        description = route.description;
      } else if (route is CommandGroup<C>) {
        final module = route.module as CliModule<C>;
        own = module.arguments;
        description = route.description;
        if (own.arguments.any((a) => a.positional)) {
          throw ArgumentError('Group arguments must be flags/options.');
        }
        modules.add(module);
      } else {
        throw ArgumentError('Use Command or CommandGroup in CLI modules.');
      }
      final schema = own.inherit(parent.schema);
      final parser = schema.buildParser();
      final node = CommandNode(
        route.path,
        description,
        schema,
        parser,
        [...parent.lineage, route],
        modules,
        route is Command<C> ? route : null,
      );
      parent.children[route.path] = node;
      parent.parser.addCommand(route.path, parser);
      if (route is CommandGroup<C>) {
        if (!visiting.add(route.module.runtimeType)) {
          throw ArgumentError('Circular command groups at ${route.path}.');
        }
        _build(node, route.module.routes, visiting);
        visiting.remove(route.module.runtimeType);
      }
    }
  }

  /// Selects a leaf or help target directly from the original argv tokens.
  CommandInvocation<C> parse(List<String> original) {
    final argv = original.isNotEmpty && original.first == 'help'
        ? [...original.skip(1), '--help']
        : original;
    try {
      var result = root.parser.parse(argv);
      final results = <ArgResults>[result];
      var node = root;
      final path = <String>[];
      while (result.command != null) {
        result = result.command!;
        node = node.children[result.name]!;
        path.add(result.name!);
        results.add(result);
      }
      final help = results.any((r) => r.flag('help')) || node.route == null;
      if (node.route == null && result.rest.isNotEmpty) {
        throw CliUsageException('Unknown command: ${result.rest.first}.');
      }
      return CommandInvocation(
        path: path,
        original: original,
        args: help ? null : node.schema.fromResults(results, result.rest),
        command: node.route,
        modules: node.modules,
        lineage: node.lineage,
        help: help,
      );
    } on FormatException catch (e) {
      throw CliUsageException(e.message);
    }
  }

  CommandNode<C> _node(List<String> path) {
    var node = root;
    for (final segment in path) {
      final child = node.children[segment];
      if (child == null) {
        throw CliUsageException('Unknown command: ${path.join('/')}');
      }
      node = child;
    }
    return node;
  }

  /// Selects a declared handler without parsing or requiring its arguments.
  CommandInvocation<C> select(String path) {
    final uri = Uri.parse(path);
    if (uri.hasQuery || uri.hasFragment) {
      throw const CliUsageException(
        'Pass command arguments to run(), not as a URL.',
      );
    }
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    final node = _node(segments);
    if (node.route == null) {
      throw CliUsageException('Select a command leaf: $path.');
    }
    return CommandInvocation(
      path: segments,
      original: const [],
      command: node.route,
      modules: node.modules,
      lineage: node.lineage,
    );
  }

  /// Formats deterministic help for the selected node and inherited declarations.
  String usage(CommandInvocation<C> invocation) {
    final node = _node(invocation.path);
    final parameters = node.schema.arguments
        .where((a) => a.positional)
        .map(
          (a) => a.required
              ? '<${a.name}${a.multiple ? '...' : ''}>'
              : '[${a.name}${a.multiple ? '...' : ''}]',
        );
    final out = StringBuffer(
      '${node.description}\n\nUsage: ${[executable, ...invocation.path].join(' ')} ${node.route == null ? '<command> ' : ''}[options] ${parameters.join(' ')}\n\n${node.parser.usage}\n',
    );
    if (node.children.isNotEmpty) {
      out.writeln('\nCommands:');
      for (final child in node.children.values) {
        out.writeln('  ${child.name.padRight(18)} ${child.description}');
      }
    }
    for (final a in node.schema.arguments) {
      if (a.positional) out.writeln('  ${a.name}: ${a.description}');
      if (a.defaultValue != null) {
        out.writeln('  ${a.name} default: ${a.defaultValue}');
      }
    }
    return out.toString();
  }
}
