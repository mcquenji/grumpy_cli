import 'package:grumpy_cli/src/arguments/domain/models/cli_argument.dart';
import 'package:grumpy_cli/src/shared/domain/models/cli_value_type.dart';

/// A boolean switch that preserves omission separately from explicit false.
///
/// With `negatable` enabled, `--no-feature` supplies false while `--feature`
/// supplies true. An omitted flag has no explicit value even when its declared
/// default is false. Short abbreviations and long aliases share the same handle.
///
/// {@category arguments}
class CliFlag extends CliArgument<bool> {
  /// Declares a boolean switch; negation is enabled by default.
  CliFlag(
    super.name, {
    super.description,
    bool defaultValue = false,
    this.abbreviation,
    this.aliases = const [],
    this.negatable = true,
  }) : super(type: CliValueType.boolean(), defaultValue: defaultValue);
  @override
  final String? abbreviation;
  @override
  final List<String> aliases;

  /// Whether `--no-name` and negated long aliases explicitly supply false.
  final bool negatable;
  @override
  Object? parseRaw(Object? value) => type.decode(value);
}
