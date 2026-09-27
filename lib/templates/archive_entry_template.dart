// archive_entry_template.dart — GitHub archive/ delta-record entry generator
//
// Pure function, no I/O — same style as changelog_template.dart. One
// frontmatter-tagged entry per PLAN.md's "GitHub archive convention"
// spec: content removed from a main document, exactly as it was, never
// paraphrased.

/// Renders one `archive/` entry: frontmatter declaring where [content]
/// came from and what replaced it, followed by the exact removed content.
String archiveEntryTemplate({
  required DateTime archived,
  required String source,
  required String supersededBy,
  required String content,
}) {
  final isoDate = archived.toIso8601String().split('T').first;

  return '''---
archived: $isoDate
source: $source
superseded_by: $supersededBy
---

$content''';
}
