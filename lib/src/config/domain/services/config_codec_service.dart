import 'package:grumpy/grumpy.dart';
import 'package:grumpy_cli/src/config/domain/models/config_format.dart';

/// Encodes and decodes configuration documents without owning storage.
///
/// Resolve the registered implementation with `ConfigCodecService()` or replace its app builder.
abstract class ConfigCodecService extends Service {
  /// Resolves the implementation registered under this domain contract.
  factory ConfigCodecService() => Service.get<ConfigCodecService>();

  /// Constructor for independently implemented adapters.
  ConfigCodecService.internal();

  @override
  bool get singelton => true;
  @override
  String get group => '${super.group}.ConfigCodecService';

  /// Decodes a document into JSON-compatible values; absent documents are empty.
  Map<String, Object?> decode(
    String? text, {
    required ConfigFormat format,
    required String source,
  });

  /// Serializes the complete validated values, retaining comments where supported.
  ///
  /// Original is the loaded snapshot; schemaReference is editor-only metadata.
  String encode(
    Map<String, Object?> values, {
    required ConfigFormat format,
    String? original,
    String? schemaReference,
  });
}
