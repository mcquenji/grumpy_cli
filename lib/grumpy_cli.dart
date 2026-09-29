/// Command-line adapters for Grumpy modules, routing, typed input and terminal IO.
///
/// Import this library to build a CLI; feature barrels under `src` organize the
/// implementation and are not required for application code.
library;

export 'package:grumpy/grumpy.dart';
export 'src/arguments/arguments.dart';
export 'src/config/config.dart';
export 'src/shared/shared.dart';
export 'src/terminal/terminal.dart';

export 'package:grumpy_annotations/grumpy_annotations.dart'
    show Config, ConfigField, ConfigScope, config, localConfig;
