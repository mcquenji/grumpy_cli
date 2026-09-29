/// Validates a typed value, returning null on success or an actionable error.
///
/// The message becomes a usage error or a prompt retry message. Do not include
/// secrets in validation diagnostics.
///
/// {@category shared}
typedef ValueValidator<T> = String? Function(T value);
