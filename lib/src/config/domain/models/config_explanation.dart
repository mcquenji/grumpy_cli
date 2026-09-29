import 'package:grumpy/grumpy.dart';
import 'package:grumpy_cli/src/config/domain/models/config_source.dart';

/// An effective setting value together with its source and optional file path.
///
/// A default has no source file; an absent setting has neither a value nor a file.
///
/// {@category config}
class ConfigExplanation<T> extends Model {
  /// Records a resolved value, its provenance, and an optional source file.
  const ConfigExplanation(this.value, this.source, {this.file});

  /// Effective typed value, or null if no scope or default supplies it.
  final T? value;

  /// Scope, declared default, or absence that explains this result.
  final ConfigSource source;

  /// Source file path for a stored value; null for defaults and absent settings.
  final String? file;
}
