// readme_template.dart — README.md's machine-owned Roadmap block
//
// Pure function, no I/O — same style as claude_template.dart. Output is
// spliced into an existing README.md by link.dart (everything above the
// `<!-- claudart:link:roadmap -->` marker, including the `## Roadmap`
// heading and its TOC anchor, is preserved untouched); never written as a
// whole file on its own.
//
// Row data is caller-assembled (link.dart reads a project-root `roadmap.json`
// via parseRoadmapConfig), not parsed from PLAN.md — PLAN.md's phase headers
// aren't uniformly structured for automated extraction. `roadmap.json` is
// git-committed (unlike workspace.json, which lives outside the repo
// entirely and can't be a source a fresh clone or CI could ever verify
// against). This template only renders whatever it's given; filtering
// deferred/parked content out of what should even be rendered is the
// caller's responsibility, same discipline plan_template.dart already uses
// for PLAN.md stub sections.

import 'dart:convert';

/// One row of the Roadmap table. `status` carries the full display string
/// (e.g. `shipped`, `deferred, see PLAN.md`) — this template does not
/// interpret it.
typedef RoadmapRow = ({String phase, String scope, String status});

/// A project's full `roadmap.json` content. `summaryText`/`footerLine` are
/// optional because most projects (e.g. claudart's own) are fine with the
/// generic defaults — only a project with existing custom copy (e.g.
/// dartrix's "Six phases — current ship is schema v3 + visual polish"
/// summary and its "Deep dive" link line) needs to set them, to avoid the
/// splice silently overwriting content that has no other source.
typedef RoadmapConfig = ({
  String? summaryText,
  String? footerLine,
  List<RoadmapRow> rows,
});

/// Parses a project's `roadmap.json` — a JSON object with a required `rows`
/// array of `{"phase", "scope", "status"}` objects, plus optional
/// `summaryText`/`footerLine` strings — into a [RoadmapConfig]. Returns null
/// on missing/malformed content — same "absent means not opted in" contract
/// as `WorkspaceConfig.load`, not an exception, since a project without
/// `roadmap.json` is the common case, not an error.
RoadmapConfig? parseRoadmapConfig(String raw) {
  if (raw.isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return null;
    final rawRows = decoded['rows'];
    if (rawRows is! List) return null;
    return (
      summaryText: decoded['summaryText'] as String?,
      footerLine: decoded['footerLine'] as String?,
      rows: rawRows.map((r) {
        final row = r as Map<String, dynamic>;
        return (
          phase: row['phase'] as String,
          scope: row['scope'] as String,
          status: row['status'] as String,
        );
      }).toList(),
    );
  } on FormatException {
    return null;
  }
}

String readmeTemplate({
  required List<RoadmapRow> roadmapRows,
  String summaryText = "What's coming",
  String? footerLine,
}) {
  final rows = roadmapRows
      .map((r) => '| ${r.phase} | ${r.scope} | ${r.status} |')
      .join('\n');
  final footer = footerLine != null ? '\n$footerLine\n' : '';

  return '''<!-- claudart:link:roadmap -->
<details>
<summary><strong>$summaryText</strong></summary>

| Phase | Scope | Status |
|---|---|---|
$rows
$footer
</details>
''';
}
