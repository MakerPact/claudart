import 'package:test/test.dart';
import 'package:claudart/session/skills_lookup.dart';

const _skillsContent = '''
# Accumulated Skills

## Root Cause Patterns

- **symlink-management**: CLI registration crashes on an existing directory. → Fix: check before linking.
- **api-integration**: Sentinel strings reached persistence before null guards. → Fix: keep sentinels null until display.
- **state-management**: Duplicate entries accumulate without keyed indexing. → Fix: use a keyed map with upsert semantics.

## Dart Testing Patterns

- Matrix-driven tests, one per variant.
''';

void main() {
  group('relevantSkillPatterns', () {
    test('ranks the most similar pattern first', () {
      final result = relevantSkillPatterns(
        _skillsContent,
        'symlink creation crashes when the target is a real directory',
        k: 1,
      );
      expect(result, hasLength(1));
      expect(result.first, contains('symlink-management'));
    });

    test('returns up to k patterns', () {
      final result =
          relevantSkillPatterns(_skillsContent, 'state management bug', k: 2);
      expect(result.length, lessThanOrEqualTo(2));
    });

    test('empty query returns no patterns', () {
      expect(relevantSkillPatterns(_skillsContent, ''), isEmpty);
    });

    test('skills.md with no Root Cause Patterns section returns no patterns',
        () {
      expect(
          relevantSkillPatterns('# Accumulated Skills\n', 'anything'), isEmpty);
    });

    test('only pulls bullets from Root Cause Patterns, not other sections', () {
      final result =
          relevantSkillPatterns(_skillsContent, 'matrix-driven tests', k: 3);
      expect(result, everyElement(isNot(contains('Matrix-driven tests'))));
    });
  });
}
