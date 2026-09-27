// changelog_template.dart — CHANGELOG.md entry generator
//
// Pure function, no I/O — same style as handoff_template.dart. One
// version-tagged entry block per PLAN.md's spec: "version-tagged, links
// back to issue."

/// Renders one CHANGELOG.md entry: a version heading, an ISO date, and a
/// bullet per change. Appends `(#N)` to the heading when [issueNumber] is
/// set — omitted entirely otherwise.
String changelogEntry({
  required String version,
  required DateTime date,
  required List<String> changes,
  int? issueNumber,
}) {
  final isoDate = date.toIso8601String().split('T').first;
  final issueSuffix = issueNumber != null ? ' (#$issueNumber)' : '';
  final body = changes.map((c) => '- $c').join('\n');

  return '''## $version — $isoDate$issueSuffix

$body
''';
}
