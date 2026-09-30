import 'package:test/test.dart';
import 'package:claudart/templates/plan_template.dart';

void main() {
  group('planStub', () {
    test('includes project name in title', () {
      final result = planStub(projectName: 'my-app');
      expect(result, contains('my-app — plan'));
    });

    test('omits dartrix section when usesDartrix is false', () {
      final result = planStub(projectName: 'my-app');
      expect(result, isNot(contains('dartrix coverage gaps')));
    });

    test('includes dartrix section when usesDartrix is true', () {
      final result = planStub(projectName: 'my-app', usesDartrix: true);
      expect(result, contains('dartrix coverage gaps'));
      expect(result, contains('matrix.gaps()'));
    });

    test('omits GitHub issues section when githubTracking is false', () {
      final result = planStub(projectName: 'my-app');
      expect(result, isNot(contains('GitHub issues')));
    });

    test('includes GitHub issues section when githubTracking is true', () {
      final result = planStub(projectName: 'my-app', githubTracking: true);
      expect(result, contains('GitHub issues'));
    });

    test('slots in the pre-rendered github log section', () {
      final result = planStub(
        projectName: 'my-app',
        githubTracking: true,
        githubLogSection: '- #1 Example issue (open)',
      );
      expect(result, contains('- #1 Example issue (open)'));
    });

    test(
        'falls back to empty-state text when githubTracking is true but no section given',
        () {
      final result = planStub(projectName: 'my-app', githubTracking: true);
      expect(result, contains('No issues tracked yet'));
    });

    test('omits architecture section when no diagram given', () {
      final result = planStub(projectName: 'my-app');
      expect(result, isNot(contains('## Architecture')));
    });

    test('slots in the pre-rendered architecture diagram', () {
      final result = planStub(
        projectName: 'my-app',
        mermaidArchitectureDiagram: '```mermaid\ngraph TD\n    A --> B\n```',
      );
      expect(result, contains('## Architecture'));
      expect(result, contains('A --> B'));
    });

    test('has What\'s been built and What\'s next stub sections', () {
      final result = planStub(projectName: 'my-app');
      expect(result, contains('What\'s been built'));
      expect(result, contains('What\'s next'));
    });
  });
}
