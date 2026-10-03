import 'package:test/test.dart';
import 'package:claudart/forge/forge_adapter.dart';
import 'package:claudart/forge/gitee_adapter.dart';
import 'dart:convert';

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
  test('GiteeAdapter basics', () {
    final adapter = GiteeAdapter();
    expect(adapter.name, 'gitee');
    expect(adapter.host, 'gitee.com');
    expect(adapter.handlesHost('gitee.com'), isTrue);
    expect(adapter.handlesHost('www.gitee.com'), isTrue);
    expect(adapter.handlesHost('github.com'), isFalse);

    final repo = ForgeRepo(
      host: 'gitee.com',
      owner: 'owner',
      repo: 'repo',
      issueNumber: 1,
      issueUrl: 'https://gitee.com/owner/repo/issues/1',
    );
    expect(adapter.cloneUrl(repo), 'https://gitee.com/owner/repo.git');
  });

  test('GiteeAdapter parseIssueUrl', () {
    final adapter = GiteeAdapter();
    final valid = adapter.parseIssueUrl(Uri.parse('https://gitee.com/owner/repo/issues/42'));
    expect(valid?.issueNumber, 42);

    expect(adapter.parseIssueUrl(Uri.parse('https://gitee.com/owner/repo')), isNull);
    expect(adapter.parseIssueUrl(Uri.parse('https://gitee.com/owner/repo/pulls/42')), isNull);
    expect(adapter.parseIssueUrl(Uri.parse('https://gitee.com/owner/repo/issues/invalid')), isNull);
  });

  test('GiteeAdapter fetchIssue success', () async {
    final adapter = GiteeAdapter();
    final repo = ForgeRepo(
      host: 'gitee.com',
      owner: 'owner',
      repo: 'repo',
      issueNumber: 42,
      issueUrl: 'https://gitee.com/owner/repo/issues/42',
    );

    final client = _CannedHttpClient({
      'https://gitee.com/api/v5/repos/owner/repo/issues/42': ForgeHttpResponse(200, jsonEncode({
        'title': 'Test Issue',
        'body': 'Test Body',
        'state': 'closed',
        'labels': [{'name': 'bug'}],
      })),
      'https://gitee.com/api/v5/repos/owner/repo/issues/42/comments': ForgeHttpResponse(200, jsonEncode([
        {'body': 'Comment 1'},
      ])),
    });

    final result = await adapter.fetchIssue(repo, client: client);
    expect(result.ok, isTrue);
    expect(result.issue?.title, 'Test Issue');
    expect(result.issue?.state, 'closed');
    expect(result.issue?.labels, ['bug']);
    expect(result.issue?.comments, ['Comment 1']);
  });

  test('GiteeAdapter fetchIssue errors', () async {
    final adapter = GiteeAdapter();
    final repo = ForgeRepo(
      host: 'gitee.com',
      owner: 'owner',
      repo: 'repo',
      issueNumber: 42,
      issueUrl: 'https://gitee.com/owner/repo/issues/42',
    );

    var client = _CannedHttpClient({
      'https://gitee.com/api/v5/repos/owner/repo/issues/42': ForgeHttpResponse(404, ''),
    });
    var result = await adapter.fetchIssue(repo, client: client);
    expect(result.ok, isFalse);
    expect(result.error, contains('not found'));

    client = _CannedHttpClient({
      'https://gitee.com/api/v5/repos/owner/repo/issues/42': ForgeHttpResponse(403, ''),
    });
    result = await adapter.fetchIssue(repo, client: client);
    expect(result.ok, isFalse);
    expect(result.error, contains('rejected'));

    client = _CannedHttpClient({
      'https://gitee.com/api/v5/repos/owner/repo/issues/42': ForgeHttpResponse(500, ''),
    });
    result = await adapter.fetchIssue(repo, client: client);
    expect(result.ok, isFalse);
    expect(result.error, contains('HTTP 500'));

    client = _CannedHttpClient({});
    result = await adapter.fetchIssue(repo, client: client);
    expect(result.ok, isFalse);
    expect(result.error, contains('Could not reach'));
  });

  test('GiteeAdapter defaultBranch', () async {
    final adapter = GiteeAdapter();
    final repo = ForgeRepo(
      host: 'gitee.com',
      owner: 'owner',
      repo: 'repo',
      issueNumber: 42,
      issueUrl: 'https://gitee.com/owner/repo/issues/42',
    );

    var client = _CannedHttpClient({
      'https://gitee.com/api/v5/repos/owner/repo': ForgeHttpResponse(200, jsonEncode({'default_branch': 'master'})),
    });
    expect(await adapter.defaultBranch(repo, client: client), 'master');

    client = _CannedHttpClient({
      'https://gitee.com/api/v5/repos/owner/repo': ForgeHttpResponse(404, ''),
    });
    expect(await adapter.defaultBranch(repo, client: client), isNull);

    client = _CannedHttpClient({});
    expect(await adapter.defaultBranch(repo, client: client), isNull);
  });
}
