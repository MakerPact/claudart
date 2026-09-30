import 'package:test/test.dart';
import 'package:claudart/paths.dart';
import 'package:path/path.dart' as p;

void main() {
  group('Workspace Path Functions', () {
    test('workspaceFor joins workspacesRoot with projectName', () {
      const projectName = 'test_project';
      final expectedPath = p.join(workspacesRoot, projectName);
      expect(workspaceFor(projectName), equals(expectedPath));
    });

    test('handoffPathFor joins workspace with handoff.md', () {
      const ws = '/fake/workspace';
      final expectedPath = p.join(ws, 'handoff.md');
      expect(handoffPathFor(ws), equals(expectedPath));
    });

    test('skillsPathFor joins workspace with skills.md', () {
      const ws = '/fake/workspace';
      final expectedPath = p.join(ws, 'skills.md');
      expect(skillsPathFor(ws), equals(expectedPath));
    });

    test(
        'pendingConfirmationPathFor joins workspace with pending_confirmation.json',
        () {
      const ws = '/fake/workspace';
      final expectedPath = p.join(ws, 'pending_confirmation.json');
      expect(pendingConfirmationPathFor(ws), equals(expectedPath));
    });

    test('archiveDirFor joins workspace with archive', () {
      const ws = '/fake/workspace';
      final expectedPath = p.join(ws, 'archive');
      expect(archiveDirFor(ws), equals(expectedPath));
    });

    group('configPathFor', () {
      test('joins workspace with config.json', () {
        const ws = '/fake/workspace';
        final expectedPath = p.join(ws, 'config.json');
        expect(configPathFor(ws), equals(expectedPath));
      });
      test('handles empty workspace string correctly', () {
        const ws = '';
        final expectedPath = p.join(ws, 'config.json');
        expect(configPathFor(ws), equals(expectedPath));
      });
      test('handles workspace with trailing slash', () {
        const ws = '/fake/workspace/';
        final expectedPath = p.join(ws, 'config.json');
        expect(configPathFor(ws), equals(expectedPath));
      });
    });

    test('knowledgeDirFor joins workspace with knowledge', () {
      const ws = '/fake/workspace';
      final expectedPath = p.join(ws, 'knowledge');
      expect(knowledgeDirFor(ws), equals(expectedPath));
    });

    test('knowledgeDirFor joins workspace with knowledge', () {
      const ws = '/fake/workspace';
      final expectedPath = p.join(ws, 'knowledge');
      expect(knowledgeDirFor(ws), equals(expectedPath));
    });

    test('genericKnowledgeDirFor joins workspace with knowledge/generic', () {
      const ws = '/fake/workspace';
      final expectedPath = p.join(ws, 'knowledge', 'generic');
      expect(genericKnowledgeDirFor(ws), equals(expectedPath));
    });

    test('projectsKnowledgeDirFor joins workspace with knowledge/projects', () {
      const ws = '/fake/workspace';
      final expectedPath = p.join(ws, 'knowledge', 'projects');
      expect(projectsKnowledgeDirFor(ws), equals(expectedPath));
    });

    test('claudeCommandsDirFor joins workspace with .claude/commands', () {
      const ws = '/fake/workspace';
      final expectedPath = p.join(ws, '.claude', 'commands');
      expect(claudeCommandsDirFor(ws), equals(expectedPath));
    });

    test('tokenMapPathFor joins workspace with token_map.json', () {
      const ws = '/fake/workspace';
      final expectedPath = p.join(ws, 'token_map.json');
      expect(tokenMapPathFor(ws), equals(expectedPath));
    });

    test('logsDirFor joins workspace with logs', () {
      const ws = '/fake/workspace';
      final expectedPath = p.join(ws, 'logs');
      expect(logsDirFor(ws), equals(expectedPath));
    });

    test('experimentsDirFor joins workspace with experiments', () {
      const ws = '/fake/workspace';
      final expectedPath = p.join(ws, 'experiments');
      expect(experimentsDirFor(ws), equals(expectedPath));
    });
  });
}
