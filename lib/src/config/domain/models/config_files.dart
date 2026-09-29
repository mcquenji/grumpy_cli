import 'package:grumpy/grumpy.dart';
import 'package:path/path.dart' as p;
import 'package:grumpy_cli/src/config/domain/models/config_file_options.dart';
import 'package:grumpy_cli/src/config/domain/models/config_format.dart';

/// File formats and discovery policy for the two persisted configuration scopes.
///
/// Local discovery walks from `workingDirectory` to the nearest ancestor with
/// the configured filename; when none exists, creation uses the starting directory.
/// An explicit local directory disables that search. Global files live beneath
/// the application identifier in the platform's user configuration directory.
///
/// {@category config}
class ConfigFiles extends Model {
  /// Creates pure location metadata with optional environment/platform overrides.
  ///
  /// Directory overrides are independent. If omitted, `workingDirectory` uses the
  /// process directory, and local filenames default to `.<applicationId>.json`.
  ConfigFiles({
    required this.applicationId,
    this.global = const ConfigFileOptions(
      filename: 'config.json',
      format: ConfigFormat.json,
    ),
    ConfigFileOptions? local,
    this.globalDirectory,
    this.localDirectory,
    this.workingDirectory,
    Map<String, String>? environment,
    this.operatingSystem,
  }) : local =
           local ??
           ConfigFileOptions(
             filename: '.$applicationId.json',
             format: ConfigFormat.json,
           ),
       environment = environment == null
           ? null
           : Map.unmodifiable(environment) {
    if (!RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9._-]*$').hasMatch(applicationId) ||
        applicationId == '..') {
      throw ArgumentError('Invalid application identifier.');
    }
    for (final file in [global, this.local]) {
      if (file.filename.isEmpty ||
          p.basename(file.filename) != file.filename ||
          file.filename == '..' ||
          file.filename == '.') {
        throw ArgumentError('Config filenames must be simple filenames.');
      }
    }
  }

  /// Application directory name beneath the platform's user configuration root.
  final String applicationId;

  /// Global file name and encoding.
  final ConfigFileOptions global;

  /// Local file name and encoding.
  final ConfigFileOptions local;

  /// Directory overrides and the starting directory for local discovery.
  ///
  /// `globalDirectory` replaces platform discovery; `localDirectory` disables
  /// ancestor discovery; `workingDirectory` selects the ancestor search start.
  final String? globalDirectory, localDirectory, workingDirectory;

  /// Optional environment override; the location service chooses native defaults.
  final Map<String, String>? environment;

  /// Optional platform name; the default location service uses the host when null.
  final String? operatingSystem;
}
