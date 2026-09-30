import 'dart:io';
import 'package:path/path.dart' as p;

// ── Filename constants ─────────────────────────────────────────────────────
// Single source of truth for all file/dir names used across claudart + consumers.

const String handoffFileName          = 'handoff.md';
const String skillsFileName           = 'skills.md';
const String archivesDirName          = 'archive';
const String archiveIndexFileName     = 'index.json';
const String flowCheckpointFileName   = 'flow_checkpoint.json';
const String pendingConfirmationFileName = 'pending_confirmation.json';

/// Extracts the workspace directory from `claudart status` output.
/// Parses the `Handoff  : <path>/handoff.md` line and returns the parent dir.
/// Returns null if the expected pattern is not found.
String? parseWorkspaceDirFromStatusOutput(String output) {
  for (final line in output.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.startsWith('Handoff') && trimmed.contains(':')) {
      final path = trimmed.split(':').sublist(1).join(':').trim();
      if (path.endsWith(handoffFileName)) return p.dirname(path);
    }
  }
  return null;
}

/// Root directory containing all project workspaces.
/// Resolved from CLAUDART_WORKSPACE env var, falls back to ~/.claudart/
/// (HOME on POSIX, USERPROFILE on Windows).
final String workspacesRoot = () {
  final env = Platform.environment['CLAUDART_WORKSPACE'];
  if (env != null && env.isNotEmpty) {
    if (env.startsWith('~/')) {
      return p.join(homeDir(), env.substring(2));
    }
    return env;
  }
  return p.join(homeDir(), '.claudart');
}();

/// The user's home directory: HOME when set (POSIX), USERPROFILE on Windows.
String homeDir() {
  final home = Platform.environment['HOME'];
  if (home != null && home.isNotEmpty) return home;
  final profile = Platform.environment['USERPROFILE'];
  if (profile != null && profile.isNotEmpty) return profile;
  return '.';
}

/// Registry of all known project workspaces.
String get registryPath => p.join(workspacesRoot, 'registry.json');

/// Returns the workspace directory for a named project.
String workspaceFor(String projectName) => p.join(workspacesRoot, projectName);

// ── Per-workspace path functions (new API) ─────────────────────────────────
// All take a resolved workspace path. Use with workspaceFor(name).

String handoffPathFor(String ws) => p.join(ws, 'handoff.md');
String skillsPathFor(String ws) => p.join(ws, 'skills.md');
String pendingConfirmationPathFor(String ws) =>
    p.join(ws, pendingConfirmationFileName);
String archiveDirFor(String ws) => p.join(ws, 'archive');
String configPathFor(String ws) => p.join(ws, 'config.json');
String knowledgeDirFor(String ws) => p.join(ws, 'knowledge');
String genericKnowledgeDirFor(String ws) => p.join(ws, 'knowledge', 'generic');
String projectsKnowledgeDirFor(String ws) => p.join(ws, 'knowledge', 'projects');
String claudeCommandsDirFor(String ws) => p.join(ws, '.claude', 'commands');
String tokenMapPathFor(String ws) => p.join(ws, 'token_map.json');
String logsDirFor(String ws) => p.join(ws, 'logs');
String experimentsDirFor(String ws) => p.join(ws, 'experiments');

// ── Per-project-root path functions ─────────────────────────────────────────
// CLAUDE.md lives at the project root, not the workspace — it is a real,
// hand-maintained file since v2 retired the CLAUDE.md symlink (see
// unlink.dart, which correctly refuses to delete a non-symlink CLAUDE.md).

/// [projectRoot]/CLAUDE.md — not to be confused with the deprecated,
/// legacy-global-workspace `claudeMdPath` getter below.
String claudeMdPathFor(String projectRoot) => p.join(projectRoot, 'CLAUDE.md');
