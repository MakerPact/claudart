// forgejo_adapter.dart — Forgejo / Gitea / Codeberg issue fetching (Phase 14)
//
// One adapter covers the whole family: Forgejo is a fork of Gitea, and
// both expose the same REST shape (/api/v1/...). Codeberg runs Forgejo.
// Hundreds of self-hosted instances exist, so known hosts are claimed
// directly (codeberg.org, gitea.com) and additional instances can be
// declared via the CLAUDART_FORGEJO_HOSTS env var (comma-separated).
// Hosts not claimed here still work through the scrape fallback — this
// adapter just upgrades them to structured API data.

import 'dart:convert';
import 'dart:io';
import 'forge_adapter.dart';

class ForgejoAdapter extends ForgeAdapter {
  @override
  String get name => 'forgejo';

  @override
  String get host => 'codeberg.org';

  /// Hosts this adapter claims: the two known public instances plus any
  /// user-declared self-hosted instances from CLAUDART_FORGEJO_HOSTS.
  @override
  bool handlesHost(String h) =>
      h == 'codeberg.org' ||
      h == 'www.codeberg.org' ||
      h == 'gitea.com' ||
      _customHosts().contains(h.toLowerCase());

  static List<String> _customHosts() {
    final raw = Platform.environment['CLAUDART_FORGEJO_HOSTS'] ?? '';
    return raw
        .split(',')
        .map((h) => h.trim().toLowerCase())
        .where((h) => h.isNotEmpty)
        .toList();
  }

  @override
  String cloneUrl(ForgeRepo repo) =>
      'https://${repo.host}/${repo.owner}/${repo.repo}.git';

  @override
  ForgeRepo? parseIssueUrl(Uri uri) {
    // Shape: https://codeberg.org/<owner>/<repo>/issues/<number>
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

  String _apiBase(ForgeRepo repo) => 'https://${repo.host}/api/v1';

  Map<String, String> _headers() {
    final headers = <String, String>{'Accept': 'application/json'};
    final token = Platform.environment['CLAUDART_FORGEJO_TOKEN'] ??
        Platform.environment['GITEA_TOKEN'];
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
        '${_apiBase(repo)}/repos/${repo.owner}/${repo.repo}/issues/${repo.number}',
        headers: _headers(),
      );
      if (response.statusCode == 404) {
        return ForgeFetchResult.fail(
          'Issue #${repo.number} not found on ${repo.host} (or the repo is '
          'private and no token is set). Set CLAUDART_FORGEJO_TOKEN (or '
          'GITEA_TOKEN) for private repos.',
        );
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        return ForgeFetchResult.fail(
          '${repo.host} rejected the request (${response.statusCode}). Your '
          'token may be expired or lack access to ${repo.slug}.',
        );
      }
      if (response.statusCode != 200) {
        return ForgeFetchResult.fail(
          '${repo.host} returned HTTP ${response.statusCode} fetching issue '
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

      // Comments: fetched only when present — same rationale as GitHub.
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
        // Non-fatal: the issue body alone seeds a handoff.
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
