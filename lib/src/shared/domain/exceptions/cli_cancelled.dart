/// Cancellation, Escape, or end of prompt input, mapped to exit code 130.
///
/// This is distinct from ordinary values such as false or an empty selection.
///
/// {@category shared}
/// Cancellation is distinct from a negative answer or an empty selection.
class CliCancelled implements Exception {
  /// Creates a distinct cancellation result without treating it as ordinary input.
  const CliCancelled();
  @override
  String toString() => 'Cancelled.';
}
