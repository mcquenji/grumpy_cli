import 'dart:async';
import 'package:grumpy_cli/grumpy_cli.dart';

class FakeTerminal extends TerminalService {
  FakeTerminal({
    this.interactive = true,
    this.supportsAnsi = false,
    Iterable<String?> lines = const [],
    Iterable<TerminalKey?> keys = const [],
  }) : lines = List.of(lines),
       keys = List.of(keys),
       super.internal();
  @override
  final bool interactive, supportsAnsi;
  final List<String?> lines;
  final List<TerminalKey?> keys;
  final output = StringBuffer(), diagnostics = StringBuffer();
  int begins = 0, ends = 0, pauses = 0, resumes = 0, disposals = 0;
  bool active = false, secret = false;
  final secretInputs = <bool>[];
  Future<String?> Function()? onRead;
  @override
  String get logTag => 'FakeTerminal';
  @override
  void write(String text) => output.write(text);
  @override
  void writeError(String text) => diagnostics.write(text);
  @override
  Future<String?> readLine({required CancellationToken cancellation}) async {
    secretInputs.add(secret);
    cancellation.throwIfCancelled();
    if (onRead != null) return cancellation.race(onRead!());
    return lines.isEmpty ? null : lines.removeAt(0);
  }

  @override
  Future<TerminalKey?> readKey({
    required CancellationToken cancellation,
  }) async {
    cancellation.throwIfCancelled();
    return keys.isEmpty ? null : keys.removeAt(0);
  }

  @override
  void beginPrompt({bool raw = false, bool secret = false}) {
    if (active) throw StateError('overlap');
    active = true;
    this.secret = secret;
    begins++;
  }

  @override
  void endPrompt() {
    active = false;
    secret = false;
    ends++;
  }

  @override
  void pauseProgress() {
    pauses++;
  }

  @override
  void resumeProgress() {
    resumes++;
  }

  @override
  void progress(String message) {
    diagnostics.writeln(message);
  }

  @override
  Future<void> flush() async {}
  @override
  Future<void> destroy() async {
    disposals++;
  }
}
