import 'package:claudart/paths.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('Per-workspace path functions', () {
    const ws = 'my_ws';

    test('handoffPathFor', () {
      expect(handoffPathFor(ws), p.join(ws, 'handoff.md'));
    });

    test('skillsPathFor', () {
      expect(skillsPathFor(ws), p.join(ws, 'skills.md'));
    });

    test('pendingConfirmationPathFor', () {
      expect(pendingConfirmationPathFor(ws), p.join(ws, 'pending_confirmation.json'));
    });

    test('archiveDirFor', () {
      expect(archiveDirFor(ws), p.join(ws, 'archive'));
    });

    test('configPathFor', () {
      expect(configPathFor(ws), p.join(ws, 'config.json'));
    });

    test('knowledgeDirFor', () {
      expect(knowledgeDirFor(ws), p.join(ws, 'knowledge'));
    });

    test('genericKnowledgeDirFor', () {
      expect(genericKnowledgeDirFor(ws), p.join(ws, 'knowledge', 'generic'));
    });

    test('projectsKnowledgeDirFor', () {
      expect(projectsKnowledgeDirFor(ws), p.join(ws, 'knowledge', 'projects'));
    });

    test('claudeCommandsDirFor', () {
      expect(claudeCommandsDirFor(ws), p.join(ws, '.claude', 'commands'));
    });

    test('tokenMapPathFor', () {
      expect(tokenMapPathFor(ws), p.join(ws, 'token_map.json'));
    });

    test('logsDirFor', () {
      expect(logsDirFor(ws), p.join(ws, 'logs'));
    });

    test('experimentsDirFor', () {
      expect(experimentsDirFor(ws), p.join(ws, 'experiments'));
    });
  });
}
