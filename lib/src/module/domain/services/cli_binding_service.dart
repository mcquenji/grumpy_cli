import 'package:grumpy/grumpy.dart';

/// Assembles replaceable preflight dependencies before application activation.
///
/// Early factories receive declaration defaults; [updateConfig] publishes the
/// resolved snapshot for subsequent factories. Transferred instances become
/// owned by the application's ordinary module scope.
abstract class CliBindingService<C extends Object> extends Service {
  /// Resolves the application's configured preflight binding service.
  factory CliBindingService() => Service.get<CliBindingService<C>>();

  /// Constructor for independently implemented binding services.
  CliBindingService.internal();

  /// Adds a factory without constructing its instance.
  void add<V extends Injectable>(InjectableFactory<V, C> builder);

  /// Registers a borrowed host value without taking disposal ownership.
  void value<V extends Object>(V value);

  /// Publishes configuration for factories that have not yet been constructed.
  void updateConfig(C value);

  /// Resolves one stable instance per registered contract.
  V resolve<V extends Object>();

  /// Resolves an instance and transfers its ownership to a module registration.
  V transfer<V extends Object>();

  /// Returns an already constructed instance without calling its factory.
  V? peek<V extends Object>();

  @override
  bool get singelton => true;
  @override
  String get group => '${super.group}.CliBindingService';
}
