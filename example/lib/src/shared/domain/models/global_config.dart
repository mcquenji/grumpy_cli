import 'package:grumpy_cli/grumpy_cli.dart';
import 'server_config.dart';

/// User-wide defaults, overridable in a local config file.
@config
class GlobalConfig extends Model with DefaultServerConfig {
  /// Creates default user preferences.
  const GlobalConfig({this.checkForUpdates = true});

  /// Whether the tool may check for updates.
  final bool checkForUpdates;

  /// Port on which the application listens.
  @override
  @ConfigField(min: 1, max: 65535, examples: [8080, 9000])
  int get port => 8080;
}
