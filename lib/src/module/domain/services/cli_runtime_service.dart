import 'package:grumpy/grumpy.dart';
import '../../../app.dart';

/// Coordinates one CLI invocation, including preflight and awaited cleanup.
abstract class CliRuntimeService<C extends Object> extends Service {
  /// Resolves a runtime explicitly registered by a host.
  factory CliRuntimeService() => Service.get<CliRuntimeService<C>>();

  /// Constructor for runtime implementations.
  CliRuntimeService.internal();

  /// Parses and runs [arguments], returning the process exit code.
  Future<int> run(CliApp<C> app, List<String> arguments);
  @override
  bool get singelton => true;
  @override
  String get group => '${super.group}.CliRuntimeService';
}
