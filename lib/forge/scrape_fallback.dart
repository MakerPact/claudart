// scrape_fallback.dart — last-resort HTML issue extraction (Phase 14)
//
// For hosts with no dedicated adapter (Bitbucket, Sourcehut, Gitee, …).
// Fetches the issue's HTML page and extracts title + body from the
// generic markup every forge uses: <title>, <h1>, and the issue body
// container. Deliberately coarse — it seeds a handoff, it does not
// promise fidelity. Structured fields (labels, state) are left empty.

import 'forge_adapter.dart';

class ScrapeFallbackAdapter extends ForgeAdapter {
  @override
  String get name => 'scrape';

  @override
  String get host => '';

  @override
  bool handlesHost(String h) => true; // fallback claims everything

  @override
  String cloneUrl(ForgeRepo repo) =>
      'https://${repo.host}/${repo.owner}/${repo.repo}.git';

  @override
  ForgeRepo? parseIssueUrl(Uri uri) {
    // Generic shape: https://<host>/<owner>/<repo>/.../issues/<number>
    // Accepts /issues/, /issue/, /-/issues/ (GitLab-style), and
    // /ticket/ (Trac-style) path segments.
    final segments = uri.pathSegments;
    int? issueIdx;
    for (var i = 0; i < segments.length; i++) {
      final s = segments[i];
      if (s == 'issues' || s == 'issue' || s == 'ticket') {
        if (i + 1 < segments.length) issueIdx = i;
      }
    }
    if (issueIdx == null) return null;
    final number = int.tryParse(segments[issueIdx + 1]);
    if (number == null) return null;

    // Owner/repo = the two segments before the issue marker, skipping
    // a GitLab-style '-' separator.
    var ownerEnd = issueIdx;
    if (ownerEnd >= 2 && segments[ownerEnd - 1] == '-') ownerEnd--;
    if (ownerEnd < 2) return null;
    final owner = segments[ownerEnd - 2];
    final repo = segments[ownerEnd - 1];
    if (owner.isEmpty || repo.isEmpty) return null;

    return ForgeRepo(
      host: uri.host,
      owner: owner,
      repo: repo,
      issueNumber: number,
      issueUrl: uri.toString(),
    );
  }

  @override
  Future<ForgeFetchResult> fetchIssue(
    ForgeRepo repo, {
    ForgeHttpClient? client,
  }) async {
    final http = client ?? RealForgeHttpClient();
    try {
      final response =
          await http.get(repo.issueUrl, headers: {'Accept': 'text/html'});
      if (response.statusCode == 404) {
        return ForgeFetchResult.fail(
          'Issue page not found at ${repo.issueUrl}.',
        );
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        return ForgeFetchResult.fail(
          'The host refused anonymous access (${response.statusCode}). '
          'Private issues on this forge need a dedicated adapter — '
          'no generic fallback can authenticate.',
        );
      }
      if (response.statusCode != 200) {
        return ForgeFetchResult.fail(
          'Fetching ${repo.issueUrl} returned HTTP ${response.statusCode}.',
        );
      }

      final title = _extractTitle(response.body);
      final body = _extractBody(response.body);
      if (title == null && body == null) {
        return ForgeFetchResult.fail(
          'Could not extract issue content from ${repo.issueUrl}. The page '
          'may be JavaScript-rendered — a dedicated adapter is needed.',
        );
      }

      return ForgeFetchResult.ok(ForgeIssue(
        host: repo.host,
        owner: repo.owner,
        repo: repo.repo,
        number: repo.number,
        title: title ?? 'Issue #${repo.number}',
        body: body ?? '',
        state: 'unknown',
        labels: const [],
        comments: const [],
        url: repo.issueUrl,
      ));
    } on ForgeHttpException catch (e) {
      return ForgeFetchResult.fail(
          'Could not reach ${repo.host}: ${e.message}');
    }
  }

  /// <title>…</title> — forges put "Issue title · repo · host" here.
  static String? _extractTitle(String html) {
    final m = RegExp(
      r'<title[^>]*>(.*?)</title>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html);
    if (m == null) return null;
    var title = _stripTags(m.group(1)!);
    // Trim trailing site decorations: " · Owner/Repo · Host"
    final sep = title.indexOf(' · ');
    if (sep > 0) title = title.substring(0, sep);
    return title.trim().isEmpty ? null : title.trim();
  }

  /// The issue body: first substantial markdown-rendered block. Coarse —
  /// matches the common `issue-body`/`comment-body` class conventions.
  static String? _extractBody(String html) {
    final m = RegExp(
      r'class="[^"]*(?:issue|comment|ticket)[^"]*body[^"]*"[^>]*>(.*?)(?=</div>)',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html);
    if (m == null) return null;
    final body = _stripTags(m.group(1)!).trim();
    return body.isEmpty ? null : body;
  }

  static String _stripTags(String html) => html
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  @override
  Future<String?> defaultBranch(
    ForgeRepo repo, {
    ForgeHttpClient? client,
  }) async =>
      null; // cannot know without a dedicated adapter; caller falls back
}
