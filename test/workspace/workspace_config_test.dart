import 'package:test/test.dart';
import 'package:claudart/workspace/workspace_config.dart';
import 'package:claudart/pipeline/agent_flow.dart';
import '../helpers/mocks.dart';

void main() {
  group('StackType', () {
    test('fromString parses correctly', () {
      expect(StackType.fromString('dart'), equals(StackType.dart));
      expect(StackType.fromString('flutter'), equals(StackType.flutter));
      expect(StackType.fromString('unknown'), isNull);
    });

    test('value returns name', () {
      expect(StackType.dart.value, equals('dart'));
      expect(StackType.flutter.value, equals('flutter'));
    });
  });

  group('WorkspaceRole', () {
    test('fromString parses correctly and defaults to contributor', () {
      expect(WorkspaceRole.fromString('maintainer'), equals(WorkspaceRole.maintainer));
      expect(WorkspaceRole.fromString('contributor'), equals(WorkspaceRole.contributor));
      expect(WorkspaceRole.fromString('unknown'), equals(WorkspaceRole.contributor));
    });

    test('canUpdateReadme returns true only for maintainer', () {
      expect(WorkspaceRole.maintainer.canUpdateReadme, isTrue);
      expect(WorkspaceRole.contributor.canUpdateReadme, isFalse);
    });

    test('value returns name', () {
      expect(WorkspaceRole.maintainer.value, equals('maintainer'));
      expect(WorkspaceRole.contributor.value, equals('contributor'));
    });
  });

  group('ProofNotation', () {
    test('fromString parses correctly and defaults to generic', () {
      expect(ProofNotation.fromString('dart-grounded'), equals(ProofNotation.dartGrounded));
      expect(ProofNotation.fromString('ts-grounded'), equals(ProofNotation.tsGrounded));
      expect(ProofNotation.fromString('unknown'), equals(ProofNotation.generic));
    });

    test('value returns string literal representation', () {
      expect(ProofNotation.dartGrounded.value, equals('dart-grounded'));
      expect(ProofNotation.tsGrounded.value, equals('ts-grounded'));
      expect(ProofNotation.generic.value, equals('generic'));
    });

    test('description returns human-readable instructions', () {
      expect(ProofNotation.dartGrounded.description, contains('Dart expressions'));
      expect(ProofNotation.tsGrounded.description, contains('TypeScript expressions'));
      expect(ProofNotation.generic.description, contains('plain English'));
    });
  });

  group('WorkspaceOwner', () {
    test('fromJson parses correctly', () {
      final json = {
        'name': 'Test User',
        'email': 'test@example.com',
        'handle': 'testuser',
        'strict': true,
      };
      final owner = WorkspaceOwner.fromJson(json);
      expect(owner.name, equals('Test User'));
      expect(owner.email, equals('test@example.com'));
      expect(owner.handle, equals('testuser'));
      expect(owner.strict, isTrue);
    });

    test('fromJson handles missing strict flag gracefully', () {
      final json = {
        'name': 'Test User',
        'email': 'test@example.com',
        'handle': 'testuser',
      };
      final owner = WorkspaceOwner.fromJson(json);
      expect(owner.strict, isFalse);
    });
  });

  group('WorkspaceProject', () {
    test('fromJson parses correctly', () {
      final json = {
        'name': 'Test Project',
        'stack': ['dart', 'flutter'],
        'role': 'maintainer',
        'repo': 'user/repo',
        'org': 'myorg',
      };
      final project = WorkspaceProject.fromJson(json);
      expect(project.name, equals('Test Project'));
      expect(project.stack, equals([StackType.dart, StackType.flutter]));
      expect(project.role, equals(WorkspaceRole.maintainer));
      expect(project.repo, equals('user/repo'));
      expect(project.org, equals('myorg'));
    });

    test('fromJson handles invalid stack elements by ignoring them', () {
      final json = {
        'name': 'Test Project',
        'stack': ['dart', 'invalid_stack'],
      };
      final project = WorkspaceProject.fromJson(json);
      expect(project.stack, equals([StackType.dart]));
    });

    test('fromJson defaults role to contributor if missing', () {
      final json = {
        'name': 'Test Project',
      };
      final project = WorkspaceProject.fromJson(json);
      expect(project.role, equals(WorkspaceRole.contributor));
    });
  });

  group('WorkspaceSession', () {
    test('fromJson parses correctly', () {
      final json = {
        'agents': ['suggest', 'debug'],
        'knowledge': ['some fact', 'another fact'],
        'proofNotation': 'dart-grounded',
        'sensitivityMode': true,
      };
      final session = WorkspaceSession.fromJson(json);
      expect(session.agents, equals([AgentFlow.suggest, AgentFlow.debug]));
      expect(session.knowledge, equals(['some fact', 'another fact']));
      expect(session.proofNotation, equals(ProofNotation.dartGrounded));
      expect(session.sensitivityMode, isTrue);
    });

    test('fromJson handles invalid agents by ignoring them', () {
      final json = {
        'agents': ['suggest', 'invalid_agent'],
      };
      final session = WorkspaceSession.fromJson(json);
      expect(session.agents, equals([AgentFlow.suggest]));
    });

    test('fromJson handles default values correctly', () {
      final session = WorkspaceSession.fromJson({});
      expect(session.agents, isEmpty);
      expect(session.knowledge, isEmpty);
      expect(session.proofNotation, equals(ProofNotation.generic));
      expect(session.sensitivityMode, isFalse);
    });
  });

  group('WorkspaceConfig', () {
    test('fromJson parses correctly', () {
      final json = <String, dynamic>{
        'owner': <String, dynamic>{
          'name': 'Test User',
          'email': 'test@example.com',
          'handle': 'testuser',
        },
        'project': <String, dynamic>{
          'name': 'Test Project',
        },
        'session': <String, dynamic>{},
      };
      final config = WorkspaceConfig.fromJson(json);
      expect(config.owner.name, equals('Test User'));
      expect(config.project.name, equals('Test Project'));
      expect(config.session.agents, isEmpty);
    });

    test('load returns WorkspaceConfig when workspace.json exists and is valid', () {
      final io = MemoryFileIO(files: {
        '/test_workspace/workspace.json': '''
        {
          "owner": {
            "name": "Test User",
            "email": "test@example.com",
            "handle": "testuser",
            "strict": true
          },
          "project": {
            "name": "Test Project",
            "stack": ["dart"],
            "role": "maintainer"
          },
          "session": {
            "agents": ["suggest"],
            "knowledge": [],
            "proofNotation": "generic",
            "sensitivityMode": false
          }
        }
        '''
      });

      final config = WorkspaceConfig.load('/test_workspace', io: io);
      expect(config, isNotNull);
      expect(config!.owner.name, equals('Test User'));
      expect(config.project.name, equals('Test Project'));
      expect(config.project.stack, equals([StackType.dart]));
    });

    test('load returns null when workspace.json is missing', () {
      final io = MemoryFileIO(); // No files
      final config = WorkspaceConfig.load('/test_workspace', io: io);
      expect(config, isNull);
    });

    test('load returns null when workspace.json contains malformed JSON', () {
      final io = MemoryFileIO(files: {
        '/test_workspace/workspace.json': 'invalid json'
      });
      final config = WorkspaceConfig.load('/test_workspace', io: io);
      expect(config, isNull);
    });
  });
}
