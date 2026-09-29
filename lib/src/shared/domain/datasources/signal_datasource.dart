import 'package:grumpy/grumpy.dart';

/// Injectable source of process cancellation requests.
abstract class SignalDatasource extends Datasource {
  /// Resolves the registered cancellation-event source.
  factory SignalDatasource() => Datasource.get<SignalDatasource>();

  /// Constructor for native or embedded signal sources.
  SignalDatasource.internal();

  /// Subscribing starts observation; cancelling releases native subscriptions.
  Stream<void> get cancellations;
  @override
  bool get singelton => true;
  @override
  String get group => '${super.group}.SignalDatasource';
}
