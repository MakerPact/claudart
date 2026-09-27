import 'package:test/test.dart';
import 'package:claudart/templates/changelog_template.dart';

void main() {
  group('changelogEntry', () {
    test('includes version and ISO date', () {
      final result = changelogEntry(
        version: '2.1.0',
        date: DateTime(2026, 9, 26),
        changes: ['Added template system'],
      );
      expect(result, contains('## 2.1.0 — 2026-09-26'));
    });

    test('includes every change as a bullet', () {
      final result = changelogEntry(
        version: '2.1.0',
        date: DateTime(2026, 9, 26),
        changes: ['First change', 'Second change'],
      );
      expect(result, contains('- First change'));
      expect(result, contains('- Second change'));
    });

    test('appends issue number when set', () {
      final result = changelogEntry(
        version: '2.1.0',
        date: DateTime(2026, 9, 26),
        changes: ['Added template system'],
        issueNumber: 12,
      );
      expect(result, contains('(#12)'));
    });

    test('omits issue suffix entirely when not set', () {
      final result = changelogEntry(
        version: '2.1.0',
        date: DateTime(2026, 9, 26),
        changes: ['Added template system'],
      );
      expect(result, isNot(contains('(#')));
    });
  });
}
