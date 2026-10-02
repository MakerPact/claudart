import 'dart:convert';
import 'package:test/test.dart';
import 'package:claudart/forge/forge_adapter.dart';
import 'package:claudart/forge/forge_registry.dart';
import 'package:claudart/forge/github_adapter.dart';
import 'package:claudart/forge/gitlab_adapter.dart';
import 'package:claudart/forge/scrape_fallback.dart';

/// Canned-response HTTP fake: maps URL → (status, body). Any URL not
/// in the map throws ForgeHttpException, simulating network failure.
class FakeHttpClient implements ForgeHttpClient {
  final Map<String, ForgeHttpResponse> responses;
  final List<String> requested = [];
  FakeHttpClient(this.responses);

  @override
  Future<ForgeHttpResponse> get(String url,
      {Map<String, String>? headers}) async {
    requested.add(url);
    final response = responses[url];
    if (response == null) {
      throw ForgeHttpException('network unreachable: $url');
    }
    return response;
  }
}

String _issueJson({
  String title = 'Crash on startup',
  String body = 'App crashes when launched.',
  int comments = 0,
}) =>
    jsonEncode({
      'title': title,
      'body': body,
      'state': 'open',
      'comments': comments,
      'labels': [
        {'name': 'bug'},
      ],
    });

void main() {
  // ── URL parsing ────────────────────────────────────────────────────────────

  group('GithubAdapter.parseIssueUrl', () {
    final adapter = GithubAdapter();

    test('parses a canonical issue URL', () {
      final repo = adapter.parseIssueUrl(
          Uri.parse('https://github.com/arduino/Arduino/issues/12036'));
      expect(repo, isNotNull);
      expect(repo!.host, 'github.com');
      expect(repo.owner, 'arduino');
      expect(repo.repo, 'Arduino');
      expect(repo.number, 12036);
      expect(repo.slug, 'arduino/Arduino');
    });

    test('rejects non-issue URLs', () {
      expect(
        adapter.parseIssueUrl(Uri.parse('https://github.com/arduino/Arduino')),
        isNull,
      );
      expect(
        adapter.parseIssueUrl(
            Uri.parse('https://github.com/arduino/Arduino/pulls/5')),
        isNull,
      );
    });

    test('rejects non-numeric issue numbers', () {
      expect(
        adapter.parseIssueUrl(
            Uri.parse('https://github.com/arduino/Arduino/issues/abc')),
        isNull,
      );
    });

    test('enterprise host keeps its own host', () {
      final repo = adapter.parseIssueUrl(
          Uri.parse('https://ghe.example.com/team/tool/issues/7'));
      expect(repo, isNotNull);
      expect(repo!.host, 'ghe.example.com');
    });
  });

  group('GitlabAdapter.parseIssueUrl', () {
    final adapter = GitlabAdapter();

    test('parses a canonical issue URL with /-/ separator', () {
      final repo = adapter.parseIssueUrl(
          Uri.parse('https://gitlab.com/group/project/-/issues/42'));
      expect(repo, isNotNull);
      expect(repo!.owner, 'group');
      expect(repo.repo, 'project');
      expect(repo.number, 42);
    });

    test('parses nested group paths', () {
      final repo = adapter.parseIssueUrl(
          Uri.parse('https://gitlab.com/group/subgroup/project/-/issues/9'));
      expect(repo, isNotNull);
      expect(repo!.owner, 'group/subgroup');
      expect(repo.repo, 'project');
    });

    test('rejects URLs without the /-/ separator', () {
      expect(
        adapter.parseIssueUrl(
            Uri.parse('https://gitlab.com/group/project/issues/42')),
        isNull,
      );
    });
  });

  group('ScrapeFallbackAdapter.parseIssueUrl', () {
    final adapter = ScrapeFallbackAdapter();

    test('parses generic /issues/N shape', () {
      final repo = adapter.parseIssueUrl(
          Uri.parse('https://bitbucket.org/owner/repo/issues/12'));
      expect(repo, isNotNull);
      expect(repo!.owner, 'owner');
      expect(repo.repo, 'repo');
      expect(repo.number, 12);
    });

    test('skips GitLab-style - separator', () {
      final repo = adapter
          .parseIssueUrl(Uri.parse('https://codeberg.org/owner/repo/issues/3'));
      expect(repo, isNotNull);
      expect(repo!.owner, 'owner');
    });

    test('rejects URLs without an issue marker', () {
      expect(
        adapter.parseIssueUrl(Uri.parse('https://example.com/owner/repo')),
        isNull,
      );
    });
  });

  // ── Registry ───────────────────────────────────────────────────────────────

  group('ForgeRegistry', () {
    test('github.com resolves to the GitHub adapter first', () {
      final registry = ForgeRegistry.builtin();
      expect(registry.forHost('github.com'), isA<GithubAdapter>());
    });

    test('gitlab.com resolves to the GitLab adapter first', () {
      final registry = ForgeRegistry.builtin();
      expect(registry.forHost('gitlab.com'), isA<GitlabAdapter>());
    });

    test('unknown hosts fall through to the scrape adapter', () {
      final registry = ForgeRegistry.builtin();
      expect(registry.forHost('bitbucket.org'), isA<ScrapeFallbackAdapter>());
    });
  });

  // ── Fetch ──────────────────────────────────────────────────────────────────

  group('GithubAdapter.fetchIssue', () {
    final adapter = GithubAdapter();
    final repo = adapter.parseIssueUrl(
        Uri.parse('https://github.com/arduino/Arduino/issues/12036'))!;

    test('ok response maps to ForgeIssue', () async {
      final client = FakeHttpClient({
        'https://api.github.com/repos/arduino/Arduino/issues/12036':
            ForgeHttpResponse(200, _issueJson(comments: 2)),
        'https://api.github.com/repos/arduino/Arduino/issues/12036/comments':
            ForgeHttpResponse(
                200,
                jsonEncode([
                  {'body': 'First comment'},
                  {'body': 'Second comment'},
                ])),
      });
      final result = await adapter.fetchIssue(repo, client: client);
      expect(result.ok, isTrue);
      expect(result.issue!.title, 'Crash on startup');
      expect(result.issue!.labels, ['bug']);
      expect(result.issue!.comments, ['First comment', 'Second comment']);
    });

    test('404 yields auth guidance, not a raw error', () async {
      final client = FakeHttpClient({
        'https://api.github.com/repos/arduino/Arduino/issues/12036':
            const ForgeHttpResponse(404, ''),
      });
      final result = await adapter.fetchIssue(repo, client: client);
      expect(result.ok, isFalse);
      expect(result.error, contains('GITHUB_TOKEN'));
    });

    test('network failure yields a reachable message', () async {
      final client = FakeHttpClient({}); // no responses → throw
      final result = await adapter.fetchIssue(repo, client: client);
      expect(result.ok, isFalse);
      expect(result.error, contains('Could not reach'));
    });
  });

  group('GitlabAdapter.fetchIssue', () {
    final adapter = GitlabAdapter();
    final repo = adapter.parseIssueUrl(
        Uri.parse('https://gitlab.com/group/project/-/issues/42'))!;

    test('ok response maps to ForgeIssue with description as body', () async {
      final client = FakeHttpClient({
        'https://gitlab.com/api/v4/projects/group%2Fproject/issues/42':
            ForgeHttpResponse(
                200,
                jsonEncode({
                  'title': 'Build fails',
                  'description': 'CI is red.',
                  'state': 'opened',
                  'labels': ['ci'],
                  'user_notes_count': 0,
                })),
      });
      final result = await adapter.fetchIssue(repo, client: client);
      expect(result.ok, isTrue);
      expect(result.issue!.body, 'CI is red.');
      expect(result.issue!.state, 'opened');
    });

    test('404 yields token guidance', () async {
      final client = FakeHttpClient({
        'https://gitlab.com/api/v4/projects/group%2Fproject/issues/42':
            const ForgeHttpResponse(404, ''),
      });
      final result = await adapter.fetchIssue(repo, client: client);
      expect(result.ok, isFalse);
      expect(result.error, contains('GITLAB_TOKEN'));
    });
  });

  group('ScrapeFallbackAdapter.fetchIssue', () {
    final adapter = ScrapeFallbackAdapter();
    final repo = adapter
        .parseIssueUrl(Uri.parse('https://example.org/owner/repo/issues/5'))!;

    test('extracts title and body from HTML', () async {
      final client = FakeHttpClient({
        'https://example.org/owner/repo/issues/5': const ForgeHttpResponse(
            200,
            '<html><head><title>Widget breaks · owner/repo · example.org</title></head>'
            '<body><div class="issue-body"><p>It explodes.</p></div></body></html>'),
      });
      final result = await adapter.fetchIssue(repo, client: client);
      expect(result.ok, isTrue);
      expect(result.issue!.title, 'Widget breaks');
      expect(result.issue!.body, contains('It explodes'));
    });

    test('JS-rendered page yields a dedicated-adapter message', () async {
      final client = FakeHttpClient({
        'https://example.org/owner/repo/issues/5': const ForgeHttpResponse(
            200, '<html><head><title></title></head><body></body></html>'),
      });
      final result = await adapter.fetchIssue(repo, client: client);
      expect(result.ok, isFalse);
      expect(result.error, contains('dedicated adapter'));
    });
  });

  // ── defaultBranch ──────────────────────────────────────────────────────────

  group('defaultBranch', () {
    test('GitHub returns default_branch from the repo endpoint', () async {
      final adapter = GithubAdapter();
      final repo = adapter.parseIssueUrl(
          Uri.parse('https://github.com/arduino/Arduino/issues/1'))!;
      final client = FakeHttpClient({
        'https://api.github.com/repos/arduino/Arduino':
            const ForgeHttpResponse(200, '{"default_branch":"master"}'),
      });
      expect(await adapter.defaultBranch(repo, client: client), 'master');
    });

    test('scrape fallback returns null (caller falls back to main)', () async {
      final adapter = ScrapeFallbackAdapter();
      final repo = adapter
          .parseIssueUrl(Uri.parse('https://example.org/owner/repo/issues/5'))!;
      expect(await adapter.defaultBranch(repo), isNull);
    });
  });
}
