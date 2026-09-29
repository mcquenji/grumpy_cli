import 'package:grumpy/grumpy.dart';

/// Storage boundary for configuration documents, independent of filesystem layout.
///
/// Resolve the registered implementation with `ConfigDatasource()` or replace its app builder.
abstract class ConfigDatasource extends Datasource {
  /// Resolves the implementation registered under this domain contract.
  factory ConfigDatasource() => Datasource.get<ConfigDatasource>();

  /// Constructor for independently implemented adapters.
  ConfigDatasource.internal();

  @override
  bool get singelton => true;
  @override
  String get group => '${super.group}.ConfigDatasource';

  /// Reads a document, or null when it does not exist.
  Future<String?> read(String path);

  /// Tests document existence without requiring its contents to be valid.
  Future<bool> exists(String path);

  /// Atomically replaces a document when its current text matches expected.
  ///
  /// Null expected means absent. Failure must preserve the existing document.
  Future<void> replace(String path, String contents, {String? expected});
}
