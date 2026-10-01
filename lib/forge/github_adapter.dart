// github_adapter.dart — GitHub + GitHub Enterprise issue fetching (Phase 14)

import 'dart:convert';
import 'dart:io';
import 'forge_adapter.dart';

/// GitHub REST adapter. Handles github.com and any GitHub Enterprise
/// host (ghe.example.com) — the API path shape is identical, only the
/// base URL differs. Public issues need no token; private issues honor
/// GITHUB_TOKEN / GH_TOKEN env vars when set.
class GithubAdapter extends ForgeAdapter {
  @override
  String get name => 'github';

  @override
  String get host => 'github.com';

  @override
  bool handlesHost(String h) =>
      h == 'github.com' ||
      h == 'www.github.com' ||
      h.endsWith('.ghe.github.com');

  /// Enterprise hosts are their own origin — clone URLs point at the
  /// URL's host, not github.com. Overrides the base-class getter so
  /// `cloneUrl` builds against the issue URL's actual host.
  String cloneUrlFor(ForgeRepo repo) =>
      'https://${repo.host}/${repo.owner}/${repo.repo}.git';

  @override
  ForgeRepo? parseIssueUrl(Uri uri) {
    // Shape: https://github.com/<owner>/<repo>/issues/<number>
    final segments = uri.pathSegments;
    if (segments.length < 4) return null;
    if (segments[2] != 'issues') return null;
    final number = int.tryParse(segments[3]);
    if (number == null) return null;
    return ForgeRepo(
      host: uri.host,
      owner: segments[0],
      repo: segments[1].replaceAll('.git', ''),
      issueNumber: number,
      issueUrl:
          'https://${uri.host}/${segments[0]}/${segments[1]}/issues/$number',
    );
  }

  /// API base for [repo]: github.com → api.github.com; any other host
  /// (Enterprise) → `https://<host>/api/v3`.
  String _apiBase(ForgeRepo repo) {
    if (repo.host == 'github.com' || repo.host == 'www.github.com') {
      return 'https://api.github.com';
    }
    return 'https://${repo.host}/api/v3';
  }

  Map<String, String> _headers() {
    final headers = <String, String>{
      'Accept': 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
    };
    final token = _githubToken();
    if (token != null) headers['Authorization'] = 'Bearer $token';
    return headers;
  }

  static String? _githubToken() {
    final env = Platform.environment;
    return env['GITHUB_TOKEN'] ?? env['GH_TOKEN'];
  }

  @override
  Future<ForgeFetchResult> fetchIssue(
    ForgeRepo repo, {
    ForgeHttpClient? client,
  }) async {
    final http = client ?? RealForgeHttpClient();
    try {
      final response = await http.get(
        '${_apiBase(repo)}/repos/${repo.owner}/${repo.repo}/issues/${repo.number}',
        headers: _headers(),
      );
      if (response.statusCode == 404) {
        return ForgeFetchResult.fail(
          'Issue #${repo.number} not found on ${repo.host} (or the repo is '
          'private and no token is set). Set GITHUB_TOKEN or run '
          '`gh auth login` for private repos.',
        );
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        return ForgeFetchResult.fail(
          'GitHub rejected the request (${response.statusCode}). Your token '
          'may be expired or lack access to ${repo.slug}.',
        );
      }
      if (response.statusCode != 200) {
        return ForgeFetchResult.fail(
          'GitHub returned HTTP ${response.statusCode} fetching issue '
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

      // Comments: fetched only when the issue has a non-zero comment
      // count — saves a request for the common single-post issue.
      final comments = <String>[];
      final commentCount = (json['comments'] as int?) ?? 0;
      if (commentCount > 0) {
        final commentResponse = await http.get(
          '${_apiBase(repo)}/repos/${repo.owner}/${repo.repo}/issues/${repo.number}/comments',
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
        // Comment-fetch failure is non-fatal: the issue body alone is
        // enough to seed a handoff. Comments are enrichment, not a gate.
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
        '${_apiBase(repo)}/repos/${repo.owner}/${repo.repo}',
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
