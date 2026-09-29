import 'package:grumpy/grumpy.dart';

/// Exit status returned by a command without terminating the host process.
///
/// The application uses 0 for success, 1 for execution or cleanup failure, 64 for
/// usage errors, and 130 for cancellation. Commands may return another status
/// when their public command contract requires it.
///
/// {@category presentation}
class CommandResult extends Model {
  /// Creates an explicit exit status; omitting it means success.
  const CommandResult([this.exitCode = 0]);

  /// Process exit status to return after command cleanup.
  final int exitCode;

  /// Reusable successful result with exit code 0.
  static const success = CommandResult();
}
