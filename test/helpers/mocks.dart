import 'dart:io';
import 'dart:collection';
import 'package:mocktail/mocktail.dart';
import 'package:claudart/file_io.dart';
import 'package:claudart/process_runner.dart';

/// Mock file system — use [files] to pre-seed content,
/// inspect it after the call under test.
class MockFileIO extends Mock implements FileIO {}

/// Mock process runner — stub with [when] to control stdout/stderr/exitCode.
class MockProcessRunner extends Mock implements ProcessRunner {}

/// In-memory [FileIO] backed by a plain Map.
/// Simpler than [MockFileIO] when you just want realistic read/write behaviour.
class MemoryFileIO implements FileIO {
  final Map<String, String> files;
  final Set<String> dirs;
  final Set<String> links;
  MemoryFileIO({
    Map<String, String>? files,
    Set<String>? dirs,
    Set<String>? links,
  })  : files = _NormalisedKeyMap(files),
        dirs = _NormalisedKeySet(dirs),
        links = _NormalisedKeySet(links);

  /// Canonicalises paths to forward-slash form so the mock behaves
  /// identically on every platform: literal '/'-separated test constants,
  /// p.join() output ('\ ' on Windows), or mixed all collapse to '/'.
  /// Tests inspect io.files with '/'-style keys; production lookups via
  /// p.join() are normalised on the way in.
  static String _norm(String path) => path.replaceAll('\\', '/');

  @override
  String read(String path) => files[_norm(path)] ?? '';
  @override
  void write(String path, String content) => files[_norm(path)] = content;
  @override
  void writeAtomic(String path, String content) => write(path, content);
  @override
  void delete(String path) => files.remove(_norm(path));
  @override
  bool fileExists(String path) => files.containsKey(_norm(path));
  @override
  bool dirExists(String path) =>
      dirs.contains(_norm(path)) ||
      files.keys.any((k) => k.startsWith('${_norm(path)}/'));
  @override
  void createDir(String path) => dirs.add(_norm(path));
  @override
  List<String> listFiles(String dirPath, {String? extension}) {
    final dir = _norm(dirPath);
    return files.keys.where((k) {
      final inDir =
          k.startsWith('$dir/') && !k.substring(dir.length + 1).contains('/');
      return inDir && (extension == null || k.endsWith(extension));
    }).toList();
  }

  @override
  bool linkExists(String path) => links.contains(_norm(path));
  @override
  void deleteLink(String path) => links.remove(_norm(path));
  @override
  void createLink(String linkPath, String targetPath) =>
      links.add(_norm(linkPath));
}

/// A [Map] whose keys are canonicalised to forward-slash form on every
/// access — writes, lookups, and containsKey all normalise, so a path
/// built with p.join() ('\ ' on Windows) and the same path written as a
/// '/' literal address the same entry on every platform.
class _NormalisedKeyMap extends MapBase<String, String> {
  final Map<String, String> _inner = {};

  _NormalisedKeyMap([Map<String, String>? initial]) {
    initial?.forEach((k, v) => _inner[_norm(k)] = v);
  }

  static String _norm(String path) => path.replaceAll('\\', '/');

  @override
  String? operator [](Object? key) => key is String ? _inner[_norm(key)] : null;

  @override
  void operator []=(String key, String value) => _inner[_norm(key)] = value;

  @override
  void clear() => _inner.clear();

  @override
  Iterable<String> get keys => _inner.keys;

  @override
  String? remove(Object? key) =>
      key is String ? _inner.remove(_norm(key)) : null;
}

/// A [Set] with the same forward-slash canonicalisation as
/// [_NormalisedKeyMap].
class _NormalisedKeySet extends SetBase<String> {
  final Set<String> _inner = {};

  _NormalisedKeySet([Iterable<String>? initial]) {
    initial?.forEach((k) => _inner.add(_norm(k)));
  }

  static String _norm(String path) => path.replaceAll('\\', '/');

  @override
  bool add(String value) => _inner.add(_norm(value));

  @override
  bool contains(Object? element) =>
      element is String && _inner.contains(_norm(element));

  @override
  bool remove(Object? element) =>
      element is String && _inner.remove(_norm(element));

  @override
  Set<String> toSet() => _inner.toSet();

  @override
  Iterator<String> get iterator => _inner.iterator;

  @override
  int get length => _inner.length;

  @override
  String? lookup(Object? element) =>
      element is String ? _inner.lookup(_norm(element)) : null;
}

/// Returns a [ProcessResult] with the given stdout and exit code 0.
ProcessResult fakeResult(String stdout, {int exitCode = 0}) =>
    ProcessResult(0, exitCode, stdout, '');

/// Normalises a path to forward-slash form — the canonical key form used
/// by [MemoryFileIO.files]. Use when filtering `io.files.keys` with a
/// path built by p.join(), which yields '\' separators on Windows.
String normPath(String path) => path.replaceAll('\\', '/');

/// Sets up mocktail fallback values (call once in setUpAll).
void registerFallbacks() {
  registerFallbackValue(fakeResult(''));
}
