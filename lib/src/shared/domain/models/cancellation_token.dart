import 'package:grumpy/grumpy.dart';
import 'dart:async';
import 'package:grumpy_cli/src/shared/domain/exceptions/cli_cancelled.dart';

/// Cooperative cancellation shared by one application's commands and prompts.
///
/// Cancellation is permanent and idempotent. It does not forcibly stop arbitrary
/// Dart work; long-running commands must check the token or race an operation
/// against its completion signal.
///
/// {@category shared}
class CancellationToken extends Model {
  final Completer<void> _cancelled = Completer<void>();

  /// Whether cancellation has been requested; once true it remains true.
  bool get isCancelled => _cancelled.isCompleted;

  /// Completes once cancellation is requested.
  Future<void> get whenCancelled => _cancelled.future;

  /// Requests cancellation once; repeated calls are harmless.
  void cancel() {
    if (!isCancelled) _cancelled.complete();
  }

  /// Throws `CliCancelled` when cancellation has already been requested.
  void throwIfCancelled() {
    if (isCancelled) throw const CliCancelled();
  }

  /// Completes with the operation or throws when cancellation wins.
  ///
  /// The underlying future is not forcibly stopped and must arrange its own cleanup.
  Future<T> race<T>(Future<T> work) {
    throwIfCancelled();
    return Future.any([
      work,
      whenCancelled.then<T>((_) => throw const CliCancelled()),
    ]);
  }
}
