import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:claudart/commands/issue.dart';
import 'package:claudart/forge/forge_adapter.dart';
import 'package:claudart/forge/forge_registry.dart';
import 'package:claudart/forge/github_adapter.dart';
import 'package:claudart/paths.dart';
import 'package:claudart/process_runner.dart';
import 'package:claudart/registry.dart';
import '../helpers/mocks.dart';

class _MockRunner extends Mock implements ProcessRunner {}

class _CannedHttpClient implements ForgeHttpClient {
  final Map<String, ForgeHttpResponse> responses;
  _CannedHttpClient(this.responses);

  @override
  Future<ForgeHttpResponse> get(String url,
      {Map<String, String>? headers}) async {
    final r = responses[url];
    if (r == null) throw ForgeHttpException('unreachable: $url');
    return r;
  }
}

class _ExitException implements Exception {
  final int code;
  const _ExitException(this.code);
}

Never _throwExit(int code) => throw _ExitException(code);

const _issueUrl = 'https://github.com/example/example-repo/issues/12036';
const _issueApi = 'https://api.github.com/repos/example/example-repo/issues/12036';

/// A GitHub adapter with a canned HTTP client — the wizard's fetch step
/// hits the real API shape without a socket.
class _CannedGithubAdapter extends GithubAdapter {
  final ForgeHttpClient client;
  _CannedGithubAdapter(this.client);

  @override
  Future<ForgeFetchResult> fetchIssue(ForgeRepo repo,
          {ForgeHttpClient? client}) =>
      super.fetchIssue(repo, client: this.client);

  @override
  Future<String?> defaultBranch(ForgeRepo repo, {ForgeHttpClient? client}) =>
      super.defaultBranch(repo, client: this.client);
}

void main() {
  tearDown(() => resetMocktailState());

  test('no args → usage + exit 1', () async {
    expect(
      () => runIssue(
        [],
        io: MemoryFileIO(),
        forgeRegistry: ForgeRegistry.builtin(),
        processRunner: _MockRunner(),
        confirmFn: (_) => true,
        promptFn: (q, {optional = false}) => '',
        exitFn: _throwExit,
      ),
      throwsA(isA<_ExitException>().having((e) => e.code, 'code', 1)),
    );
  });

  test('non-issue URL → exit 1', () async {
    expect(
      () => runIssue(
        ['https://github.com/example/example-repo'],
        io: MemoryFileIO(),
        forgeRegistry: ForgeRegistry.builtin(),
        processRunner: _MockRunner(),
        confirmFn: (_) => true,
        promptFn: (q, {optional = false}) => '',
        exitFn: _throwExit,
      ),
      throwsA(isA<_ExitException>().having((e) => e.code, 'code', 1)),
    );
  });

  test('fetch 404 → auth guidance + exit 1', () async {
    final adapter = _CannedGithubAdapter(
        _CannedHttpClient({_issueApi: const ForgeHttpResponse(404, '')}));
    final registry = ForgeRegistry.builtin();
    // Replace github with the canned one.
    final forges = ForgeRegistry([
      adapter,
      registry.forHost('gitlab.com')!,
      registry.forHost('bitbucket.org')!
    ]);

    expect(
      () => runIssue(
        [_issueUrl],
        io: MemoryFileIO(),
        forgeRegistry: forges,
        processRunner: _MockRunner(),
        confirmFn: (_) => true,
        promptFn: (q, {optional = false}) => '',
        exitFn: _throwExit,
      ),
      throwsA(isA<_ExitException>().having((e) => e.code, 'code', 1)),
    );
  });

  test('full happy path: fetch → clone → branch → handoff written', () async {
    final http = _CannedHttpClient({
      _issueApi: ForgeHttpResponse(
          200,
          jsonEncode({
            'title': 'Crash on startup',
            'body':
                'App crashes when launched.\n\nExpected behavior: it should start cleanly.',
            'state': 'open',
            'comments': 0,
            'labels': [
              {'name': 'bug'}
            ],
          })),
      'https://api.github.com/repos/example/example-repo':
          const ForgeHttpResponse(200, '{"default_branch":"master"}'),
    });
    final adapter = _CannedGithubAdapter(http);
    final forges = ForgeRegistry([adapter]);

    final runner = _MockRunner();
    // No registered clone → prompt for path → clone there.
    when(() => runner.runSync('git', any(that: contains('get-url')),
            workingDirectory: any(named: 'workingDirectory')))
        .thenReturn(ProcessResult(0, 1, '', 'no remote'));
    when(() => runner.run('git', any(that: contains('clone'))))
        .thenAnswer((_) async => ProcessResult(0, 0, '', ''));
    when(() => runner.runSync('git', any(that: contains('rev-parse')),
            workingDirectory: any(named: 'workingDirectory')))
        .thenReturn(ProcessResult(0, 1, '', 'no branch'));
    when(() => runner.runSync('git', any(that: contains('checkout')),
            workingDirectory: any(named: 'workingDirectory')))
        .thenReturn(ProcessResult(0, 0, '', ''));

    final io = MemoryFileIO();
    // Seed an empty registry so Registry.load finds one.
    Registry.empty().save(io: io);

    await runIssue(
      [_issueUrl],
      io: io,
      forgeRegistry: forges,
      processRunner: runner,
      confirmFn: (_) => true,
      promptFn: (q, {optional = false}) => 'test_repos/example-repo',
      exitFn: _throwExit,
    );

    // Registry now has the imported project.
    final registry = Registry.load(io: io);
    final entry = registry.findByProjectRoot('test_repos/example-repo');
    expect(entry, isNotNull);
    expect(entry!.name, 'example_example-repo');

    // Handoff written with the issue as the Bug section.
    final handoff = io.read(handoffPathFor(entry.workspacePath));
    expect(handoff, contains('Crash on startup'));
    expect(handoff, contains(_issueUrl));
    expect(handoff, contains('fix/issue-12036'));
    // Expected Behavior extracted from the "Expected behavior:" line.
    expect(handoff, contains('it should start cleanly'));
  });
}
