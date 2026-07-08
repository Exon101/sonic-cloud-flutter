// Platform-agnostic file system stubs for web.
//
// On mobile/desktop, the real implementations (using dart:io File/Directory)
// are imported via conditional imports in the consuming files. On web, this
// stub provides no-op implementations so the code compiles.
//
// Web browsers don't have a traditional file system — file access goes
// through the File System Access API or file pickers, not dart:io.

/// A no-op file system entity stub for web. This is the base class that
/// File and Directory extend, matching dart:io's hierarchy.
class FileSystemEntity {
  final String path;
  FileSystemEntity(this.path);

  Future<FileStat> stat() async => FileStat._empty;
}

/// A no-op file stub for web. Extends FileSystemEntity to match dart:io.
class File extends FileSystemEntity {
  File(String path) : super(path);

  Future<bool> exists() async => false;
  Future<String> readAsString() async => throw UnsupportedError('File.readAsString not supported on web');
  Future<void> writeAsString(String contents) async => throw UnsupportedError('File.writeAsString not supported on web');
  Future<void> delete() async => throw UnsupportedError('File.delete not supported on web');
}

/// A no-op directory stub for web. Extends FileSystemEntity to match dart:io.
/// Includes the followLinks parameter that callers pass.
class Directory extends FileSystemEntity {
  Directory(String path) : super(path);

  Future<bool> exists() async => false;
  Future<Directory> create({bool recursive = false}) async => this;
  Stream<FileSystemEntity> list({bool recursive = false, bool followLinks = true}) async* {}
}

/// A no-op FileStat stub for web.
class FileStat {
  static final FileStat _empty = FileStat._();
  FileStat._();

  DateTime get modified => DateTime.fromMillisecondsSinceEpoch(0);
  DateTime get accessed => DateTime.fromMillisecondsSinceEpoch(0);
  DateTime get changed => DateTime.fromMillisecondsSinceEpoch(0);
  int get size => 0;
  FileSystemEntityType get type => FileSystemEntityType.notFound;
}

/// A no-op file system entity type enum.
enum FileSystemEntityType {
  file,
  directory,
  link,
  notFound,
}

/// A no-op random-access file stub for web.
class RandomAccessFile {
  Future<int> length() async => 0;
  Future<void> close() async {}
  Future<List<int>> read(int count) async => [];
}

/// Platform stub for web. On mobile/desktop, dart:io's Platform is used.
/// On web, all checks return false — callers should guard with kIsWeb first.
class Platform {
  static bool get isAndroid => false;
  static bool get isIOS => false;
  static bool get isMacOS => false;
  static bool get isWindows => false;
  static bool get isLinux => false;
  static bool get isWeb => true;
}
