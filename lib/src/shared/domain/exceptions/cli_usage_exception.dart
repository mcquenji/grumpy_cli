/// User-correctable input or configuration failure mapped to exit code 64.
///
/// Use `message` to identify the offending argument, setting, or file and explain
/// how to correct it. Prompt validation catches this error and retries input.
///
/// {@category shared}
/// A user-correctable input error. Runners map this to exit status 64.
class CliUsageException implements Exception {
  /// Creates a usage failure with an actionable diagnostic.
  const CliUsageException(this.message);

  /// Explanation shown on stderr by the application runner.
  final String message;
  @override
  String toString() => message;
}
