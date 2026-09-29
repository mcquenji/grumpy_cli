import 'package:grumpy_cli/src/arguments/domain/models/cli_argument.dart';
import 'package:grumpy_cli/src/shared/domain/models/cli_value_type.dart';

/// All remaining positional arguments as a typed, immutable list.
///
/// This must be the final positional declaration. Tokens following `--` remain
/// literal values, including strings that resemble flags. A required rest
/// parameter must receive at least one explicit value.
///
/// {@category arguments}
class CliRestParameter<T> extends CliArgument<List<T>> {
  /// Declares the final positional list and its element codec.
  CliRestParameter(
    super.name, {
    required this.elementType,
    super.description,
    List<T>? defaultValue,
    super.required,
  }) : super(
         type: CliValueType.list(elementType),
         defaultValue: defaultValue ?? <T>[],
       );

  /// Codec applied independently to each raw value before constructing the list.
  final CliValueType<T> elementType;
  @override
  bool get positional => true;
  @override
  bool get multiple => true;
  @override
  Object? parseRaw(Object? value) =>
      List<T>.unmodifiable((value as List<String>).map(elementType.parse));
}
