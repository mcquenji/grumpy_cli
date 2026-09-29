import 'package:grumpy_cli/src/config/domain/models/config_format.dart';
import 'package:grumpy_cli/src/config/domain/services/config_codec_service.dart';
import 'package:grumpy_cli/src/shared/domain/exceptions/cli_usage_exception.dart';
import 'dart:convert';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

/// JSON/YAML serialization with targeted YAML edits and editor schema metadata.
class JsonYamlConfigCodecService extends ConfigCodecService {
  /// Creates a codec without storage access.
  JsonYamlConfigCodecService() : super.internal();
  @override
  String get logTag => 'JsonYamlConfigCodecService';
  @override
  Map<String, Object?> decode(
    String? text, {
    required ConfigFormat format,
    required String source,
  }) {
    if (text == null) return {};
    try {
      final raw = format == ConfigFormat.json
          ? jsonDecode(text)
          : loadYaml(text);
      if (raw is! Map || raw.keys.any((key) => key is! String)) {
        throw const CliUsageException('Expected a config object.');
      }
      return Map<String, Object?>.from(jsonDecode(jsonEncode(raw)) as Map);
    } catch (e) {
      throw CliUsageException('$source: $e');
    }
  }

  @override
  String encode(
    Map<String, Object?> values, {
    required ConfigFormat format,
    String? original,
    String? schemaReference,
  }) {
    if (format == ConfigFormat.json) {
      return '${const JsonEncoder.withIndent('  ').convert({...values, r'$schema': ?schemaReference})}\n';
    }
    final editor = YamlEditor(original ?? '');
    if (original == null || original.trim().isEmpty) {
      editor.update([], values);
    } else {
      final previous = decode(
        original,
        format: format,
        source: 'original document',
      );
      for (final key in previous.keys) {
        if (!values.containsKey(key)) editor.remove([key]);
      }
      for (final entry in values.entries) {
        if (!previous.containsKey(entry.key) ||
            jsonEncode(previous[entry.key]) != jsonEncode(entry.value)) {
          editor.update([entry.key], entry.value);
        }
      }
    }
    var content = editor.toString();
    if (schemaReference != null &&
        !content.contains('# yaml-language-server:')) {
      content =
          '# yaml-language-server: ${r'$schema'}=$schemaReference\n$content';
    }
    return content;
  }

  @override
  Future<void> destroy() async {}
}
