import 'package:test/test.dart';
import 'package:claudart/paths.dart';
import 'package:path/path.dart' as p;

void main() {
  group('Workspace Path Functions', () {
    test('handoffPathFor joins workspace with handoff.md', () {
      final ws = '/fake/workspace';
      final expectedPath = p.join(ws, 'handoff.md');
      expect(handoffPathFor(ws), equals(expectedPath));
    });

    test('skillsPathFor joins workspace with skills.md', () {
      final ws = '/fake/workspace';
      final expectedPath = p.join(ws, 'skills.md');
      expect(skillsPathFor(ws), equals(expectedPath));
    });

    test('pendingConfirmationPathFor joins workspace with pending_confirmation.json', () {
      final ws = '/fake/workspace';
      final expectedPath = p.join(ws, 'pending_confirmation.json');
      expect(pendingConfirmationPathFor(ws), equals(expectedPath));
    });

    test('archiveDirFor joins workspace with archive', () {
      final ws = '/fake/workspace';
      final expectedPath = p.join(ws, 'archive');
      expect(archiveDirFor(ws), equals(expectedPath));
    });

    test('configPathFor joins workspace with config.json', () {
      final ws = '/fake/workspace';
      final expectedPath = p.join(ws, 'config.json');
      expect(configPathFor(ws), equals(expectedPath));
    });

    test('knowledgeDirFor joins workspace with knowledge', () {
      final ws = '/fake/workspace';
      final expectedPath = p.join(ws, 'knowledge');
      expect(knowledgeDirFor(ws), equals(expectedPath));
    });

    test('genericKnowledgeDirFor joins workspace with knowledge/generic', () {
      final ws = '/fake/workspace';
      final expectedPath = p.join(ws, 'knowledge', 'generic');
      expect(genericKnowledgeDirFor(ws), equals(expectedPath));
    });

    test('projectsKnowledgeDirFor joins workspace with knowledge/projects', () {
      final ws = '/fake/workspace';
      final expectedPath = p.join(ws, 'knowledge', 'projects');
      expect(projectsKnowledgeDirFor(ws), equals(expectedPath));
    });

    test('claudeCommandsDirFor joins workspace with .claude/commands', () {
      final ws = '/fake/workspace';
      final expectedPath = p.join(ws, '.claude', 'commands');
      expect(claudeCommandsDirFor(ws), equals(expectedPath));
    });

    test('tokenMapPathFor joins workspace with token_map.json', () {
      final ws = '/fake/workspace';
      final expectedPath = p.join(ws, 'token_map.json');
      expect(tokenMapPathFor(ws), equals(expectedPath));
    });

    test('logsDirFor joins workspace with logs', () {
      final ws = '/fake/workspace';
      final expectedPath = p.join(ws, 'logs');
      expect(logsDirFor(ws), equals(expectedPath));
    });

    test('experimentsDirFor joins workspace with experiments', () {
      final ws = '/fake/workspace';
      final expectedPath = p.join(ws, 'experiments');
      expect(experimentsDirFor(ws), equals(expectedPath));
        main
    });
  });
}
