// github_log_template.dart — GitHub issues log section for PLAN.md/README.md
//
// Pure function, no I/O — same style as handoff_template.dart. Generates
// PLAN.md's "GitHub issues" section (per PLAN.md's "GitHub tracking
// section" spec): one row per tracked issue, open or closed.

/// One tracked GitHub issue entry: its number, title, and open/closed state.
typedef GithubLogEntry = ({int number, String title, bool open});

/// Renders the "GitHub issues" section body — one line per [entries] item,
/// e.g. `'- #12 Template system phase 2 (open)'`.
String githubLogSection({required List<GithubLogEntry> entries}) {
  if (entries.isEmpty) return '_No issues tracked yet._';
  return entries
      .map((e) => '- #${e.number} ${e.title} (${e.open ? 'open' : 'closed'})')
      .join('\n');
}
