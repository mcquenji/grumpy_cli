import 'dart:convert';
import 'package:grumpy_io/grumpy_io.dart';
import '../../domain/datasources/config_datasource.dart';
import '../../../shared/domain/exceptions/cli_usage_exception.dart';

/// Stores configuration through the application's selected filesystem service.
class FileConfigDatasource extends ConfigDatasource {
  /// Borrows [fileSystemService]; replace it to use another filesystem backend.
  FileConfigDatasource({required this.fileSystemService}) : super.internal();

  /// Filesystem implementation selected by the host.
  final FileSystemService fileSystemService;

  T _unwrap<T>(IoResult<T> result) => switch (result) {
    IoOk<T>(:final value) => value,
    IoErr<T>(:final failure) => throw CliUsageException(
      '${failure.message} (${failure.code.name}) ${failure.details}',
    ),
  };

  @override
  Future<bool> exists(String path) async =>
      _unwrap(await fileSystemService.exists(IoPath(path)));

  @override
  Future<String?> read(String path) async {
    final result = await fileSystemService.readBytes(IoPath(path));
    if (result case IoErr(failure: IoFailure(code: IoFailureCode.notFound))) {
      return null;
    }
    return utf8.decode(_unwrap(result));
  }

  @override
  Future<void> replace(String path, String contents, {String? expected}) async {
    if (await read(path) != expected) {
      throw CliUsageException(
        'Config changed while editing: $path. Reload before saving.',
      );
    }
    _unwrap(
      await fileSystemService.replaceBytes(
        IoPath(path),
        Bytes.fromList(utf8.encode(contents)),
      ),
    );
  }

  @override
  String get logTag => 'FileConfigDatasource';
  @override
  Future<void> destroy() async {}
}
