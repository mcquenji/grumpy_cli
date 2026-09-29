/// Normalized keys understood by keyboard selection prompts.
///
/// EOF is represented separately by a null read result; cancellation throws a
/// `CliCancelled` exception instead of producing an ordinary key.
///
/// {@category terminal}
enum TerminalKey {
  /// Move to the previous enabled choice.
  up,

  /// Move to the next enabled choice.
  down,

  /// Left arrow, available to custom renderers.
  left,

  /// Right arrow, available to custom renderers.
  right,

  /// Toggle the highlighted multiselect choice.
  space,

  /// Accept the highlighted choice or current selection.
  enter,

  /// Cancel the current prompt.
  escape,

  /// An unrecognized key that the default menus ignore.
  other,
}
