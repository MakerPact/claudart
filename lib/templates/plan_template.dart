// plan_template.dart — PLAN.md stub generator
//
// Pure function, no I/O — same style as handoff_template.dart. Composes
// pre-rendered output from diagram_template.dart / github_log_template.dart
// (the caller builds those, this function only slots them in) into the
// PLAN.md stub `claudart add` writes for a new workspace.

/// Renders a PLAN.md stub for [projectName]. Sections are gated by their
/// corresponding flag/param — a `false`/`null` means the section is
/// omitted entirely, not rendered empty.
String planStub({
  required String projectName,
  bool usesDartrix = false,
  bool githubTracking = false,
  String? mermaidArchitectureDiagram,
  String? githubLogSection,
}) {
  final sections = StringBuffer();

  if (mermaidArchitectureDiagram != null) {
    sections.writeln('## Architecture\n');
    sections.writeln(mermaidArchitectureDiagram);
    sections.writeln();
  }

  if (usesDartrix) {
    sections.writeln('## dartrix coverage gaps\n');
    sections.writeln(
      '> Enum variants that haven\'t been exercised in each feature appear '
      'here as named failures from `matrix.gaps()`.',
    );
    sections.writeln();
  }

  if (githubTracking) {
    sections.writeln('## GitHub issues\n');
    sections.writeln(githubLogSection ?? '_No issues tracked yet._');
    sections.writeln();
  }

  return '''# $projectName — plan

This file is the never-lose-context document for $projectName.

---

## Vision

_Not yet determined._

---

$sections## What's been built

_Nothing yet._

---

## What's next

_Not yet determined._
''';
}
