// gitee_adapter.dart — Gitee (gitee.com) issue fetching (Phase 14)
//
// Gitee is China's largest GitHub-like forge. Its REST API v5 mirrors
// GitHub's shape closely (repos/{owner}/{repo}/issues/{number}) with a
// few field-name differences: the issue body is `body` but the repo
// endpoint reports `default_branch`, and issue numbers are strings in
// some responses — parsed defensively throughout.

import 'dart:convert';
import 'dart:io';
import 'forge_adapter.dart';

class GiteeAdapter extends ForgeAdapter {
  @override
  String get name => 'gitee';

  @override
  String get host => 'gitee.com';

  @override
  bool handlesHost(String h) => h == 'gitee.com' || h == 'www.gitee.com';

  @override
  String cloneUrl(ForgeRepo repo) =>
      'https://${repo.host}/${repo.owner}/${repo.repo}.git';

  @override
  ForgeRepo? parseIssueUrl(Uri uri) {
    // Shape: https://gitee.com/<owner>/<repo>/issues/<number>
    final segments = uri.pathSegments;
    if (segments.length < 4) return null;
    if (segments[2] != 'issues') return null;
    final number = int.tryParse(segments[3]);
    if (number == null) return null;
    return ForgeRepo(
      host: uri.host,
      owner: segments[0],
      repo: segments[1],
      issueNumber: number,
      issueUrl:
          'https://${uri.host}/${segments[0]}/${segments[1]}/issues/$number',
    );
  }

  String get _apiBase => 'https://gitee.com/api/v5';

  Map<String, String> _headers() {
    final headers = <String, String>{'Accept': 'application/json'};
    final token = Platform.environment['GITEE_TOKEN'];
    if (token != null) headers['Authorization'] = 'token $token';
    return headers;
  }

  @override
  Future<ForgeFetchResult> fetchIssue(
    ForgeRepo repo, {
    ForgeHttpClient? client,
  }) async {
    final http = client ?? RealForgeHttpClient();
    try {
      final response = await http.get(
        '$_apiBase/repos/${repo.owner}/${repo.repo}/issues/${repo.number}',
        headers: _headers(),
      );
      if (response.statusCode == 404) {
        return ForgeFetchResult.fail(
          'Issue #${repo.number} not found on gitee.com (or the repo is '
          'private and no token is set). Set GITEE_TOKEN for private repos.',
        );
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        return ForgeFetchResult.fail(
          'Gitee rejected the request (${response.statusCode}). Your token '
          'may be expired or lack access to ${repo.slug}.',
        );
      }
      if (response.statusCode != 200) {
        return ForgeFetchResult.fail(
          'Gitee returned HTTP ${response.statusCode} fetching issue '
          '#${repo.number}.',
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final title = (json['title'] as String?) ?? '';
      final body = (json['body'] as String?) ?? '';
      final state = (json['state'] as String?) ?? 'open';
      final labels = (json['labels'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((l) => (l['name'] as String?) ?? '')
          .where((n) => n.isNotEmpty)
          .toList();

      // Gitee has no comment-count field on the issue object — fetch
      // comments unconditionally but treat failure/empty as fine.
      final comments = <String>[];
      final commentResponse = await http.get(
        '$_apiBase/repos/${repo.owner}/${repo.repo}/issues/${repo.number}/comments',
        headers: _headers(),
      );
      if (commentResponse.statusCode == 200) {
        final list = jsonDecode(commentResponse.body) as List<dynamic>;
        comments.addAll(
          list.whereType<Map<String, dynamic>>().map(
                (c) => (c['body'] as String?) ?? '',
              ),
        );
      }

      return ForgeFetchResult.ok(ForgeIssue(
        host: repo.host,
        owner: repo.owner,
        repo: repo.repo,
        number: repo.number,
        title: title,
        body: body,
        state: state,
        labels: labels,
        comments: comments,
        url: repo.issueUrl,
      ));
    } on ForgeHttpException catch (e) {
      return ForgeFetchResult.fail(
        'Could not reach ${repo.host}: ${e.message}',
      );
    }
  }

  @override
  Future<String?> defaultBranch(
    ForgeRepo repo, {
    ForgeHttpClient? client,
  }) async {
    final http = client ?? RealForgeHttpClient();
    try {
      final response = await http.get(
        '$_apiBase/repos/${repo.owner}/${repo.repo}',
        headers: _headers(),
      );
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return json['default_branch'] as String?;
    } on ForgeHttpException {
      return null;
    }
  }
}
