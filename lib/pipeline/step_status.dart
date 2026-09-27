// step_status.dart — UI-facing lifecycle state of a single pipeline step
//
// Not produced by PipelineExecutor directly — the executor's real
// lifecycle model is the sealed PipelineEvent hierarchy (pipeline_event.dart).
// StepStatus is a derived projection of that stream for consumers that want
// a per-step display state (spinner glyph, colour) rather than the full
// event. `StepStatusFromEvent.fromEvent` is the one canonical, tested
// projection — consumers should use it instead of re-deriving their own
// mapping. (Called via the extension's own name, not `StepStatus.fromEvent`
// — a static extension member is namespaced under the extension, not the
// extended type.)
//
// `waiting` added 2026-09-27: AgentEscalating/AgentResumed now carry a
// stepId (previously session-level events with no per-step identity), so
// they drive a real status transition instead of leaving the active
// step's displayed status untouched. Five events identify a single step
// now, not three.

import 'pipeline_event.dart';

enum StepStatus { pending, running, waiting, done, failed }

extension StepStatusFromEvent on StepStatus {
  /// Projects a [PipelineEvent] onto a [StepStatus], or `null` when the
  /// event carries no per-step status change of its own — the caller
  /// should keep whatever status it already had. Only events that
  /// identify a single step (`stepId`) drive a status transition; the
  /// flow-command approval gate and pipeline completion are session-level
  /// and leave the active step's displayed status untouched.
  static StepStatus? fromEvent(PipelineEvent event) => switch (event) {
        AgentStarted() || AgentResumed() => StepStatus.running,
        AgentCompleted() => StepStatus.done,
        AgentFailed() => StepStatus.failed,
        AgentEscalating() => StepStatus.waiting,
        PlanDraft() ||
        AwaitingApproval() ||
        PipelineCompleted() =>
          null,
      };
}
