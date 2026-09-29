/// Supported on-disk encodings for a configuration scope.
///
/// {@category config}
enum ConfigFormat {
  /// JSON with consistent two-space indentation on writes.
  json,

  /// YAML with targeted edits that preserve surrounding comments and style.
  yaml,
}
