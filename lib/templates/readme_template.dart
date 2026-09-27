// readme_template.dart — README.md's machine-owned Roadmap block
//
// Pure function, no I/O — same style as claude_template.dart. Output is
// spliced into an existing README.md by link.dart (everything above the
// `<!-- claudart:link:roadmap -->` marker, including the `## Roadmap`
// heading and its TOC anchor, is preserved untouched); never written as a
// whole file on its own.
//
// Row data is caller-assembled (link.dart holds the List<RoadmapRow>
// literal), not parsed from PLAN.md — PLAN.md's phase headers aren't
// uniformly structured for automated extraction. This template only
// renders whatever rows it's given; filtering deferred/parked content out
// of what should even be rendered is the caller's responsibility, same
// discipline plan_template.dart already uses for PLAN.md stub sections.

/// One row of the Roadmap table. `status` carries the full display string
/// (e.g. `shipped`, `deferred, see PLAN.md`) — this template does not
/// interpret it.
typedef RoadmapRow = ({String phase, String scope, String status});

String readmeTemplate({
  required List<RoadmapRow> roadmapRows,
}) {
  final rows = roadmapRows
      .map((r) => '| ${r.phase} | ${r.scope} | ${r.status} |')
      .join('\n');

  return '''<!-- claudart:link:roadmap -->
<details>
<summary><strong>What's coming</strong></summary>

| Phase | Scope | Status |
|---|---|---|
$rows

</details>
''';
}
