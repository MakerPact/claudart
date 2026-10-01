// forge_registry.dart — host → adapter resolution (Phase 14)

import 'forge_adapter.dart';
import 'forgejo_adapter.dart';
import 'gitee_adapter.dart';
import 'github_adapter.dart';
import 'gitlab_adapter.dart';
import 'scrape_fallback.dart';

/// Resolves a host to the adapter that handles it. Order matters: the
/// scrape fallback claims *every* host, so it must be consulted last.
class ForgeRegistry {
  final List<ForgeAdapter> _adapters;

  ForgeRegistry(this._adapters);

  /// All builtin adapters, in resolution order. The scrape fallback is
  /// appended last so known hosts always resolve to their real adapter.
  factory ForgeRegistry.builtin() => ForgeRegistry([
        GithubAdapter(),
        GitlabAdapter(),
        ForgejoAdapter(),
        GiteeAdapter(),
        ScrapeFallbackAdapter(),
      ]);

  /// The adapter for [host], or null when no adapter claims it.
  /// (Builtin registry never returns null — the fallback claims all.)
  ForgeAdapter? forHost(String host) {
    for (final adapter in _adapters) {
      if (adapter.handlesHost(host)) return adapter;
    }
    return null;
  }
}
