import 'package:grumpy_cli/grumpy_cli.dart';
import 'package:grumpy_io/grumpy_io.dart';
import 'app.dart';
import 'shared/domain/models/app_config.g.dart';
import 'shared/infra/services/memory_file_system_service.dart';

/// Runs the same application with in-memory configuration files.
class MemoryApp extends App {
  /// Creates an application with isolated storage.
  MemoryApp();
  @override
  String get logTag => 'MemoryApp';
  @override
  InjectableFactory<FileSystemService, AppConfig>
  get fileSystemServiceBuilder =>
      (_, _) => MemoryFileSystemService();
}
