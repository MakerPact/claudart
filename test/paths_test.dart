import 'package:test/test.dart';
import 'package:claudart/paths.dart';
import 'package:path/path.dart' as p;

void main() {
  group('Paths', () {
    test('archiveDirFor returns the correct archive directory path', () {
      const workspacePath = '/fake/workspace/path';
      final expectedPath = p.join(workspacePath, 'archive');

      expect(archiveDirFor(workspacePath), equals(expectedPath));
    });
  });
}
