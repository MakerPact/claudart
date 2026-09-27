import 'package:test/test.dart';
import 'package:claudart/templates/archive_entry_template.dart';

void main() {
  group('archiveEntryTemplate', () {
    test('includes ISO date on the archived key', () {
      final result = archiveEntryTemplate(
        archived: DateTime(2026, 9, 26),
        source: 'PLAN.md § What\'s next',
        supersededBy: 'shipped',
        content: 'Old planned content.',
      );
      expect(result, contains('archived: 2026-09-26'));
    });

    test('includes source and superseded_by keys', () {
      final result = archiveEntryTemplate(
        archived: DateTime(2026, 9, 26),
        source: 'PLAN.md § What\'s next',
        supersededBy: 'shipped',
        content: 'Old planned content.',
      );
      expect(result, contains('source: PLAN.md § What\'s next'));
      expect(result, contains('superseded_by: shipped'));
    });

    test('frontmatter keys appear in order: archived, source, superseded_by', () {
      final result = archiveEntryTemplate(
        archived: DateTime(2026, 9, 26),
        source: 'README.md § Roadmap',
        supersededBy: 'Phase 9',
        content: 'Removed roadmap text.',
      );
      final archivedIndex = result.indexOf('archived:');
      final sourceIndex = result.indexOf('source:');
      final supersededIndex = result.indexOf('superseded_by:');
      expect(archivedIndex, lessThan(sourceIndex));
      expect(sourceIndex, lessThan(supersededIndex));
    });

    test('wraps content exactly, nothing added or paraphrased', () {
      const content = 'Exact removed content.\nWith a second line.';
      final result = archiveEntryTemplate(
        archived: DateTime(2026, 9, 26),
        source: 'PLAN.md § Old decision',
        supersededBy: 'new decision',
        content: content,
      );
      expect(result, endsWith(content));
    });
  });
}
