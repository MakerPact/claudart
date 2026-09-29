import 'package:test/test.dart';
import 'package:path/path.dart' as p;
import 'package:claudart/paths.dart';

void main() {
  group('per-workspace path functions', () {
    const workspace = '/mock/workspace';

    test('workspaceFor returns correct path', () {
      const projectName = 'test_project';
      expect(workspaceFor(projectName), equals(p.join(workspacesRoot, projectName)));
    });

    test('handoffPathFor returns correct path', () {
      expect(handoffPathFor(workspace), equals(p.join(workspace, 'handoff.md')));
    });

    test('skillsPathFor returns correct path', () {
      expect(skillsPathFor(workspace), equals(p.join(workspace, 'skills.md')));
    });

    test('pendingConfirmationPathFor returns correct path', () {
      expect(pendingConfirmationPathFor(workspace), equals(p.join(workspace, 'pending_confirmation.json')));
    });

    test('archiveDirFor returns correct path', () {
      expect(archiveDirFor(workspace), equals(p.join(workspace, 'archive')));
    });

    test('configPathFor returns correct path', () {
      expect(configPathFor(workspace), equals(p.join(workspace, 'config.json')));
    });

    test('knowledgeDirFor returns correct path', () {
      expect(knowledgeDirFor(workspace), equals(p.join(workspace, 'knowledge')));
    });

    test('genericKnowledgeDirFor returns correct path', () {
      expect(genericKnowledgeDirFor(workspace), equals(p.join(workspace, 'knowledge', 'generic')));
    });

    test('projectsKnowledgeDirFor returns correct path', () {
      expect(projectsKnowledgeDirFor(workspace), equals(p.join(workspace, 'knowledge', 'projects')));
    });

    test('claudeCommandsDirFor returns correct path', () {
      expect(claudeCommandsDirFor(workspace), equals(p.join(workspace, '.claude', 'commands')));
    });

    test('tokenMapPathFor returns correct path', () {
      expect(tokenMapPathFor(workspace), equals(p.join(workspace, 'token_map.json')));
    });

    test('logsDirFor returns correct path', () {
      expect(logsDirFor(workspace), equals(p.join(workspace, 'logs')));
    });

    test('experimentsDirFor returns correct path', () {
      expect(experimentsDirFor(workspace), equals(p.join(workspace, 'experiments')));
    });
  });

  group('per-project-root path functions', () {
    const projectRoot = '/mock/project_root';

    test('claudeMdPathFor returns correct path', () {
      expect(claudeMdPathFor(projectRoot), equals(p.join(projectRoot, 'CLAUDE.md')));
    });
  });
}
