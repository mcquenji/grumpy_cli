import 'package:grumpy/grumpy.dart';
import 'package:grumpy_cli/src/config/domain/services/config_service.dart';
import 'package:grumpy_cli/src/presentation/commands/cli_command.dart';
import 'package:grumpy_cli/src/routing/domain/models/command_context.dart';
import 'package:grumpy_cli/src/routing/domain/models/command_result.dart';
import 'package:grumpy_cli/src/prompting/domain/services/prompt_service.dart';
import 'package:grumpy_cli/src/routing/domain/models/command_invocation.dart';
import 'package:grumpy_cli/src/routing/domain/services/cli_routing_service.dart';
import 'package:grumpy_cli/src/routing/domain/services/command_parser_service.dart';
import 'package:grumpy_cli/src/shared/domain/models/cancellation_token.dart';
import 'package:grumpy_cli/src/terminal/domain/services/terminal_service.dart';
import 'dart:async';

/// Selects CLI handlers and activates their module graph using core contracts.
///
/// `run` executes each invocation independently; results are neither cached nor
/// coalesced. Inherited `navigate` selects a handler without executing it.
/// Dependency readiness tracks module activation, never command completion, so a
/// command can await dependency discovery without waiting on itself.
///
/// Use `CliApp.run` for process-level configuration, signals, exit-code mapping,
/// and cleanup. Direct router calls require an already bootstrapped application
/// and reject overlapping invocations.
///
/// {@category routing}
class DefaultCliRoutingService<C extends Object> extends CliRoutingService<C> {
  /// Borrows all dependencies through domain contracts; owns only router state.
  DefaultCliRoutingService({
    required this.root,
    required this.bootstrapConfig,
    required this.registry,
    required this.parser,
    required this.config,
    required this.prompts,
    required this.terminal,
    required this.cancellation,
  }) : super.internal();
  @override
  final Route<CliCommand, C> root;

  /// Core bootstrap config included in navigation events.
  final C bootstrapConfig;

  /// Registry responsible for activation of the selected module graph.
  final ModuleRegistryService<CliCommand, C> registry;

  /// Parser used by both explicit runs and navigation selection.
  final CommandParserService<C> parser;

  /// Loaded persisted settings supplied to handlers.
  final ConfigService config;

  /// Prompt service used by handlers without constructing a fallback instance.
  final PromptService prompts;

  /// Output boundary borrowed from the application.
  final TerminalService terminal;

  /// Shared invocation cancellation token.
  final CancellationToken cancellation;
  final _events = StreamController<ViewChangedEvent<CliCommand, C>>.broadcast();
  final Set<void Function(Route<CliCommand, C>)> _listeners = {};
  RouteContext? _context;
  Future<void> _readiness = Future.value();
  Future<void> _navigation = Future.value();
  bool _busy = false, _closed = false;
  @override
  String get logTag => 'DefaultCliRoutingService';
  @override
  RouteContext? get currentContext => _context;
  @override
  Future<void> get currentNavigation => _navigation;

  /// Waits for the latest module activation, never for command execution.
  ///
  /// Safe for dependency discovery initiated from an executing command.
  @override
  Future<void> waitForPendingDependencies() async {
    while (true) {
      final pending = _readiness;
      await pending;
      if (identical(pending, _readiness)) return;
    }
  }

  Future<RouteContext> _resolve(CommandInvocation<C> invocation) async {
    final readiness = Completer<void>();
    _readiness = readiness.future;
    // Keep a handler attached even if no consumer asks for readiness.
    unawaited(
      _readiness.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
    );
    try {
      await registry.sync(invocation.modules);
      readiness.complete();
    } catch (e, s) {
      readiness.completeError(e, s);
      rethrow;
    }
    cancellation.throwIfCancelled();
    var context = RouteContext(fullPath: '/${invocation.path.join('/')}');
    for (final route in invocation.lineage) {
      for (final middleware in route.middleware) {
        context = await middleware.call(context);
        cancellation.throwIfCancelled();
      }
    }
    _context = context;
    return context;
  }

  /// Executes one argv selection on an already bootstrapped application.
  ///
  /// Help only prints usage. Errors propagate to the caller; config loading,
  /// process exit-code mapping and shutdown belong to `CliApp.run`.
  @override
  Future<CommandResult> run(List<String> arguments) async {
    final invocation = parser.parse(arguments);
    if (invocation.help) {
      terminal.writeln(parser.usage(invocation));
      return CommandResult.success;
    }
    return executeInvocation(invocation);
  }

  /// Executes an already parsed selection without reconstructing argv.
  ///
  /// Internal bridge used after the app has loaded config and bootstrapped.
  @override
  Future<CommandResult> executeInvocation(
    CommandInvocation<C> invocation,
  ) async {
    if (_closed || _busy) {
      throw StateError('Router is closed or an invocation is already running.');
    }
    _busy = true;
    try {
      final context = await _resolve(invocation);
      final handler = invocation.command!.handler.content(context);
      prompts.nonInteractive = invocation.nonInteractive;
      cancellation.throwIfCancelled();
      final result = await handler.execute(
        CommandContext(
          originalArguments: invocation.original,
          args: invocation.args!,
          route: context,
          config: config,
          terminal: terminal,
          prompts: prompts,
          cancellation: cancellation,
        ),
      );
      cancellation.throwIfCancelled();
      return result;
    } finally {
      _busy = false;
    }
  }

  /// Selects a command handler without calling its `execute` method.
  ///
  /// Activates dependencies and runs middleware. Paths must identify a leaf and
  /// must not contain a query or fragment; command arguments belong to `run`.
  @override
  Future<void> navigate(
    String path, {
    bool skipPreview = false,
    void Function(CliCommand, bool) callback = RoutingService.noopCallback,
  }) {
    if (_closed || _busy) {
      return Future.error(StateError('Router is closed or busy.'));
    }
    _busy = true;
    return _navigation = () async {
      try {
        final invocation = parser.select(path);
        final command = invocation.command!;
        if (!skipPreview) {
          callback(command.handler.preview(RouteContext(fullPath: path)), true);
        }
        final context = await _resolve(invocation);
        final handler = command.handler.content(context);
        _events.add((
          view: handler,
          isPreview: false,
          context: context,
          config: bootstrapConfig,
        ));
        callback(handler, false);
        for (final listener in List.of(_listeners)) {
          listener(command);
        }
      } finally {
        _busy = false;
      }
    }();
  }

  @override
  bool isActive(String path, {bool exact = true, bool ignoreParams = false}) {
    final current = _context?.uri.path;
    if (current == null) return false;
    final requested = ignoreParams ? Uri.parse(path).path : path;
    return exact
        ? current == requested
        : current == requested || current.startsWith('$requested/');
  }

  @override
  void addListener(void Function(Route<CliCommand, C>) listener) =>
      _listeners.add(listener);
  @override
  void removeListener(void Function(Route<CliCommand, C>) listener) =>
      _listeners.remove(listener);
  @override
  Stream<ViewChangedEvent<CliCommand, C>> get viewStream => _events.stream;
  @override
  StreamSubscription<ViewChangedEvent<CliCommand, C>> onViewChanged(
    void Function(ViewChangedEvent<CliCommand, C>) callback,
  ) => viewStream.listen(callback);

  /// Closes navigation events and listeners once; module teardown belongs to the app.
  @override
  Future<void> destroy() async {
    if (_closed) return;
    _closed = true;
    _listeners.clear();
    await _events.close();
  }
}
