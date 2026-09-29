import 'package:grumpy_cli/src/arguments/domain/models/cli_argument.dart';
import 'package:grumpy_cli/src/shared/domain/models/cli_value_type.dart';

/// Repeated named values, converted individually and retained in input order.
///
/// `--tag=a,b --tag=c` produces two string values, `a,b` and `c`; commas are never
/// split implicitly. Values inherited across command levels retain their order.
/// The resolved default is an empty list unless specified otherwise.
///
/// {@category arguments}
class CliMultiOption<T> extends CliArgument<List<T>> {
  /// Declares a repeatable option with an independent codec for each value.
  CliMultiOption(
    super.name, {
    required this.elementType,
    super.description,
    List<T>? defaultValue,
    super.required,
    this.abbreviation,
    this.aliases = const [],
  }) : super(
         type: CliValueType.list(elementType),
         defaultValue: defaultValue ?? <T>[],
       );

  /// Codec applied independently to each raw value before constructing the list.
  final CliValueType<T> elementType;
  @override
  final String? abbreviation;
  @override
  final List<String> aliases;
  @override
  bool get multiple => true;
  @override
  Object? parseRaw(Object? value) =>
      List<T>.unmodifiable((value as List<String>).map(elementType.parse));
}
