// issue.dart — `claudart issue <url>` wizard (PLAN.md Phase 14)
//
// Paste a forge issue URL; claudart parses it, fetches the issue,
// ensures the right repo is cloned and current, cuts a bug-fix branch,
// and writes the handoff with the issue as the Bug section — exactly as
// if the user had typed the issue text into `claudart setup`. Fully
// interactive: every mutating step (clone, branch, handoff write) is
// confirmed before it runs. The user is never removed from the loop;
// the manual heavy lifting (clone, branch, copy issue text) is.

import 'dart:io';
import '../file_io.dart';
import '../forge/forge_adapter.dart';
import '../forge/forge_registry.dart';
import '../forge/repo_resolver.dart';
import '../md_io.dart' show confirm;
import '../paths.dart';
import '../process_runner.dart';
import '../registry.dart';
import '../templates/handoff_template.dart';
import '../ui/ansi.dart' as ansi;
import '../ui/render.dart' as render;

Future<void> runIssue(
  List<String> args, {
  FileIO? io,
  ForgeRegistry? forgeRegistry,
  ProcessRunner? processRunner,
  bool Function(String question)? confirmFn,
  String? Function(String question, {bool optional})? promptFn,
  Never Function(int code)? exitFn,
}) async {
  final fileIO = io ?? const RealFileIO();
  final forges = forgeRegistry ?? ForgeRegistry.builtin();
  final runner = processRunner ?? const RealProcessRunner();
  final confirm_ = confirmFn ?? confirm;
  final prompt_ = promptFn ?? _defaultPrompt;
  final exit_ = exitFn ?? exit;

  print(render.header('CLAUDART ISSUE'));

  // ── 1 — Parse the URL ────────────────────────────────────────────────────

  if (args.isEmpty) {
    print(
      '\n✗ Usage: claudart issue <url>\n'
      '  e.g. claudart issue https://github.com/arduino/Arduino/issues/12036\n',
    );
    exit_(1);
  }
  final url = args.first;
  final uri = Uri.tryParse(url);
  if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
    print('\n✗ Not a valid http(s) URL: $url\n');
    exit_(1);
  }
  final adapter = forges.forHost(uri.host);
  if (adapter == null) {
    print('\n✗ No forge adapter handles ${uri.host}.\n');
    exit_(1);
  }
  final repo = adapter.parseIssueUrl(uri);
  if (repo == null) {
    print(
      '\n✗ That does not look like an issue URL for ${adapter.name}:\n'
      '  $url\n',
    );
    exit_(1);
  }
  print('  Forge   : ${adapter.name} (${repo.host})');
  print('  Repo    : ${repo.slug}');
  print('  Issue   : #${repo.number}');

  // ── 2 — Fetch the issue ───────────────────────────────────────────────────

  print('\n  [1] Fetching issue…');
  final fetched = await adapter.fetchIssue(repo);
  if (!fetched.ok) {
    print('\n✗ ${fetched.error}\n');
    exit_(1);
  }
  final issue = fetched.issue!;
  print('  Title   : ${_truncate(issue.title, 70)}');
  print('  State   : ${issue.state}'
      '${issue.labels.isNotEmpty ? '  Labels: ${issue.labels.join(', ')}' : ''}');

  // ── 3 — Resolve the local clone ──────────────────────────────────────────

  print('\n  [2] Resolving local repo…');
  final registry = Registry.load(io: fileIO);
  final resolver = RepoResolver(runner);

  String clonePath;
  final registered = resolver.findRegisteredClone(repo, registry);
  if (registered != null) {
    print('  Found registered clone: $registered');
    if (!confirm_('Use this clone?')) {
      clonePath = _promptClonePath(prompt_);
    } else {
      clonePath = registered;
    }
  } else {
    clonePath = _promptClonePath(prompt_);
  }

  // ── 4 — Verify or clone ───────────────────────────────────────────────────

  if (Directory(clonePath).existsSync()) {
    print('\n  [3] Verifying existing clone…');
    final outcome = await resolver.verifyClone(
      clonePath: clonePath,
      repo: repo,
      cloneUrl: adapter.cloneUrl(repo),
    );
    switch (outcome) {
      case RepoReady():
        print('  ✓ Clone verified — on ${outcome.branch}, clean tree.');
      case RemoteMismatch():
        print(
          '\n⚠  That directory is a clone of a different repo:\n'
          '     expected: ${repo.slug} on ${repo.host}\n'
          '     actual  : ${outcome.actualRemote}\n'
          '  Refusing to work in the wrong repo. Pick a different path.',
        );
        clonePath = _promptClonePath(prompt_);
        await _cloneFresh(resolver, repo, adapter, clonePath, exit_);
      case DirtyTree():
        print(
          '\n⚠  Working tree at ${outcome.path} has uncommitted changes.\n'
          '  Refusing to switch branches over them.',
        );
        if (confirm_('Stash them and continue?')) {
          final stash = await runner.run(
            'git',
            ['stash', 'push', '-u', '-m', 'claudart-issue-import'],
            workingDirectory: outcome.path,
          );
          if (stash.exitCode != 0) {
            print('\n✗ git stash failed. Aborting.\n');
            exit_(1);
          }
          print('  Stashed as claudart-issue-import.');
        } else {
          print('\nAborted — commit or stash your changes first.\n');
          exit_(1);
        }
      case GitError():
        print('\n✗ ${outcome.message}\n');
        exit_(1);
      case NoLocalClone():
        // unreachable via verifyClone — kept for switch exhaustiveness.
        break;
    }
  } else {
    print('\n  [3] No clone at $clonePath');
    await _cloneFresh(resolver, repo, adapter, clonePath, exit_);
  }

  // ── 5 — Create the fix branch ─────────────────────────────────────────────

  print('\n  [4] Creating fix branch…');
  final defaultBranch = await adapter.defaultBranch(repo) ?? 'main';
  final branchResult = resolver.createFixBranch(
    clonePath: clonePath,
    issueNumber: repo.number,
    baseBranch: defaultBranch,
  );
  if (branchResult.error != null) {
    print('\n✗ ${branchResult.error}\n');
    exit_(1);
  }
  final branch = branchResult.branch!;
  print('  ✓ Branch: $branch');

  // ── 6 — Write the handoff ─────────────────────────────────────────────────

  // The issue becomes the Bug section verbatim — downstream (suggest /
  // debug) never knows where the text came from.
  final bugText = _issueToBug(issue);
  final expectedText = _issueToExpected(issue);

  print('\n  [5] Handoff preview:');
  print('  ─────────────────────────────────────────');
  print('  Bug     : ${_truncate(bugText, 68)}');
  print('  Expected: ${_truncate(expectedText, 68)}');
  print('  ─────────────────────────────────────────');

  if (!confirm_('Write handoff for this issue?')) {
    print('\nAborted. No files were written.\n');
    exit_(0);
  }

  // The clone must be registered so suggest/debug find it by root.
  RegistryEntry? newEntry;
  if (registry.findByProjectRoot(clonePath) == null) {
    final name = '${repo.owner}_${repo.repo}';
    print('\n  Registering $clonePath as "$name" (claudart link equivalent).');
    newEntry = RegistryEntry(
      name: name,
      projectRoot: clonePath,
      workspacePath: workspaceFor(name),
      createdAt: _today(),
      lastSession: _today(),
    );
    final updated = registry.add(newEntry);
    updated.save(io: fileIO);
    fileIO.createDir(newEntry.workspacePath);
  }
  final workspace = registry.findByProjectRoot(clonePath)?.workspacePath ??
      newEntry!.workspacePath;

  final handoff = handoffTemplate(
    branch: branch,
    date: _today(),
    bug: bugText,
    expected: expectedText,
    projectName: '${repo.owner}/${repo.repo}',
    files: null,
    entryPoints: null,
    pendingIssues: ['${issue.title} (${issue.url})'],
  );
  fileIO.write(handoffPathFor(workspace), handoff);
  print('  ✓ Handoff written: ${handoffPathFor(workspace)}');

  print(
    '\n${ansi.c(ansi.green, '✓ Issue #${repo.number} imported.')}\n'
    '  Repo     : $clonePath\n'
    '  Branch   : $branch\n'
    '  Workspace: $workspace\n\n'
    '  Next: cd $clonePath\n'
    '        claudart suggest   (classify + enrich the handoff)\n'
    '        claudart debug     (apply the fix)\n',
  );
}

// ── Helpers ─────────────────────────────────────────────────────────────────

Future<void> _cloneFresh(
  RepoResolver resolver,
  ForgeRepo repo,
  ForgeAdapter adapter,
  String targetDir,
  Never Function(int code) exit_,
) async {
  final cloneUrl = adapter.cloneUrl(repo);
  print('  Cloning $cloneUrl → $targetDir…');
  final error = await resolver.clone(
    repo: repo,
    cloneUrl: cloneUrl,
    targetDir: targetDir,
  );
  if (error != null) {
    print('\n✗ $error\n');
    exit_(1);
  }
  print('  ✓ Cloned.');
}

String _promptClonePath(String? Function(String q, {bool optional}) prompt_) {
  final path = prompt_(
    'Directory to clone into (must not exist yet, or be the existing clone)',
  );
  if (path == null || path.trim().isEmpty) {
    print('\n✗ A clone path is required.\n');
    exit(1);
  }
  return path.trim();
}

/// The issue title + body + key comments, formatted as the Bug section.
String _issueToBug(ForgeIssue issue) {
  final buf = StringBuffer();
  buf.writeln('**${issue.title}** (${issue.url})');
  if (issue.body.trim().isNotEmpty) {
    buf.writeln();
    buf.writeln(issue.body.trim());
  }
  if (issue.comments.isNotEmpty) {
    buf.writeln();
    buf.writeln('--- Discussion comments (may contain hints) ---');
    for (final c in issue.comments.take(10)) {
      if (c.trim().isEmpty) continue;
      buf.writeln();
      buf.writeln('> ${c.trim().replaceAll('\n', '\n> ')}');
    }
  }
  return buf.toString().trimRight();
}

/// Best-effort Expected Behavior extraction: issues often state the
/// desired behavior after "expected", "should", or similar. When
/// nothing matches, the section says so — suggest's categorize step
/// reasons over the full Bug section anyway.
String _issueToExpected(ForgeIssue issue) {
  final text = '${issue.body}\n${issue.comments.join('\n')}';
  final patterns = [
    RegExp(r'expected behavior[:\s-]+(.+)', caseSensitive: false, dotAll: true),
    RegExp(r'expected[:\s-]+(.+)', caseSensitive: false, dotAll: true),
    RegExp(r'(?:it|this|that) should (.+)', caseSensitive: false, dotAll: true),
  ];
  for (final pattern in patterns) {
    final m = pattern.firstMatch(text);
    if (m != null) {
      final captured = m.group(1)!.trim();
      if (captured.isNotEmpty) {
        // Cap at the first blank line — the regexes are greedy across
        // the whole text otherwise.
        final firstPara = captured.split(RegExp(r'\n\s*\n')).first;
        return firstPara.trim();
      }
    }
  }
  return '_Not stated in the issue — infer from the bug description '
      '(${issue.url})._';
}

String _truncate(String s, int width) {
  final one = s.replaceAll('\n', ' ').trim();
  return one.length <= width ? one : '${one.substring(0, width - 3)}…';
}

String _today() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

String? _defaultPrompt(String question, {bool optional = false}) {
  stdout.write('$question${optional ? ' (optional)' : ''}: ');
  return stdin.readLineSync();
}
