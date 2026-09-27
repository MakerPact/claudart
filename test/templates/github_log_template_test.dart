import 'package:test/test.dart';
import 'package:claudart/templates/github_log_template.dart';

void main() {
  group('githubLogSection', () {
    test('renders empty-state text when no entries', () {
      expect(githubLogSection(entries: []), contains('No issues tracked'));
    });

    test('renders an open issue', () {
      final result = githubLogSection(entries: [
        (number: 12, title: 'Template system phase 2', open: true),
      ]);
      expect(result, contains('#12 Template system phase 2 (open)'));
    });

    test('renders a closed issue', () {
      final result = githubLogSection(entries: [
        (number: 7, title: 'Registry migration', open: false),
      ]);
      expect(result, contains('#7 Registry migration (closed)'));
    });

    test('renders multiple entries, one per line', () {
      final result = githubLogSection(entries: [
        (number: 1, title: 'First', open: true),
        (number: 2, title: 'Second', open: false),
      ]);
      expect(result.split('\n'), hasLength(2));
      expect(result, contains('#1 First (open)'));
      expect(result, contains('#2 Second (closed)'));
    });
  });
}
