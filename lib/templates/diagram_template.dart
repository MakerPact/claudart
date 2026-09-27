// diagram_template.dart — Mermaid diagram string generators
//
// Pure functions, no I/O — same style as handoff_template.dart and
// knowledge_templates.dart. Callers build each pre-formatted line
// (a transition, an edge, a step) and pass the joined content in; these
// functions only wrap it in the right Mermaid block syntax. `title`
// renders as a `%%` Mermaid comment — a caption, not a directive.
//
// Diagram kind → Mermaid directive, per PLAN.md's "Diagram templates" table:
//   State machine    → stateDiagram-v2
//   Dependency graph  → graph LR
//   Data flow         → sequenceDiagram
//   Architecture      → graph TD

/// A state-machine diagram — one line per transition, e.g.
/// `'suggest_investigating --> ready_for_debug : /save'`.
String stateDiagramTemplate({
  required String title,
  required List<String> transitions,
}) {
  final body = transitions.map((t) => '    $t').join('\n');
  return '''```mermaid
%% $title
stateDiagram-v2
    direction LR
$body
```''';
}

/// A dependency graph — one line per edge, e.g. `'A --> B'`.
String dependencyGraphTemplate({
  required String title,
  required List<String> edges,
}) {
  final body = edges.map((e) => '    $e').join('\n');
  return '''```mermaid
%% $title
graph LR
$body
```''';
}

/// A data-flow / sequence diagram — one line per step, e.g.
/// `'User->>CLI: claudart add'`.
String dataFlowTemplate({
  required String title,
  required List<String> steps,
}) {
  final body = steps.map((s) => '    $s').join('\n');
  return '''```mermaid
%% $title
sequenceDiagram
$body
```''';
}

/// An architecture / workspace-layout graph — one line per edge, e.g.
/// `'A -->|generates| B'`.
String architectureGraphTemplate({
  required String title,
  required List<String> edges,
}) {
  final body = edges.map((e) => '    $e').join('\n');
  return '''```mermaid
%% $title
graph TD
$body
```''';
}
