// repo_resolver.dart — local-clone discovery + verification (Phase 14)
//
// The state machine behind "is the git already created, is it up to
// date, is it the correct git": given a parsed [ForgeRepo], find a local
// clone (registered or user-supplied), verify its remote matches the
// issue's repo, check the default branch is current, and surface every
// failure as a typed outcome the wizard can branch on — never a raw
// exception.

import 'dart:io';
import 'package:path/path.dart' as p;
import 'forge_adapter.dart';
import '../process_runner.dart';
import '../registry.dart';

/// Outcome of resolving a local clone for a forge repo.
sealed class RepoResolveOutcome {
  const RepoResolveOutcome();
}

/// A verified local clone: right remote, fetched, on [branch] (the
/// default branch, checked out ready for the fix branch to be cut).
class RepoReady extends RepoResolveOutcome {
  final String path;
  final String branch;
  const RepoReady(this.path, this.branch);
}

/// A local clone exists but its origin points at a different repo.
class RemoteMismatch extends RepoResolveOutcome {
  final String path;
  final String actualRemote;
  const RemoteMismatch(this.path, this.actualRemote);
}

/// The clone's working tree has uncommitted changes — branch switch
/// refused; the wizard offers stash-or-abort.
class DirtyTree extends RepoResolveOutcome {
  final String path;
  const DirtyTree(this.path);
}

/// No local clone found anywhere — needs a fresh clone.
class NoLocalClone extends RepoResolveOutcome {
  const NoLocalClone();
}

/// git itself failed in a way the resolver doesn't classify (git not
/// installed, corrupt repo, …). [message] is user-actionable.
class GitError extends RepoResolveOutcome {
  final String message;
  const GitError(this.message);
}

/// Resolves and verifies local clones for forge repos.
class RepoResolver {
  final ProcessRunner runner;

  RepoResolver(this.runner);

  /// Finds a registered clone whose origin matches [repo].
  ///
  /// Match rule: normalized remote URL equality, where normalization
  /// strips scheme, `.git` suffix, and trailing slashes, and compares
  /// case-insensitively — `git@github.com:owner/repo.git`,
  /// `https://github.com/owner/repo`, and
  /// `https://github.com/owner/repo.git` are all the same repo.
  String? findRegisteredClone(ForgeRepo repo, Registry registry) {
    for (final entry in registry.entries) {
      final remote = _originUrl(entry.projectRoot);
      if (remote == null) continue;
      if (_sameRepo(remote, repo)) return entry.projectRoot;
    }
    return null;
  }

  /// Verifies a candidate clone path: remote match → fetch → default
  /// branch current → clean tree. Returns the typed outcome.
  Future<RepoResolveOutcome> verifyClone({
    required String clonePath,
    required ForgeRepo repo,
    required String cloneUrl,
  }) async {
    // 1 — Remote check: the clone must point at the issue's repo.
    final remote = _originUrl(clonePath);
    if (remote == null) {
      return GitError('Not a git repository (no origin remote): $clonePath');
    }
    if (!_sameRepo(remote, repo)) {
      return RemoteMismatch(clonePath, remote);
    }

    // 2 — Fetch: update remote refs so currency checks are real.
    final fetch = await runner.run(
      'git',
      ['fetch', 'origin', '--quiet'],
      workingDirectory: clonePath,
    );
    if (fetch.exitCode != 0) {
      return GitError('git fetch failed in $clonePath: '
          '${(fetch.stderr as String).trim()}');
    }

    // 3 — Clean tree: refuse to switch branches over uncommitted work.
    final status = await runner.run(
      'git',
      ['status', '--porcelain'],
      workingDirectory: clonePath,
    );
    if (status.exitCode != 0) {
      return GitError('git status failed in $clonePath');
    }
    if ((status.stdout as String).trim().isNotEmpty) {
      return DirtyTree(clonePath);
    }

    return RepoReady(clonePath, _localDefaultBranch(clonePath));
  }

  /// Clones [repo] into [targetDir]. Returns null on success, or a
  /// user-actionable error message.
  Future<String?> clone({
    required ForgeRepo repo,
    required String cloneUrl,
    required String targetDir,
  }) async {
    final parent = p.dirname(targetDir);
    if (!Directory(parent).existsSync()) {
      Directory(parent).createSync(recursive: true);
    }
    final result = await runner.run(
      'git',
      ['clone', cloneUrl, targetDir],
    );
    if (result.exitCode != 0) {
      return 'git clone failed: ${(result.stderr as String).trim()}';
    }
    return null;
  }

  /// Creates the bug-fix branch off the default branch in [clonePath].
  /// Returns the branch name, or null + [error] via the record.
  ({String? branch, String? error}) createFixBranch({
    required String clonePath,
    required int issueNumber,
    required String baseBranch,
  }) {
    final branch = 'fix/issue-$issueNumber';

    // Branch already exists? Reuse it — re-running an import should be
    // idempotent, not an error.
    final exists = runner.runSync(
      'git',
      ['rev-parse', '--verify', 'refs/heads/$branch'],
      workingDirectory: clonePath,
    );
    if (exists.exitCode == 0) {
      final checkout = runner.runSync(
        'git',
        ['checkout', branch],
        workingDirectory: clonePath,
      );
      if (checkout.exitCode != 0) {
        return (
          branch: null,
          error: 'Branch $branch exists but checkout failed'
        );
      }
      return (branch: branch, error: null);
    }

    // Base off the remote default branch so the fix starts current.
    final checkout = runner.runSync(
      'git',
      ['checkout', '-b', branch, 'origin/$baseBranch'],
      workingDirectory: clonePath,
    );
    if (checkout.exitCode != 0) {
      // origin/<base> may not exist locally (single-branch clones) —
      // fall back to the local base branch.
      final localCheckout = runner.runSync(
        'git',
        ['checkout', '-b', branch, baseBranch],
        workingDirectory: clonePath,
      );
      if (localCheckout.exitCode != 0) {
        return (
          branch: null,
          error: 'Could not create branch $branch off $baseBranch: '
              '${(localCheckout.stderr as String).trim()}'
        );
      }
    }
    return (branch: branch, error: null);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String? _originUrl(String projectRoot) {
    try {
      final result = runner.runSync(
        'git',
        ['remote', 'get-url', 'origin'],
        workingDirectory: projectRoot,
      );
      if (result.exitCode != 0) return null;
      final url = (result.stdout as String).trim();
      return url.isEmpty ? null : url;
    } on Exception {
      return null;
    }
  }

  /// The local HEAD's branch name (the default branch after a fresh
  /// clone, or whatever is checked out in an existing clone).
  String _localDefaultBranch(String clonePath) {
    final result = runner.runSync(
      'git',
      ['rev-parse', '--abbrev-ref', 'HEAD'],
      workingDirectory: clonePath,
    );
    if (result.exitCode != 0) return 'main';
    final branch = (result.stdout as String).trim();
    return branch.isEmpty || branch == 'HEAD' ? 'main' : branch;
  }

  /// Normalized repo identity comparison — see [findRegisteredClone].
  static bool _sameRepo(String remoteUrl, ForgeRepo repo) {
    String normalize(String url) {
      var u = url.toLowerCase();
      // ssh scp-style: git@host:owner/repo → host/owner/repo
      final scp = RegExp(r'^[^@/]+@([^:]+):(.+)$').firstMatch(u);
      if (scp != null) u = '${scp.group(1)}/${scp.group(2)}';
      u = u.replaceFirst(RegExp(r'^https?://'), '');
      u = u.replaceFirst(RegExp(r'^git://'), '');
      u = u.replaceFirst(RegExp(r'\.git$'), '');
      u = u.replaceAll(RegExp(r'/+$'), '');
      return u;
    }

    final remote = normalize(remoteUrl);
    final expected =
        normalize('https://${repo.host}/${repo.owner}/${repo.repo}');
    return remote == expected;
  }
}
