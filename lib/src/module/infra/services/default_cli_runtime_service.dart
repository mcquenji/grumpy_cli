import 'dart:async';
import '../../../app.dart';
import '../../domain/services/cli_runtime_service.dart';
import '../../../routing/domain/services/cli_routing_service.dart';
import '../../../shared/domain/exceptions/cli_cancelled.dart';
import '../../../shared/domain/exceptions/cli_usage_exception.dart';

/// Runs a CLI application with help before config access and awaited shutdown.
class DefaultCliRuntimeService<C extends Object> extends CliRuntimeService<C> {
  /// Creates a coordinator for one application invocation.
  DefaultCliRuntimeService() : super.internal();
  static Object? _active;
  bool _ran = false;

  @override
  Future<int> run(CliApp<C> app, List<String> arguments) async {
    if (_ran) throw StateError('Create a fresh application for each run.');
    if (_active != null) {
      throw StateError('Only one CLI application may run per isolate.');
    }
    _ran = true;
    _active = this;
    var code = 0;
    StreamSubscription<void>? signals;
    try {
      final invocation = app.commandParser.parse(arguments);
      if (invocation.help) {
        app.terminal.writeln(app.commandParser.usage(invocation));
      } else {
        signals = app.cancellationEvents.listen(
          (_) => app.cancellation.cancel(),
        );
        app.cancellation.throwIfCancelled();
        await app.config.load();
        app.resolveConfiguration();
        app.cancellation.throwIfCancelled();
        await app.bootstrap();
        code = (await CliRoutingService<C>().executeInvocation(
          invocation,
        )).exitCode;
      }
    } on CliCancelled {
      code = 130;
      app.terminal.errorln('Cancelled.');
    } on CliUsageException catch (e) {
      code = 64;
      app.terminal.errorln(e.message);
    } catch (e) {
      code = 1;
      app.terminal.errorln('$e');
    } finally {
      try {
        await signals?.cancel();
        await app.shutdown();
      } catch (e) {
        app.terminal.errorln('Cleanup failed: $e');
        if (code == 0) code = 1;
      }
      try {
        await app.releasePreflight();
      } catch (_) {
        if (code == 0) code = 1;
      }
      _active = null;
    }
    return code;
  }

  @override
  String get logTag => 'DefaultCliRuntimeService';
  @override
  Future<void> destroy() async {}
}
