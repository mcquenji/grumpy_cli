import 'package:grumpy_io/grumpy_io.dart';

/// In-memory filesystem for tests and tools that should not create config files.
class MemoryFileSystemService extends FileSystemService {
  /// Creates an isolated file store.
  MemoryFileSystemService() : super.internal();

  /// File contents keyed by path, useful for seeding a test environment.
  final Map<String, Bytes> files = {};
  @override
  Future<IoResult<bool>> exists(IoPath path) async =>
      IoOk(files.containsKey(path.value));
  @override
  Future<IoResult<Bytes>> readBytes(IoPath file) async =>
      files.containsKey(file.value)
      ? IoOk(Bytes.fromList(files[file.value]!))
      : IoErr(
          IoFailure(
            code: IoFailureCode.notFound,
            message: 'File not found',
            details: {'path': file.value},
          ),
        );
  @override
  Future<IoResult<void>> replaceBytes(IoPath file, Bytes bytes) async {
    files[file.value] = Bytes.fromList(bytes);
    return const IoOk(null);
  }

  @override
  Future<IoResult<void>> writeBytes(
    IoPath file,
    Bytes bytes, {
    bool overwrite = true,
    bool createParents = true,
  }) async {
    if (!overwrite && files.containsKey(file.value)) {
      return const IoErr(
        IoFailure(code: IoFailureCode.alreadyExists, message: 'File exists'),
      );
    }
    return replaceBytes(file, bytes);
  }

  @override
  Future<IoResult<void>> delete(IoPath path, {bool recursive = false}) async {
    files.remove(path.value);
    return const IoOk(null);
  }

  @override
  Future<IoResult<FsMetadata>> stat(IoPath path) async =>
      const IoErr.unsupported('stat');
  @override
  Future<IoResult<void>> createDirectory(
    IoPath directory, {
    bool recursive = true,
  }) async => const IoOk(null);
  @override
  Future<IoResult<List<IoPath>>> list(
    IoPath directory, {
    bool recursive = false,
  }) async => IoOk(
    files.keys
        .where((path) => path.startsWith('${directory.value}/'))
        .map(IoPath.new)
        .toList(),
  );
  @override
  Future<IoResult<void>> move(
    IoPath from,
    IoPath to, {
    bool overwrite = false,
  }) async => const IoErr.unsupported('move');
  @override
  Future<IoResult<void>> copy(
    IoPath from,
    IoPath to, {
    bool overwrite = false,
  }) async => const IoErr.unsupported('copy');
  @override
  String get logTag => 'MemoryFileSystemService';
  @override
  Future<void> destroy() async {}
}
