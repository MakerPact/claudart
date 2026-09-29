import 'dart:io';
import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import '../md_io.dart';
import '../paths.dart';
import '../knowledge_templates.dart';
import '../templates/handoff_template.dart';
import '../templates/suggest_template.dart';
import '../templates/debug_template.dart';
import '../templates/save_template.dart';
import '../templates/teardown_template.dart';
import '../ui/render.dart' as render;

Future<void> runInit(List<String> args) async {
  final parser = ArgParser()
    ..addOption('project', abbr: 'p', help: 'Add a project knowledge file to the workspace');

  final parsed = parser.parse(args);
  final projectName = parsed['project'] as String?;

  if (projectName != null) {
    await _initProject(projectName);
  } else {
    await _initWorkspace();
  }
}

Future<void> _initWorkspace() async {
  print(render.header('CLAUDART WORKSPACE INIT'));

  print('\nWorkspace: ${workspacesRoot}');


  // Check if already initialized
  if (Directory(genericKnowledgeDirFor(workspacesRoot)).existsSync()) {
    print('\n⚠  Workspace already initialized.');
    if (!confirm('Re-initialize and overwrite starter files?')) {
      print('\nAborted. Run `claudart init --project <name>` to add a project.\n');
      exit(0);
    }
  }

  // Detect Dart version for version-tagged starters
  final dartVersion = await _detectVersion('dart', ['--version']) ?? '3.x';

  // Create directory structure
  for (final dir in [
    genericKnowledgeDirFor(workspacesRoot),
    projectsKnowledgeDirFor(workspacesRoot),
    archiveDirFor(workspacesRoot),
    claudeCommandsDirFor(workspacesRoot),
  ]) {
    Directory(dir).createSync(recursive: true);
  }

  // Write generic knowledge starters
  _writeIfAbsent(p.join(genericKnowledgeDirFor(workspacesRoot), 'dart.md'), dartTemplate(dartVersion));
  _writeIfAbsent(p.join(genericKnowledgeDirFor(workspacesRoot), 'testing.md'), testingTemplate);

  // Write Claude Code slash commands into workspace.
  // 'workspace' is the project label for global default commands — re-running
  // `claudart link` in a real project overrides these with the project name.
  const globalLabel = 'workspace';
  writeFile(p.join(claudeCommandsDirFor(workspacesRoot), 'suggest-$globalLabel.md'), suggestCommandTemplate(workspacesRoot, globalLabel));
  writeFile(p.join(claudeCommandsDirFor(workspacesRoot), 'debug-$globalLabel.md'), debugCommandTemplate(workspacesRoot, globalLabel));
  writeFile(p.join(claudeCommandsDirFor(workspacesRoot), 'save-$globalLabel.md'), saveCommandTemplate(workspacesRoot, globalLabel));
  writeFile(p.join(claudeCommandsDirFor(workspacesRoot), 'teardown-$globalLabel.md'), teardownCommandTemplate(workspacesRoot, globalLabel));

  // Write blank handoff and skills if not present
  _writeIfAbsent(handoffPathFor(workspacesRoot), blankHandoff);
  _writeIfAbsent(skillsPathFor(workspacesRoot), _blankSkills);

  print('\n✓ Generic knowledge files written to ${genericKnowledgeDirFor(workspacesRoot)}');
  print('✓ Slash commands written to ${claudeCommandsDirFor(workspacesRoot)}');
  print('\nNext: register your project with:');
  print('  claudart init --project <your-project-name>\n');
}

Future<void> _initProject(String name) async {
  print(render.header('CLAUDART PROJECT INIT: $name'));

  if (!Directory(genericKnowledgeDirFor(workspacesRoot)).existsSync()) {
    print('\n✗ Workspace not initialized. Run `claudart init` first.\n');
    exit(1);
  }

  final projectFile = p.join(projectsKnowledgeDirFor(workspacesRoot), '$name.md');

  if (File(projectFile).existsSync()) {
    print('\n⚠  Project knowledge file already exists: $projectFile');
    if (!confirm('Overwrite with a fresh template?')) {
      print('\nKept existing file.\n');
      exit(0);
    }
  }

  writeFile(projectFile, projectTemplate(name));

  print('\n✓ Project knowledge file created: $projectFile');
  print('\nNext: from your project root, run:');
  print('  claudart link $name\n');
}

void _writeIfAbsent(String path, String content) {
  if (!File(path).existsSync()) {
    writeFile(path, content);
  }
}

Future<String?> _detectVersion(String cmd, List<String> args) async {
  try {
    final result = await Process.run(cmd, args);
    final out = (result.stdout as String) + (result.stderr as String);
    final match = RegExp(r'(\d+\.\d+\.\d+)').firstMatch(out);
    return match?.group(1);
  } on ProcessException catch (_) {
    return null;
  }
}

const String _blankSkills = '''# Accumulated Skills
> Updated by claudart teardown after each resolved session.

---

## Hot Paths

_No sessions recorded yet._

---

## Root Cause Patterns

_No patterns recorded yet._

---

## Anti-patterns

_None recorded yet._

---

## Branch Notes

_None recorded yet._

---

## Session Index

_No sessions recorded yet._
''';
