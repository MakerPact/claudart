// forge_adapter.dart — pluggable interface for code-forge issue fetching
// (PLAN.md Phase 14)
//
// A "forge" is any site hosting git repos with an issue tracker: GitHub,
// GitLab, Bitbucket, Forgejo/Gitea/Codeberg, … Each gets an adapter
// implementing this interface. The `issue` command layer never talks to a
// specific host directly — it resolves an adapter from the URL and works
// against [ForgeIssue] / [ForgeRepo] values only.
//
// Adding a new host = one new adapter class + one entry in
// `ForgeRegistry.builtin` (forge_registry.dart). No command-layer changes
// (exhaustive switches elsewhere are unaffected — this is a class
// registry, not an enum).

import 'dart:convert';
import 'dart:io';

/// A fetched issue: everything the handoff needs, host-agnostic.
class ForgeIssue {
  final String host; // e.g. 'github.com'
  final String owner; // e.g. 'arduino'
  final String repo; // e.g. 'Arduino'
  final int number; // e.g. 12036
  final String title;
  final String body;
  final String state; // 'open' | 'closed' | 'all' — raw host value
  final List<String> labels;
  final List<String> comments; // rendered comment bodies, in order
  final String url; // canonical issue URL

  const ForgeIssue({
    required this.host,
    required this.owner,
    required this.repo,
    required this.number,
    required this.title,
    required this.body,
    required this.state,
    required this.labels,
    required this.comments,
    required this.url,
  });
}

/// A resolved repo reference parsed from an issue URL — produced before
/// any network call, so URL parsing is testable without HTTP.
class ForgeRepo {
  final String host; // e.g. 'github.com' or 'gitlab.example.com'
  final String owner;
  final String repo;
  final int issueNumber;
  final String issueUrl;

  const ForgeRepo({
    required this.host,
    required this.owner,
    required this.repo,
    required this.issueNumber,
    required this.issueUrl,
  });

  /// `owner/repo` — the common display and clone-path form.
  String get slug => '$owner/$repo';

  /// Convenience alias — the issue number this repo ref came from.
  int get number => issueNumber;
}

/// Result of an issue fetch. [issue] is null on failure with [error]
/// carrying a user-actionable message (auth guidance for 401/404, host
/// unreachable, etc.) — never a raw exception across this boundary.
class ForgeFetchResult {
  final ForgeIssue? issue;
  final String? error;

  const ForgeFetchResult.ok(this.issue) : error = null;
  const ForgeFetchResult.fail(this.error) : issue = null;

  bool get ok => issue != null;
}

/// Fetches issues from one forge family. One implementation per host
/// family; self-hosted variants (GitHub Enterprise, self-hosted GitLab)
/// are handled by the same adapter via the URL's host.
abstract class ForgeAdapter {
  /// Wire name for diagnostics, e.g. 'github'.
  String get name;

  /// True when this adapter handles [host]. Must be cheap and pure —
  /// called during URL routing before any network I/O.
  bool handlesHost(String host);

  /// Parses an issue URL into a [ForgeRepo]. Returns null when the URL
  /// is not an issue URL this adapter recognizes (wrong path shape,
  /// non-numeric issue number, …).
  ForgeRepo? parseIssueUrl(Uri uri);

  /// Fetches the issue at [repo] (already parsed). Network call —
  /// inject the [client] in tests; production passes the real one.
  Future<ForgeFetchResult> fetchIssue(
    ForgeRepo repo, {
    ForgeHttpClient? client,
  });

  /// The default branch name for [repo], or null when it cannot be
  /// determined (network failure, private repo without credentials).
  /// Used to base the bug-fix branch on the forge's actual default
  /// branch rather than assuming `main`.
  Future<String?> defaultBranch(
    ForgeRepo repo, {
    ForgeHttpClient? client,
  });

  /// HTTPS clone URL for [repo].
  String cloneUrl(ForgeRepo repo) =>
      'https://$host/${repo.owner}/${repo.repo}.git';

  /// The host this adapter's [cloneUrl] builds URLs against — for the
  /// GitHub adapter that's always `github.com` even when the issue URL
  /// was an enterprise host, so clones go to the public forge unless the
  /// enterprise host is explicitly the origin. Subclasses override when
  /// the URL host is the clone host.
  String get host;
}

/// Minimal HTTP surface the adapters need. `dart:io`'s HttpClient is
/// wrapped behind this so tests inject canned responses without sockets.
abstract class ForgeHttpClient {
  /// GETs [url] with [headers]. Returns the decoded body and status code.
  /// Throws [ForgeHttpException] on network-level failure (DNS, refused
  /// connection, timeout) — HTTP error statuses (404, 401, …) are
  /// returned, not thrown, so adapters can branch on them.
  Future<ForgeHttpResponse> get(String url, {Map<String, String>? headers});
}

class ForgeHttpResponse {
  final int statusCode;
  final String body;

  const ForgeHttpResponse(this.statusCode, this.body);
}

class ForgeHttpException implements Exception {
  final String message;
  const ForgeHttpException(this.message);

  @override
  String toString() => 'ForgeHttpException: $message';
}

/// Production HTTP client backed by `dart:io` HttpClient.
class RealForgeHttpClient implements ForgeHttpClient {
  static final HttpClient _http = HttpClient();

  @override
  Future<ForgeHttpResponse> get(String url,
      {Map<String, String>? headers}) async {
    final uri = Uri.parse(url);
    final request = await _http.getUrl(uri);
    headers?.forEach((k, v) => request.headers.set(k, v));
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    return ForgeHttpResponse(response.statusCode, body);
  }
}
