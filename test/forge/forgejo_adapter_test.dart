import 'package:test/test.dart';
import 'package:claudart/forge/forge_adapter.dart';
import 'package:claudart/forge/forgejo_adapter.dart';
import 'dart:convert';
import 'dart:io';

class _CannedHttpClient implements ForgeHttpClient {
  final Map<String, ForgeHttpResponse> responses;
  _CannedHttpClient(this.responses);

  @override
  Future<ForgeHttpResponse> get(String url, {Map<String, String>? headers}) async {
    final r = responses[url];
    if (r == null) throw ForgeHttpException('unreachable: $url');
    return r;
  }
}

void main() {
  test('ForgejoAdapter basics', () {
    final adapter = ForgejoAdapter();
    expect(adapter.name, 'forgejo');
    expect(adapter.host, 'codeberg.org');

    expect(adapter.handlesHost('codeberg.org'), isTrue);
    expect(adapter.handlesHost('www.codeberg.org'), isTrue);
    expect(adapter.handlesHost('gitea.com'), isTrue);
    expect(adapter.handlesHost('github.com'), isFalse);

    final repo = ForgeRepo(
      host: 'codeberg.org',
      owner: 'owner',
      repo: 'repo',
      issueNumber: 1,
      issueUrl: 'https://codeberg.org/owner/repo/issues/1',
    );
    expect(adapter.cloneUrl(repo), 'https://codeberg.org/owner/repo.git');
  });

  test('ForgejoAdapter parseIssueUrl', () {
    final adapter = ForgejoAdapter();
    final valid = adapter.parseIssueUrl(Uri.parse('https://codeberg.org/owner/repo/issues/42'));
    expect(valid?.issueNumber, 42);

    expect(adapter.parseIssueUrl(Uri.parse('https://codeberg.org/owner/repo')), isNull);
    expect(adapter.parseIssueUrl(Uri.parse('https://codeberg.org/owner/repo/pulls/42')), isNull);
    expect(adapter.parseIssueUrl(Uri.parse('https://codeberg.org/owner/repo/issues/invalid')), isNull);
  });

  test('ForgejoAdapter fetchIssue success without comments', () async {
    final adapter = ForgejoAdapter();
    final repo = ForgeRepo(
      host: 'codeberg.org',
      owner: 'owner',
      repo: 'repo',
      issueNumber: 42,
      issueUrl: 'https://codeberg.org/owner/repo/issues/42',
    );

    final client = _CannedHttpClient({
      'https://codeberg.org/api/v1/repos/owner/repo/issues/42': ForgeHttpResponse(200, jsonEncode({
        'title': 'Test Issue',
        'body': 'Test Body',
        'state': 'closed',
        'labels': [{'name': 'bug'}],
        'comments': 0,
      })),
    });

    final result = await adapter.fetchIssue(repo, client: client);
    expect(result.ok, isTrue);
    expect(result.issue?.title, 'Test Issue');
    expect(result.issue?.comments, isEmpty);
  });

  test('ForgejoAdapter fetchIssue success with comments', () async {
    final adapter = ForgejoAdapter();
    final repo = ForgeRepo(
      host: 'codeberg.org',
      owner: 'owner',
      repo: 'repo',
      issueNumber: 42,
      issueUrl: 'https://codeberg.org/owner/repo/issues/42',
    );

    final client = _CannedHttpClient({
      'https://codeberg.org/api/v1/repos/owner/repo/issues/42': ForgeHttpResponse(200, jsonEncode({
        'title': 'Test Issue',
        'body': 'Test Body',
        'state': 'open',
        'comments': 1,
      })),
      'https://codeberg.org/api/v1/repos/owner/repo/issues/42/comments': ForgeHttpResponse(200, jsonEncode([
        {'body': 'Comment 1'},
      ])),
    });

    final result = await adapter.fetchIssue(repo, client: client);
    expect(result.ok, isTrue);
    expect(result.issue?.comments, ['Comment 1']);
  });

  test('ForgejoAdapter fetchIssue errors', () async {
    final adapter = ForgejoAdapter();
    final repo = ForgeRepo(
      host: 'codeberg.org',
      owner: 'owner',
      repo: 'repo',
      issueNumber: 42,
      issueUrl: 'https://codeberg.org/owner/repo/issues/42',
    );

    var client = _CannedHttpClient({
      'https://codeberg.org/api/v1/repos/owner/repo/issues/42': ForgeHttpResponse(404, ''),
    });
    var result = await adapter.fetchIssue(repo, client: client);
    expect(result.ok, isFalse);
    expect(result.error, contains('not found'));

    client = _CannedHttpClient({
      'https://codeberg.org/api/v1/repos/owner/repo/issues/42': ForgeHttpResponse(403, ''),
    });
    result = await adapter.fetchIssue(repo, client: client);
    expect(result.ok, isFalse);
    expect(result.error, contains('rejected'));

    client = _CannedHttpClient({
      'https://codeberg.org/api/v1/repos/owner/repo/issues/42': ForgeHttpResponse(500, ''),
    });
    result = await adapter.fetchIssue(repo, client: client);
    expect(result.ok, isFalse);
    expect(result.error, contains('HTTP 500'));

    client = _CannedHttpClient({});
    result = await adapter.fetchIssue(repo, client: client);
    expect(result.ok, isFalse);
    expect(result.error, contains('Could not reach'));
  });

  test('ForgejoAdapter defaultBranch', () async {
    final adapter = ForgejoAdapter();
    final repo = ForgeRepo(
      host: 'codeberg.org',
      owner: 'owner',
      repo: 'repo',
      issueNumber: 42,
      issueUrl: 'https://codeberg.org/owner/repo/issues/42',
    );

    var client = _CannedHttpClient({
      'https://codeberg.org/api/v1/repos/owner/repo': ForgeHttpResponse(200, jsonEncode({'default_branch': 'master'})),
    });
    expect(await adapter.defaultBranch(repo, client: client), 'master');

    client = _CannedHttpClient({
      'https://codeberg.org/api/v1/repos/owner/repo': ForgeHttpResponse(404, ''),
    });
    expect(await adapter.defaultBranch(repo, client: client), isNull);

    client = _CannedHttpClient({});
    expect(await adapter.defaultBranch(repo, client: client), isNull);
  });
}
