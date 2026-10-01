// gitlab_adapter.dart — GitLab (gitlab.com + self-hosted) issue fetching (Phase 14)

import 'dart:convert';
import 'dart:io';
import 'forge_adapter.dart';

/// GitLab REST adapter. gitlab.com and any self-hosted GitLab share the
/// same API shape; only the base URL differs. Project paths are URL-
/// encoded as a whole (nested groups like `group/subgroup/repo` are one
/// path parameter, not three segments).
class GitlabAdapter extends ForgeAdapter {
  @override
  String get name => 'gitlab';

  @override
  String get host => 'gitlab.com';

  @override
  bool handlesHost(String h) =>
      h == 'gitlab.com' || h == 'www.gitlab.com' || h.endsWith('.gitlab.com');

  @override
  String cloneUrl(ForgeRepo repo) =>
      'https://${repo.host}/${repo.owner}/${repo.repo}.git';

  @override
  ForgeRepo? parseIssueUrl(Uri uri) {
    // Shape: https://gitlab.com/<owner>/<repo>/-/issues/<number>
    // GitLab requires the `/-/` separator before the issue path. The
    // owner may be a nested group path (group/subgroup) — everything
    // before the repo segment is the owner; the last path segment
    // before `/-/` is the repo name.
    final segments = uri.pathSegments;
    final dashIndex = segments.indexOf('-');
    if (dashIndex < 2) return null; // need at least owner/repo before /-/
    if (dashIndex + 2 >= segments.length) return null;
    if (segments[dashIndex + 1] != 'issues') return null;
    final number = int.tryParse(segments[dashIndex + 2]);
    if (number == null) return null;

    final repo = segments[dashIndex - 1];
    final owner = segments.sublist(0, dashIndex - 1).join('/');
    if (owner.isEmpty || repo.isEmpty) return null;

    return ForgeRepo(
      host: uri.host,
      owner: owner,
      repo: repo,
      issueNumber: number,
      issueUrl: 'https://${uri.host}/$owner/$repo/-/issues/$number',
    );
  }

  String _apiBase(ForgeRepo repo) => 'https://${repo.host}/api/v4';

  /// GitLab identifies projects by URL-encoded full path.
  String _projectPath(ForgeRepo repo) =>
      Uri.encodeComponent('${repo.owner}/${repo.repo}');

  Map<String, String> _headers() {
    final headers = <String, String>{'Accept': 'application/json'};
    final token = _gitlabToken();
    if (token != null) headers['PRIVATE-TOKEN'] = token;
    return headers;
  }

  static String? _gitlabToken() {
    final env = Platform.environment;
    return env['GITLAB_TOKEN'] ?? env['GITLAB_ACCESS_TOKEN'];
  }

  @override
  Future<ForgeFetchResult> fetchIssue(
    ForgeRepo repo, {
    ForgeHttpClient? client,
  }) async {
    final http = client ?? RealForgeHttpClient();
    try {
      final response = await http.get(
        '${_apiBase(repo)}/projects/${_projectPath(repo)}/issues/${repo.number}',
        headers: _headers(),
      );
      if (response.statusCode == 404) {
        return ForgeFetchResult.fail(
          'Issue #${repo.number} not found on ${repo.host} (or the project is '
          'private and no token is set). Set GITLAB_TOKEN for private projects.',
        );
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        return ForgeFetchResult.fail(
          'GitLab rejected the request (${response.statusCode}). Your token '
          'may be expired or lack access to ${repo.slug}.',
        );
      }
      if (response.statusCode != 200) {
        return ForgeFetchResult.fail(
          'GitLab returned HTTP ${response.statusCode} fetching issue '
          '#${repo.number}.',
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final title = (json['title'] as String?) ?? '';
      final body = (json['description'] as String?) ?? '';
      final state = (json['state'] as String?) ?? 'opened';
      final labels =
          (json['labels'] as List<dynamic>? ?? []).whereType<String>().toList();

      // Notes (comments): fetched only when the issue has some.
      final comments = <String>[];
      final commentCount = (json['user_notes_count'] as int?) ?? 0;
      if (commentCount > 0) {
        final commentResponse = await http.get(
          '${_apiBase(repo)}/projects/${_projectPath(repo)}/issues/${repo.number}/notes?sort=asc',
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
        // Non-fatal, same rationale as the GitHub adapter.
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
        '${_apiBase(repo)}/projects/${_projectPath(repo)}',
        headers: _headers(),
      );
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      // GitLab exposes the default branch via repository details;
      // default_branch appears on the project object for modern GitLab.
      final direct = json['default_branch'] as String?;
      if (direct != null && direct.isNotEmpty) return direct;
      final repository = json['repository'] as Map<String, dynamic>?;
      return repository?['default_branch'] as String?;
    } on ForgeHttpException {
      return null;
    }
  }
}
