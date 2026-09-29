import 'dart:async';
import 'package:grumpy/grumpy.dart';
import 'package:grumpy_cli/src/shared/domain/models/cancellation_token.dart';
import 'package:grumpy_cli/src/terminal/domain/models/terminal_key.dart';

/// Injectable terminal IO contract for CLI output, prompts, and progress.
///
/// Command data belongs on stdout (`write`); prompts, progress and diagnostics
/// belong on stderr (`writeError`). A prompt owns input between `beginPrompt` and
/// `endPrompt`, and progress is suspended during that interval. Implementations
/// must restore modes even after read failures or cancellation.
///
/// {@category terminal}
/// Injectable IO boundary. Presentation goes to stderr; command data to stdout.
abstract class TerminalService extends Service {
  @override
  String get group => '${super.group}.TerminalService';

  /// Resolves the IO implementation registered under this terminal contract.
  factory TerminalService() => Service.get<TerminalService>();

  /// Constructor for independently implemented terminal backends.
  TerminalService.internal();

  /// Whether stdin and the diagnostic stream support interactive prompting.
  bool get interactive;

  /// Whether ANSI cursor control and keyboard menus are supported.
  bool get supportsAnsi;

  /// Writes command data to stdout without appending a newline.
  void write(String text);

  /// Writes prompts or diagnostics to stderr without appending a newline.
  void writeError(String text);

  /// Writes command data followed by a newline to stdout.
  void writeln([String text = '']) => write('$text\n');

  /// Writes diagnostic or prompt text followed by a newline to stderr.
  void errorln([String text = '']) => writeError('$text\n');

  /// Reads one line asynchronously; null signals EOF.
  ///
  /// Cancellation must throw rather than returning an ordinary input value.
  Future<String?> readLine({required CancellationToken cancellation});

  /// Reads one normalized key asynchronously; null signals EOF.
  ///
  /// Implementations must distinguish Escape/cancellation from a normal selection.
  Future<TerminalKey?> readKey({required CancellationToken cancellation});

  /// Acquires input ownership and saves terminal modes.
  ///
  /// `raw` enables keyboard selection; `secret` forbids echo. Implementations must
  /// reject overlapping sessions and recover if acquisition fails.
  void beginPrompt({bool raw = false, bool secret = false});

  /// Restores saved modes and cursor state, even after input errors.
  void endPrompt();

  /// Suspends progress rendering while a prompt owns the terminal.
  void pauseProgress();

  /// Resumes progress rendering after the matching pause.
  void resumeProgress();

  /// Displays a progress message on stderr, respecting prompt suspension.
  void progress(String message);

  /// Awaits buffered stdout and diagnostic output without closing either stream.
  Future<void> flush();
  @override
  bool get singelton => true;
  @override
  String get logTag => 'TerminalService';
}
