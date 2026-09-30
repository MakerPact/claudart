// state_hue.dart — shared state-semantic categories for pipeline responses
//
// Relocated here from zedup (2026-09-27) — claudart's own AgentResponse.hue
// field was the sole reason claudart depended on zedup as a real runtime
// dependency, reversing the documented "zedup is a consumer of claudart"
// direction. zedup still owns the nocterm-rendering half of this concept
// (a StateHueRendering extension with .color/.tickDuration lives in
// zedup/lib/src/enums/state_hue.dart, which imports and re-exports this
// enum) — this file only owns the pure semantics.

enum StateHue {
  /// Disconnected or not started. Greyed out.
  inactive,

  /// Connection established but not yet warm — initialization, linked
  /// but no session, cold start.
  loading,

  /// Warm and idle. Ready to act but currently doing nothing.
  ready,

  /// Currently running / processing.
  active,

  /// Paused intentionally — waiting on user input.
  paused,

  /// Failed terminally.
  error,

  /// Completed successfully.
  success;

  /// Short label rendered in legends and status hints.
  String get label => switch (this) {
        StateHue.inactive => 'inactive',
        StateHue.loading => 'loading',
        StateHue.ready => 'ready',
        StateHue.active => 'active',
        StateHue.paused => 'paused',
        StateHue.error => 'error',
        StateHue.success => 'success',
      };
}
