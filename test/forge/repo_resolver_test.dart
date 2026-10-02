import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';
import 'dart:io';
import 'package:claudart/forge/forge_adapter.dart';
import 'package:claudart/forge/repo_resolver.dart';
import 'package:claudart/process_runner.dart';
import 'package:claudart/registry.dart';

class _MockRunner extends Mock implements ProcessRunner {}

ProcessResult _ok([String stdout = '']) => ProcessResult(0, 0, stdout, '');

ProcessResult _fail([String stderr = 'boom']) =>
    ProcessResult(0, 1, '', stderr);

ForgeRepo _repo() => const ForgeRepo(
      host: 'github.com',
      owner: 'example',
      repo: 'example-repo',
      issueNumber: 12036,
      issueUrl: 'https://github.com/example/example-repo/issues/12036',
    );

void main() {
  group('RepoResolver.findRegisteredClone', () {
    test('matches https remote with .git suffix', () {
      final runner = _MockRunner();
      when(() => runner.runSync('git', any(that: contains('get-url')),
              workingDirectory: any(named: 'workingDirectory')))
          .thenReturn(_ok('https://github.com/example/example-repo.git'));
      final resolver = RepoResolver(runner);
      final registry = Registry.empty().add(const RegistryEntry(
        name: 'example-repo',
        projectRoot: '/repos/example-repo',
        workspacePath: '/ws/example-repo',
        createdAt: '2026-01-01',
        lastSession: '2026-01-01',
      ));
      expect(resolver.findRegisteredClone(_repo(), registry), '/repos/example-repo');
    });

    test('matches ssh scp-style remote', () {
      final runner = _MockRunner();
      when(() => runner.runSync('git', any(that: contains('get-url')),
              workingDirectory: any(named: 'workingDirectory')))
          .thenReturn(_ok('git@github.com:example/example-repo.git'));
      final resolver = RepoResolver(runner);
      final registry = Registry.empty().add(const RegistryEntry(
        name: 'example-repo',
        projectRoot: '/repos/example-repo',
        workspacePath: '/ws/example-repo',
        createdAt: '2026-01-01',
        lastSession: '2026-01-01',
      ));
      expect(resolver.findRegisteredClone(_repo(), registry), '/repos/example-repo');
    });

    test('different repo → no match', () {
      final runner = _MockRunner();
      when(() => runner.runSync('git', any(that: contains('get-url')),
              workingDirectory: any(named: 'workingDirectory')))
          .thenReturn(_ok('https://github.com/other/repo'));
      final resolver = RepoResolver(runner);
      final registry = Registry.empty().add(const RegistryEntry(
        name: 'other',
        projectRoot: '/repos/other',
        workspacePath: '/ws/other',
        createdAt: '2026-01-01',
        lastSession: '2026-01-01',
      ));
      expect(resolver.findRegisteredClone(_repo(), registry), isNull);
    });
  });

  group('RepoResolver.verifyClone', () {
    test('clean matching clone → RepoReady', () async {
      final runner = _MockRunner();
      when(() => runner.runSync('git', any(that: contains('get-url')),
              workingDirectory: any(named: 'workingDirectory')))
          .thenReturn(_ok('https://github.com/example/example-repo.git'));
      when(() => runner.run('git', any(that: contains('fetch')),
              workingDirectory: any(named: 'workingDirectory')))
          .thenAnswer((_) async => _ok());
      when(() => runner.run('git', any(that: contains('status')),
              workingDirectory: any(named: 'workingDirectory')))
          .thenAnswer((_) async => _ok(''));
      when(() => runner.runSync('git', any(that: contains('--abbrev-ref')),
              workingDirectory: any(named: 'workingDirectory')))
          .thenReturn(_ok('main'));

      final resolver = RepoResolver(runner);
      final outcome = await resolver.verifyClone(
        clonePath: '/repos/example-repo',
        repo: _repo(),
        cloneUrl: 'https://github.com/example/example-repo.git',
      );
      expect(outcome, isA<RepoReady>());
      expect((outcome as RepoReady).branch, 'main');
    });

    test('remote pointing elsewhere → RemoteMismatch', () async {
      final runner = _MockRunner();
      when(() => runner.runSync('git', any(that: contains('get-url')),
              workingDirectory: any(named: 'workingDirectory')))
          .thenReturn(_ok('https://github.com/someone/else.git'));

      final resolver = RepoResolver(runner);
      final outcome = await resolver.verifyClone(
        clonePath: '/repos/wrong',
        repo: _repo(),
        cloneUrl: 'https://github.com/example/example-repo.git',
      );
      expect(outcome, isA<RemoteMismatch>());
      expect((outcome as RemoteMismatch).actualRemote,
          'https://github.com/someone/else.git');
    });

    test('uncommitted changes → DirtyTree', () async {
      final runner = _MockRunner();
      when(() => runner.runSync('git', any(that: contains('get-url')),
              workingDirectory: any(named: 'workingDirectory')))
          .thenReturn(_ok('https://github.com/example/example-repo.git'));
      when(() => runner.run('git', any(that: contains('fetch')),
              workingDirectory: any(named: 'workingDirectory')))
          .thenAnswer((_) async => _ok());
      when(() => runner.run('git', any(that: contains('status')),
              workingDirectory: any(named: 'workingDirectory')))
          .thenAnswer((_) async => _ok(' M lib/foo.dart'));

      final resolver = RepoResolver(runner);
      final outcome = await resolver.verifyClone(
        clonePath: '/repos/example-repo',
        repo: _repo(),
        cloneUrl: 'https://github.com/example/example-repo.git',
      );
      expect(outcome, isA<DirtyTree>());
    });

    test('fetch failure → GitError', () async {
      final runner = _MockRunner();
      when(() => runner.runSync('git', any(that: contains('get-url')),
              workingDirectory: any(named: 'workingDirectory')))
          .thenReturn(_ok('https://github.com/example/example-repo.git'));
      when(() => runner.run('git', any(that: contains('fetch')),
              workingDirectory: any(named: 'workingDirectory')))
          .thenAnswer((_) async => _fail('no network'));

      final resolver = RepoResolver(runner);
      final outcome = await resolver.verifyClone(
        clonePath: '/repos/example-repo',
        repo: _repo(),
        cloneUrl: 'https://github.com/example/example-repo.git',
      );
      expect(outcome, isA<GitError>());
      expect((outcome as GitError).message, contains('fetch'));
    });
  });

  group('RepoResolver.createFixBranch', () {
    test('creates fix/issue-N off origin base', () {
      final runner = _MockRunner();
      when(() => runner.runSync('git', any(that: contains('rev-parse')),
              workingDirectory: any(named: 'workingDirectory')))
          .thenReturn(_fail('does not exist'));
      when(() => runner.runSync('git', any(that: contains('checkout')),
          workingDirectory: any(named: 'workingDirectory'))).thenReturn(_ok());

      final resolver = RepoResolver(runner);
      final result = resolver.createFixBranch(
        clonePath: '/repos/example-repo',
        issueNumber: 12036,
        baseBranch: 'master',
      );
      expect(result.branch, 'fix/issue-12036');
      expect(result.error, isNull);
      verify(() => runner.runSync('git', any(that: contains('checkout')),
          workingDirectory: any(named: 'workingDirectory'))).called(1);
    });

    test('existing branch is reused idempotently', () {
      final runner = _MockRunner();
      when(() => runner.runSync('git', any(that: contains('rev-parse')),
              workingDirectory: any(named: 'workingDirectory')))
          .thenReturn(_ok('refs/heads/fix/issue-12036'));
      when(() => runner.runSync('git', any(that: contains('checkout')),
          workingDirectory: any(named: 'workingDirectory'))).thenReturn(_ok());

      final resolver = RepoResolver(runner);
      final result = resolver.createFixBranch(
        clonePath: '/repos/example-repo',
        issueNumber: 12036,
        baseBranch: 'main',
      );
      expect(result.branch, 'fix/issue-12036');
      expect(result.error, isNull);
    });
  });
}
