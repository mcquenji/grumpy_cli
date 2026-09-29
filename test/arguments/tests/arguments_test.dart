import 'package:grumpy_cli/grumpy_cli.dart';
import 'package:test/test.dart';

enum Mode { fast, safe }

void main() {
  test(
    'typed options track presence, negation, scalar last-wins and aliases',
    () {
      final port = CliOption<int>(
        'port',
        type: CliValueType.integer(min: 1, max: 65535),
        abbreviation: 'p',
        aliases: ['listen'],
      );
      final flag = CliFlag('feature', defaultValue: true);
      final schema = ArgumentSchema(arguments: [port, flag]);
      final absent = schema.parse([]);
      expect(absent.provided(flag), isNull);
      expect(absent.get(flag), isTrue);
      final args = schema.parse([
        '--port',
        '1234',
        '--listen=4567',
        '--no-feature',
      ]);
      expect(args.require(port), 4567);
      expect(args.provided(flag), false);
      expect(
        () => schema.parse(['--port=70000']),
        throwsA(isA<CliUsageException>()),
      );
    },
  );
  test(
    'repeated options preserve commas and order, -- preserves positional values',
    () {
      final tags = CliMultiOption<String>(
        'tag',
        elementType: CliValueType.string(),
      );
      final files = CliRestParameter<String>(
        'files',
        elementType: CliValueType.path(),
      );
      final schema = ArgumentSchema(arguments: [tags, files]);
      final result = schema.parse([
        '--tag=a,b',
        '--tag=c',
        '--',
        '--literal',
        'has spaces',
      ]);
      expect(result.require(tags), ['a,b', 'c']);
      expect(result.require(files), ['--literal', 'has spaces']);
    },
  );
  test('required positional values, defaults, choices and extra arguments', () {
    final count = CliParameter<int>(
      'count',
      type: CliValueType.integer(),
      required: true,
    );
    final mode = CliOption<Mode>(
      'mode',
      type: CliValueType.enumeration(Mode.values),
      defaultValue: Mode.safe,
    );
    final schema = ArgumentSchema(arguments: [count, mode]);
    expect(schema.parse(['3']).require(mode), Mode.safe);
    expect(schema.parse(['3', '--mode=fast']).require(mode), Mode.fast);
    expect(() => schema.parse([]), throwsA(isA<CliUsageException>()));
    expect(() => schema.parse(['1', '2']), throwsA(isA<CliUsageException>()));
    expect(
      () => schema.parse(['1', '--mode=unknown']),
      throwsA(isA<CliUsageException>()),
    );
  });
  test('declaration conflicts and invalid positionals are rejected', () {
    expect(
      () => ArgumentSchema(arguments: [CliFlag('help')]).parse([]),
      throwsArgumentError,
    );
    expect(
      () => ArgumentSchema(
        arguments: [CliFlag('foo'), CliFlag('no-foo')],
      ).parse([]),
      throwsArgumentError,
    );
    expect(
      () => ArgumentSchema(
        arguments: [CliFlag('foo', abbreviation: 'xx')],
      ).parse([]),
      throwsArgumentError,
    );
    expect(
      () => ArgumentSchema(
        arguments: [
          CliParameter('x', type: CliValueType.string()),
          CliParameter('y', type: CliValueType.string(), required: true),
        ],
      ).parse([]),
      throwsArgumentError,
    );
  });
  test('relationships use explicit presence and enforce dependencies', () {
    final a = CliFlag('alpha'), b = CliFlag('beta'), c = CliFlag('gamma');
    final schema = ArgumentSchema(
      arguments: [a, b, c],
      exclusive: [
        [a, b],
      ],
      dependencies: {
        a: [c],
      },
    );
    expect(() => schema.parse(['--alpha']), throwsA(isA<CliUsageException>()));
    expect(
      () => schema.parse(['--alpha', '--beta', '--gamma']),
      throwsA(isA<CliUsageException>()),
    );
    expect(schema.parse(['--no-alpha', '--gamma']).provided(a), false);
    expect(() => schema.parse([]).get(CliFlag('other')), throwsArgumentError);
  });
  test('value types validate config and text consistently', () {
    final integer = CliValueType.integer(min: 1, max: 5);
    expect(integer.decode(3), 3);
    expect(() => integer.decode('3'), throwsA(isA<CliUsageException>()));
    expect(() => integer.encode(0), throwsA(isA<CliUsageException>()));
    expect(
      () => CliValueType.decimal().parse('NaN'),
      throwsA(isA<CliUsageException>()),
    );
    expect(CliValueType.boolean().parse('yes'), true);
    expect(
      CliValueType.uri(absolute: true).parse('https://example.com').host,
      'example.com',
    );
    expect(
      () => CliValueType.uri(absolute: true).parse('/relative'),
      throwsA(isA<CliUsageException>()),
    );
    final list = CliValueType.list(integer, unique: true);
    expect(list.parse('[1,2]'), [1, 2]);
    expect(() => list.decode([1, 1]), throwsA(isA<CliUsageException>()));
    final object = CliValueType.object<Map<String, Object?>>(
      properties: {'count': integer},
      required: ['count'],
      fromJson: (v) => v,
      toJson: (v) => v,
    );
    expect(object.parse('{"count":2}'), {'count': 2});
    expect(
      () => object.decode({'extra': 1}),
      throwsA(isA<CliUsageException>()),
    );
  });
  test(
    'alternate parsers bind typed values with defaults and presence validation',
    () {
      final port = CliOption<int>(
        'port',
        type: CliValueType.integer(min: 1),
        defaultValue: 80,
      );
      final feature = CliFlag('feature', defaultValue: true);
      final schema = ArgumentSchema(arguments: [port, feature]);
      final values = schema.bind({feature: false});
      expect(values.provided(port), null);
      expect(values.get(port), 80);
      expect(values.provided(feature), false);
      expect(values.wasProvided(feature), true);
      expect(
        () => schema.bind({port: 'invalid'}),
        throwsA(isA<CliUsageException>()),
      );
      expect(() => schema.bind({port: 0}), throwsA(isA<CliUsageException>()));
      expect(
        () => schema.bind({CliFlag('unknown'): true}),
        throwsArgumentError,
      );
      final required = CliMultiOption<int>(
        'ids',
        elementType: CliValueType.integer(),
        required: true,
      );
      expect(
        () => ArgumentSchema(arguments: [required]).bind({required: <int>[]}),
        throwsA(isA<CliUsageException>()),
      );
      expect(
        () => ArgumentSchema(
          arguments: [port, feature],
          dependencies: {
            feature: [port],
          },
        ).bind({feature: false}),
        throwsA(isA<CliUsageException>()),
      );
    },
  );
}
