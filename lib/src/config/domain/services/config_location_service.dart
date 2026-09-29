import 'package:grumpy/grumpy.dart';
import 'package:grumpy_cli/src/config/domain/models/config_files.dart';

/// Resolves scope locations without binding the config model to native IO.
///
/// Resolve the registered implementation with `ConfigLocationService()` or replace its app builder.
abstract class ConfigLocationService extends Service {
  /// Resolves the implementation registered under this domain contract.
  factory ConfigLocationService() => Service.get<ConfigLocationService>();

  /// Constructor for independently implemented adapters.
  ConfigLocationService.internal();

  @override
  bool get singelton => true;
  @override
  String get group => '${super.group}.ConfigLocationService';

  /// Resolves the global document location for the supplied policy.
  String globalPath(ConfigFiles files);

  /// Discovers the local location or chooses the path for a new document.
  Future<String> localPath(ConfigFiles files);
}
