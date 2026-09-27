import 'package:test/test.dart';
import 'package:claudart/templates/diagram_template.dart';

void main() {
  group('stateDiagramTemplate', () {
    final result = stateDiagramTemplate(
      title: 'Session DFA',
      transitions: ['idle --> running : AgentStarted'],
    );

    test('wraps in a mermaid code block', () {
      expect(result, contains('```mermaid'));
      expect(result, contains('```'));
    });

    test('uses stateDiagram-v2 directive', () {
      expect(result, contains('stateDiagram-v2'));
    });

    test('includes the title as a comment', () {
      expect(result, contains('%% Session DFA'));
    });

    test('includes every transition', () {
      expect(result, contains('idle --> running : AgentStarted'));
    });
  });

  group('dependencyGraphTemplate', () {
    final result = dependencyGraphTemplate(
      title: 'Package deps',
      edges: ['claudart --> dartrix'],
    );

    test('uses graph LR directive', () {
      expect(result, contains('graph LR'));
    });

    test('includes every edge', () {
      expect(result, contains('claudart --> dartrix'));
    });
  });

  group('dataFlowTemplate', () {
    final result = dataFlowTemplate(
      title: 'Add wizard',
      steps: ['User->>CLI: claudart add'],
    );

    test('uses sequenceDiagram directive', () {
      expect(result, contains('sequenceDiagram'));
    });

    test('includes every step', () {
      expect(result, contains('User->>CLI: claudart add'));
    });
  });

  group('architectureGraphTemplate', () {
    final result = architectureGraphTemplate(
      title: 'Workspace layout',
      edges: ['A -->|generates| B'],
    );

    test('uses graph TD directive', () {
      expect(result, contains('graph TD'));
    });

    test('includes every edge', () {
      expect(result, contains('A -->|generates| B'));
    });
  });
}
