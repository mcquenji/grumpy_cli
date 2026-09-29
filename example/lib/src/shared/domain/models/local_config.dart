import 'package:grumpy_cli/grumpy_cli.dart';

/// Settings introduced by a local workspace.
@localConfig
class LocalConfig extends Model {
  /// Creates a configuration that can be completed by config init.
  const LocalConfig({this.projectName, this.features = const []});

  /// Display name of this project.
  @ConfigField(minLength: 1)
  final String? projectName;

  /// Enabled optional features.
  final List<String> features;
}
