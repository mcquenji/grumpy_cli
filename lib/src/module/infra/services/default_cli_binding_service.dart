import 'dart:async';
import 'package:get_it/get_it.dart' as di;
import 'package:grumpy/grumpy.dart';
import '../../domain/services/cli_binding_service.dart';

/// Lazily composes configured singleton bindings before DI/module activation.
///
/// Help needs parser/terminal only; config loading precedes bootstrap. The exact
/// same instances are later registered under their domain contracts in GetIt.
/// Builders receive Grumpy's Resolver, detect cycles, and own dependencies in
/// reverse construction order. No private GetIt container or global reset is used.
class DefaultCliBindingService<C extends Object> extends CliBindingService<C> {
  /// Creates an invocation-owned assembly with a core-config value.
  DefaultCliBindingService(this.config) : super.internal();

  /// Borrowed application bootstrap value passed to every builder.
  C config;

  /// Publishes resolved config for dependencies constructed after preflight.
  @override
  void updateConfig(C value) {
    config = value;
    _instances[C] = value;
  }

  @override
  String get logTag => 'DefaultCliBindingService';

  final _builders = <Type, Object Function()>{};
  final _instances = <Type, Object>{};
  final _owned = <Object>[];
  final _creating = <Type>{};
  Future<void>? _destruction;

  /// Adds a lazy singleton binding with core's standard builder signature.
  @override
  void add<V extends Injectable>(InjectableFactory<V, C> builder) {
    _builders[V] = () => builder(config, resolve);
  }

  /// Supplies a borrowed value such as the shared cancellation token.
  @override
  void value<V extends Object>(V value) {
    _instances[V] = value;
  }

  /// Resolves configured CLI bindings first, then previously bound core services.
  @override
  V resolve<V extends Object>() {
    if (_instances.containsKey(V)) return _instances[V] as V;
    final builder = _builders[V];
    if (builder == null) return di.GetIt.I.get<V>();
    if (_destruction != null) throw StateError('CLI bindings are disposed.');
    if (!_creating.add(V)) {
      throw StateError('Circular CLI service dependency: $V');
    }
    try {
      final instance = builder();
      // Track the object before validating lifetime so rejected instances still
      // participate in failure cleanup.
      if (!_owned.any((value) => identical(value, instance))) {
        _owned.add(instance);
      }
      if (instance is Injectable && !instance.singelton) {
        throw StateError('CLI application binding $V must be singleton.');
      }
      _instances[V] = instance;
      return instance as V;
    } finally {
      _creating.remove(V);
    }
  }

  /// Transfers a previously assembled instance into the application's DI scope.
  @override
  V transfer<V extends Object>() {
    final value = resolve<V>();
    _owned.removeWhere((item) => identical(item, value));
    return value;
  }

  /// Returns only an already constructed instance, without invoking a builder.
  @override
  V? peek<V extends Object>() => _instances[V] as V?;

  /// Releases owned objects once, retaining a terminal until diagnostics finish.
  @override
  Future<void> destroy({Object? retained}) =>
      _destruction ??= _destroy(retained);
  Future<void> _destroy(Object? retained) async {
    Object? failure;
    StackTrace? stack;
    for (final value in _owned.reversed) {
      if (identical(value, retained)) continue;
      try {
        if (value is di.Disposable) await value.onDispose();
      } catch (e, s) {
        failure ??= e;
        stack ??= s;
      }
    }
    _owned.clear();
    if (failure != null) Error.throwWithStackTrace(failure, stack!);
  }
}
