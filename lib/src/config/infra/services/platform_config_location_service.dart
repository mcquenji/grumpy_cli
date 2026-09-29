import 'package:grumpy_cli/src/config/domain/datasources/config_datasource.dart';
import 'package:grumpy_cli/src/config/domain/models/config_files.dart';
import 'package:grumpy_cli/src/config/domain/services/config_location_service.dart';
import 'package:grumpy_cli/src/shared/domain/exceptions/cli_usage_exception.dart';
import 'dart:io';
import 'package:path/path.dart' as p;

/// Native platform config paths with ancestor discovery through a datasource.
class PlatformConfigLocationService extends ConfigLocationService {
  /// Borrows the registered storage boundary for local-file discovery.
  PlatformConfigLocationService(this.datasource) : super.internal();

  /// Storage used only to check ancestor document existence.
  final ConfigDatasource datasource;
  @override
  String get logTag => 'PlatformConfigLocationService';

  /// Resolves the global path without reading the config file.
  ///
  /// Uses APPDATA on Windows, Library/Application Support on macOS, and
  /// XDG_CONFIG_HOME or ~/.config elsewhere. Missing required environment raises
  /// a usage error.
  @override
  String globalPath(ConfigFiles files) {
    final environment = files.environment ?? Platform.environment;
    final operatingSystem = files.operatingSystem ?? Platform.operatingSystem;
    if (files.globalDirectory != null) {
      return p.join(p.absolute(files.globalDirectory!), files.global.filename);
    }
    final home = environment['HOME'] ?? environment['USERPROFILE'];
    String require(String? value, String label) => value?.isNotEmpty == true
        ? value!
        : throw CliUsageException(
            'Cannot locate global config: $label is not set.',
          );
    final base = switch (operatingSystem) {
      'windows' => require(environment['APPDATA'], 'APPDATA'),
      'macos' => p.join(
        require(home, 'HOME'),
        'Library',
        'Application Support',
      ),
      _ =>
        environment['XDG_CONFIG_HOME']?.isNotEmpty == true
            ? environment['XDG_CONFIG_HOME']!
            : p.join(require(home, 'HOME'), '.config'),
    };
    return p.join(base, files.applicationId, files.global.filename);
  }

  /// Finds the nearest configured local file or the location for a new file.
  ///
  /// An explicit local directory always wins and does not need to exist yet.
  @override
  Future<String> localPath(ConfigFiles files) async {
    if (files.localDirectory != null) {
      return p.join(p.absolute(files.localDirectory!), files.local.filename);
    }
    final initial = p.normalize(
      p.absolute(files.workingDirectory ?? Directory.current.path),
    );
    var directory = initial;
    while (true) {
      final file = p.join(directory, files.local.filename);
      if (await datasource.exists(file)) return file;
      final parent = p.dirname(directory);
      if (parent == directory) return p.join(initial, files.local.filename);
      directory = parent;
    }
  }

  @override
  Future<void> destroy() async {}
}
