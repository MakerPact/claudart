import 'package:claudart/paths.dart';
import "dart:io";
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('parseWorkspaceDirFromStatusOutput', () {
    test('extracts workspace dir when Handoff line is present', () {
      final output = '''
Some other line
Handoff  : /home/user/my_workspace/handoff.md
Another line
''';
      expect(parseWorkspaceDirFromStatusOutput(output), '/home/user/my_workspace');
    });

    test('returns null when Handoff line is missing', () {
      final output = '''
Some other line
Another line
''';
      expect(parseWorkspaceDirFromStatusOutput(output), isNull);
    });

    test('returns null when Handoff line does not end with handoffFileName', () {
      final output = '''
Handoff  : /home/user/my_workspace/other.md
''';
      expect(parseWorkspaceDirFromStatusOutput(output), isNull);
    });

    test('handles colons in the path', () {
      final output = '''
Handoff  : /home/user/my:workspace/handoff.md
''';
      expect(parseWorkspaceDirFromStatusOutput(output), '/home/user/my:workspace');
    });
  });

  group('Filename constants', () {
    test('have expected values', () {
      expect(handoffFileName, 'handoff.md');
      expect(skillsFileName, 'skills.md');
      expect(archivesDirName, 'archive');
      expect(archiveIndexFileName, 'index.json');
      expect(flowCheckpointFileName, 'flow_checkpoint.json');
    });
  });

  group('Workspace helper functions', () {
    test('registryPath uses workspacesRoot', () {
      expect(registryPath, p.join(workspacesRoot, 'registry.json'));
    });

    test('workspaceFor returns path inside workspacesRoot', () {
      expect(workspaceFor('my_project'), p.join(workspacesRoot, 'my_project'));
    });
  });

  group('Per-workspace path functions', () {
    const ws = '/mock/workspace';

    test('handoffPathFor', () => expect(handoffPathFor(ws), p.join(ws, 'handoff.md')));
    test('skillsPathFor', () => expect(skillsPathFor(ws), p.join(ws, 'skills.md')));
    test('archiveDirFor', () => expect(archiveDirFor(ws), p.join(ws, 'archive')));
    test('configPathFor', () => expect(configPathFor(ws), p.join(ws, 'config.json')));
    test('knowledgeDirFor', () => expect(knowledgeDirFor(ws), p.join(ws, 'knowledge')));
    test('genericKnowledgeDirFor', () => expect(genericKnowledgeDirFor(ws), p.join(ws, 'knowledge', 'generic')));
    test('projectsKnowledgeDirFor', () => expect(projectsKnowledgeDirFor(ws), p.join(ws, 'knowledge', 'projects')));
    test('claudeCommandsDirFor', () => expect(claudeCommandsDirFor(ws), p.join(ws, '.claude', 'commands')));
    test('tokenMapPathFor', () => expect(tokenMapPathFor(ws), p.join(ws, 'token_map.json')));
    test('logsDirFor', () => expect(logsDirFor(ws), p.join(ws, 'logs')));
    test('experimentsDirFor', () => expect(experimentsDirFor(ws), p.join(ws, 'experiments')));
  });

  group('Legacy single-workspace paths', () {
    test('claudeDir uses workspacesRoot', () => expect(claudeDir, workspacesRoot));
    test('handoffPath', () => expect(handoffPath, handoffPathFor(workspacesRoot)));
    test('skillsPath', () => expect(skillsPath, skillsPathFor(workspacesRoot)));
    test('archiveDir', () => expect(archiveDir, archiveDirFor(workspacesRoot)));
    test('knowledgeDir', () => expect(knowledgeDir, knowledgeDirFor(workspacesRoot)));
    test('genericKnowledgeDir', () => expect(genericKnowledgeDir, genericKnowledgeDirFor(workspacesRoot)));
    test('projectsKnowledgeDir', () => expect(projectsKnowledgeDir, projectsKnowledgeDirFor(workspacesRoot)));
    test('claudeCommandsDir', () => expect(claudeCommandsDir, claudeCommandsDirFor(workspacesRoot)));
    test('claudeMdPath', () => expect(claudeMdPath, p.join(workspacesRoot, 'CLAUDE.md')));
  });

  group('workspacesRoot resolution', () {
    test('resolves from absolute CLAUDART_WORKSPACE', () async {
      final result = await _runWithEnv({'CLAUDART_WORKSPACE': '/absolute/custom/path'});
      expect(result, '/absolute/custom/path');
    });

    test('resolves from ~ CLAUDART_WORKSPACE', () async {
      final home = p.join('/home', 'testuser');
      final result = await _runWithEnv({
        'CLAUDART_WORKSPACE': '~/custom/path',
        'HOME': home,
      });
      expect(result, p.join(home, 'custom', 'path'));
    });

    test('defaults to ~/.claudart when CLAUDART_WORKSPACE is unset', () async {
      final home = p.join('/home', 'testuser');
      final result = await _runWithEnv({
        'HOME': home,
      }, removeWorkspace: true);
      expect(result, p.join(home, '.claudart'));
    });

    test('defaults to ~/.claudart when CLAUDART_WORKSPACE is empty', () async {
      final home = p.join('/home', 'testuser');
      final result = await _runWithEnv({
        'CLAUDART_WORKSPACE': '',
        'HOME': home,
      });
      expect(result, p.join(home, '.claudart'));
    });
  });
}

Future<String> _runWithEnv(Map<String, String> env, {bool removeWorkspace = false}) async {
  // Since workspacesRoot is a top-level final variable, it's evaluated once when the isolate starts.
  // We need to spawn a new process to test different environment variables reliably.
  final scriptPath = p.join(Directory.current.path, 'test', 'claudart_paths_test_script.dart');

  // Clean up any existing file
  final file = File(scriptPath);
  if (file.existsSync()) {
    file.deleteSync();
  }

  file.writeAsStringSync('''
import 'package:claudart/paths.dart';
void main() {
  print(workspacesRoot);
}
''');

  final currentEnv = Map<String, String>.from(Platform.environment);
  if (removeWorkspace) {
    currentEnv.remove('CLAUDART_WORKSPACE');
  }

  final process = await Process.run(
    Platform.executable,
    [scriptPath],
    environment: {...currentEnv, ...env},
  );

  if (file.existsSync()) {
    file.deleteSync();
  }

  if (process.exitCode != 0) {
    throw Exception('Script failed: ${process.stderr}');
  }

  return process.stdout.toString().trim();
}
