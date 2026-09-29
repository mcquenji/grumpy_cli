/// The scope or fallback that supplied an effective setting value.
///
/// {@category config}
enum ConfigSource {
  /// An explicit value in the local file.
  local,

  /// An explicit value in the global file.
  global,

  /// The fallback declared on the setting.
  defaultValue,

  /// No participating scope or default supplied a value.
  absent,
}
