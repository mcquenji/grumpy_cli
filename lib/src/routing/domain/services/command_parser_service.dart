import 'package:grumpy/grumpy.dart';
import 'package:grumpy_cli/src/routing/domain/models/command_invocation.dart';

/// Replaceable command discovery, argv parsing and help formatting contract.
///
/// Constructing/using this service for help must not read config or activate DI.
abstract class CommandParserService<C extends Object> extends Service {
  /// Resolves the registered parser.
  factory CommandParserService() => Service.get<CommandParserService<C>>();

  /// Constructor for parser implementations independent of package:args.
  CommandParserService.internal();

  /// Validates original tokens and returns an execution or help selection.
  CommandInvocation<C> parse(List<String> arguments);

  /// Selects a handler by literal path without requiring execution arguments.
  CommandInvocation<C> select(String path);

  /// Formats help for a parser-produced selection.
  String usage(CommandInvocation<C> invocation);
  @override
  bool get singelton => true;
  @override
  String get group => '${super.group}.CommandParserService';
}
