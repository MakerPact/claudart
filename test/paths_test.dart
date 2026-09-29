import 'package:test/test.dart';
import 'package:path/path.dart' as p;
import 'package:claudart/paths.dart';

void main() {
  group('workspaceFor', () {
    test('returns correct path joined with workspacesRoot', () {
      const projectName = 'test_project';
      final expectedPath = p.join(workspacesRoot, projectName);

      expect(workspaceFor(projectName), equals(expectedPath));
    });
  });
}
