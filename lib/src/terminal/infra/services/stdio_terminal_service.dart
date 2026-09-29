import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:grumpy_cli/src/shared/domain/exceptions/cli_cancelled.dart';
import 'package:grumpy_cli/src/shared/domain/models/cancellation_token.dart';
import 'package:grumpy_cli/src/terminal/domain/models/terminal_key.dart';
import 'package:grumpy_cli/src/terminal/domain/services/terminal_service.dart';

/// Native asynchronous stdin/stdout/stderr implementation of terminal IO.
///
/// Input is incrementally decoded as UTF-8. Prompt sessions disable native echo
/// and handle editing and Ctrl-D directly so cancellation cannot close stdin
/// before terminal modes are restored. Secret input is never echoed.
///
/// Destruction restores modes, cancels the input subscription and flushes output;
/// it does not close the process's output streams.
///
/// {@category terminal}
/// Native terminal backend with asynchronous input and incremental UTF-8 decoding.
class StdioTerminalService extends TerminalService {
  @override
  String get logTag => 'StdioTerminalService';

  /// Creates native IO with optional stream and capability overrides.
  ///
  /// Defaults use process stdin/stdout/stderr. Capability overrides are useful for
  /// controlled embedders and tests; they do not make a pipe safe for secret input.
  StdioTerminalService({
    Stdin? input,
    IOSink? output,
    IOSink? diagnostics,
    bool? interactive,
    bool? ansi,
  }) : _input = input ?? stdin,
       _output = output ?? stdout,
       _diagnostics = diagnostics ?? stderr,
       _interactive = interactive,
       _ansi = ansi,
       super.internal();
  final Stdin _input;
  final IOSink _output, _diagnostics;
  final bool? _interactive, _ansi;
  StreamSubscription<String>? _subscription;
  final List<String> _characters = [];
  Completer<String?>? _waiting;
  bool _done = false;
  bool _prompt = false;
  bool _manualEcho = false;
  bool? _savedEcho, _savedLineMode;
  int _progressPauseDepth = 0;
  String? _progress;
  bool _afterCr = false;
  @override
  bool get interactive =>
      _interactive ??
      (_input.hasTerminal &&
          (_diagnostics is Stdout && (_diagnostics).hasTerminal));
  @override
  bool get supportsAnsi =>
      _ansi ??
      (interactive &&
          Platform.environment['TERM'] != 'dumb' &&
          _diagnostics is Stdout &&
          (_diagnostics).supportsAnsiEscapes);
  @override
  void write(String text) => _output.write(text);
  @override
  void writeError(String text) => _diagnostics.write(text);

  void _startInput() {
    _subscription ??= _input
        .transform(utf8.decoder)
        .listen(
          (chunk) {
            _characters.addAll(chunk.runes.map(String.fromCharCode));
            _deliver();
          },
          onDone: () {
            _done = true;
            _deliver();
          },
          onError: (Object error, StackTrace stack) {
            _done = true;
            final waiting = _waiting;
            _waiting = null;
            if (waiting != null) waiting.completeError(error, stack);
          },
        );
  }

  void _deliver() {
    if (_waiting == null || _characters.isEmpty && !_done) return;
    final waiting = _waiting!;
    _waiting = null;
    waiting.complete(_characters.isEmpty ? null : _characters.removeAt(0));
  }

  Future<String?> _character(
    CancellationToken token, {
    Duration? timeout,
  }) async {
    token.throwIfCancelled();
    _startInput();
    if (_characters.isNotEmpty) return _characters.removeAt(0);
    if (_done) return null;
    if (_waiting != null) {
      throw StateError('Concurrent terminal input is not supported.');
    }
    final waiting = Completer<String?>();
    _waiting = waiting;
    Timer? timer;
    if (timeout != null) {
      timer = Timer(timeout, () {
        if (identical(_waiting, waiting)) {
          _waiting = null;
          waiting.complete(null);
        }
      });
    }
    try {
      return await token.race(waiting.future);
    } finally {
      timer?.cancel();
      if (identical(_waiting, waiting)) _waiting = null;
    }
  }

  /// Reads decoded text with manual echo when appropriate.
  ///
  /// Backspace removes one Unicode scalar; Ctrl-U clears the line. Ctrl-C, Ctrl-D,
  /// and Escape cancel rather than returning partial input.
  @override
  Future<String?> readLine({required CancellationToken cancellation}) async {
    final text = <String>[];
    while (true) {
      final character = await _character(cancellation);
      if (character == null) return text.isEmpty ? null : text.join();
      if (_afterCr) {
        _afterCr = false;
        if (character == '\n') continue;
      }
      if (character == '\x03' || character == '\x04' || character == '\x1b') {
        throw const CliCancelled();
      }
      if (character == '\r' || character == '\n') {
        _afterCr = character == '\r';
        if (_manualEcho) errorln();
        return text.join();
      }
      if (character == '\x7f' || character == '\b') {
        if (text.isNotEmpty) {
          text.removeLast();
          if (_manualEcho) writeError('\b \b');
        }
      } else if (character == '\x15') {
        if (_manualEcho) writeError('\b \b' * text.length);
        text.clear();
      } else {
        text.add(character);
        if (_manualEcho) writeError(character);
      }
    }
  }

  /// Decodes arrow escape sequences, Space and Enter for menu input.
  @override
  Future<TerminalKey?> readKey({
    required CancellationToken cancellation,
  }) async {
    final character = await _character(cancellation);
    if (character == null) return null;
    if (character == '\x03' || character == '\x04') throw const CliCancelled();
    if (character == '\x1b') {
      final next = await _character(
        cancellation,
        timeout: const Duration(milliseconds: 60),
      );
      if (next != '[' && next != 'O') return TerminalKey.escape;
      final code = await _character(
        cancellation,
        timeout: const Duration(milliseconds: 60),
      );
      return switch (code) {
        'A' => TerminalKey.up,
        'B' => TerminalKey.down,
        'C' => TerminalKey.right,
        'D' => TerminalKey.left,
        _ => TerminalKey.other,
      };
    }
    return switch (character) {
      ' ' => TerminalKey.space,
      '\r' || '\n' => TerminalKey.enter,
      _ => TerminalKey.other,
    };
  }

  /// Saves modes, disables native echo, and acquires a single input session.
  ///
  /// Line prompts manually echo non-secret text and support Backspace/Ctrl-U.
  @override
  void beginPrompt({bool raw = false, bool secret = false}) {
    if (_prompt) throw StateError('A terminal prompt is already active.');
    _prompt = true;
    try {
      if (_input.hasTerminal) {
        _savedEcho = _input.echoMode;
        _savedLineMode = _input.lineMode;
        // Read Ctrl-D as a cancellation key rather than allowing the platform
        // stdin stream to close its descriptor before modes can be restored.
        _input.echoMode = false;
        _input.lineMode = false;
        _manualEcho = !raw && !secret;
      } else if (secret) {
        throw StateError('Secret input requires a terminal.');
      }
      if (raw && supportsAnsi) writeError('\x1b[?25l');
    } catch (_) {
      endPrompt();
      rethrow;
    }
  }

  /// Restores saved line/echo modes and shows the cursor in all completion paths.
  @override
  void endPrompt() {
    if (!_prompt) return;
    try {
      if (_savedLineMode != null) _input.lineMode = _savedLineMode!;
    } finally {
      try {
        if (_savedEcho != null) _input.echoMode = _savedEcho!;
      } finally {
        _savedEcho = null;
        _savedLineMode = null;
        _manualEcho = false;
        _prompt = false;
        if (supportsAnsi) writeError('\x1b[?25h');
      }
    }
  }

  @override
  void pauseProgress() {
    if (_progressPauseDepth++ == 0 && _progress != null && supportsAnsi) {
      writeError('\r\x1b[2K');
    }
  }

  @override
  void resumeProgress() {
    if (_progressPauseDepth == 0) return;
    if (--_progressPauseDepth == 0 && _progress != null) progress(_progress!);
  }

  @override
  void progress(String message) {
    _progress = message;
    if (_progressPauseDepth > 0) return;
    if (supportsAnsi) {
      writeError('\r\x1b[2K$message');
    } else {
      errorln(message);
    }
  }

  @override
  Future<void> flush() async {
    await _output.flush();
    await _diagnostics.flush();
  }

  /// Restores modes, stops stdin listening, and flushes both output streams once.
  @override
  Future<void> destroy() async {
    endPrompt();
    if (_progress != null && supportsAnsi) writeError('\r\x1b[2K');
    await _subscription?.cancel();
    _subscription = null;
    _done = true;
    _deliver();
    await flush();
  }
}
