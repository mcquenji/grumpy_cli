import 'package:grumpy_cli/src/shared/domain/datasources/signal_datasource.dart';
import 'dart:async';
import 'dart:io';

/// Maps SIGINT and supported SIGTERM events to cooperative cancellation.
class ProcessSignalDatasource extends SignalDatasource {
  /// Creates a lazy signal source; no listeners are installed until subscribed.
  ProcessSignalDatasource() : super.internal();
  @override
  String get logTag => 'ProcessSignalDatasource';
  final _subscriptions = <StreamSubscription<ProcessSignal>>[];
  StreamController<void>? _controller;
  @override
  Stream<void> get cancellations => (_controller ??= StreamController<void>(
    onListen: () {
      for (final signal in [
        ProcessSignal.sigint,
        if (!Platform.isWindows) ProcessSignal.sigterm,
      ]) {
        try {
          _subscriptions.add(
            signal.watch().listen((_) => _controller!.add(null)),
          );
        } on SignalException {
          /* Some embedders do not expose process signals. */
        }
      }
    },
    onCancel: _cancel,
  )).stream;
  Future<void> _cancel() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
  }

  @override
  Future<void> destroy() async {
    await _cancel();
    final controller = _controller;
    if (controller != null) {
      unawaited(controller.close());
    }
  }
}
