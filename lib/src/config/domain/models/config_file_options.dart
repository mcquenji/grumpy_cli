import 'package:grumpy/grumpy.dart';
import 'package:grumpy_cli/src/config/domain/models/config_format.dart';

/// The filename and encoding chosen by the CLI developer for one config scope.
///
/// Filenames must be simple names rather than directory paths; use directory
/// overrides on `ConfigFiles` to choose locations.
///
/// {@category config}
class ConfigFileOptions extends Model {
  /// Chooses a simple filename and explicit encoding for one scope.
  const ConfigFileOptions({required this.filename, required this.format});

  /// Simple filename, including any desired dot prefix and extension.
  final String filename;

  /// Encoding used for parsing and saving this scope.
  final ConfigFormat format;
}
