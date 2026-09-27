# agentFlow design review — Fable system prompt

> PLAN.md Phase 12. Run this as a live inspection pass, not a document to file
> away. Model: `AgentModel.fable` (`claude-fable-5-1`) — routed here because
> `IntentClass.design` maps to it in `categorization.dart`'s `routeModel`;
> this is exactly the specialization it's for.
>
> Update (2026-09-27): `routeModel`'s design branch now routes to `opus`
> instead, after comparing output quality directly. The review this prompt
> produced already ran under the `fable` routing above and its findings
> stand — a future re-run of this same prompt would use `opus`.

---

## System prompt (verbatim — hand this to the Fable session)

You are reviewing the **agentFlow** surface across two repositories:
claudart (the CLI pipeline engine) and zedup (the TUI that visualizes it).
"agentFlow" means the whole path from a pipeline step running to a human
seeing it happen: claudart's typed event/response model, and zedup's live
rendering of that model.

**Read first, in this order, before touching any agentFlow file.** This is
the project's own knowledge base — skipping it produces recommendations
that re-litigate settled decisions or invent conventions that already exist
under a different name.

1. `/Users/aksana.buster/dev/apps/claudart/PLAN.md` — Phase 11 (what just
   shipped) and Phase 12 (this task's own charter) especially.
2. `/Users/aksana.buster/dev/apps/dartrix/PARADIGMS.md` — the design law.
   Every finding you report must cite which dimension it violates
   (`architecture`, `consts`, `testing`, `comments`, etc.) or say plainly
   that it's a new case PARADIGMS doesn't cover yet.
3. `/Users/aksana.buster/dev/dev_tools/claude/claudart/skills.md` — accumulated
   Root Cause Patterns. Don't re-surface a problem already fixed here.
4. `/Users/aksana.buster/dev/apps/claudart/docs/design.md` — the session-state
   FSA. Not agentFlow itself, but the sibling formal-design doc whose style
   (theory → rule → example, table-first) your own report should match.
5. `/Users/aksana.buster/dev/apps/claudart/docs/agent_response_and_output.md`
   — the `AgentResponse` design doc. This IS agentFlow's data model spec;
   read it fully before opening the code.

**Then inspect these files** — the complete agentFlow surface, nothing
outside it:

*claudart (the model + engine):*
- `lib/pipeline/agent_flow.dart` — the `AgentFlow` enum, one variant per
  session-lifecycle flow.
- `lib/pipeline/agent_response.dart` — the sealed `AgentResponse` hierarchy
  (`Plan`/`Progress`/`Question`/`Action`/`Result`/`Blocker`/`Handoff`/`Replan`).
- `lib/pipeline/event_response_map.dart` — `toResponse()`, the bridge from
  `PipelineEvent` to `AgentResponse`. Only 3 of 7 variants are reachable
  today (`AgentCompleted`→`Result`, `AgentFailed`→`Blocker`,
  `AgentEscalating`→`Question`) — confirm this is still true, and confirm
  whether it should be.
- `lib/pipeline/pipeline_event.dart`, `lib/pipeline/step_status.dart` — the
  underlying event/status types agentFlow is built on.

*zedup (the TUI consumer):*
- `lib/src/features/dashboard/agent_flow_session.dart` — shared app-level
  `AgentsWorkflowState` holder.
- `lib/src/features/dashboard/agent_flow_diagram.dart` — the per-step flow
  list widget.
- `lib/src/features/dashboard/agent_flow_band.dart` — the fixed-row live
  pipeline band on the dashboard grid.
- `lib/src/features/dashboard/agent_flow_poller.dart` — how live state gets
  polled into the session.
- `lib/src/features/chat/agents_workflow_pane.dart` — `AgentSlot`,
  `AgentsWorkflowState.handleEvent()`, the chat-screen rendering of the
  same pipeline.
- `lib/src/features/chat/agent_flow_ext.dart` — TUI-layer extensions on
  `AgentFlow` (label, isCli).

## What to evaluate

For each dimension, answer with evidence (file:line), not impression:

1. **Enum-first correctness** — every state this surface can be in
   (question pending, revisit, escalation, blocked, done) should trace to
   an enum variant or a getter on one. Flag any place a `bool`/`String`
   flag combination is standing in for what should be a variant.
2. **Exhaustiveness and the reachability gap** — `toResponse()` only
   produces 3 of 7 `AgentResponse` variants. Is that gap correctly load-
   bearing (the other 4 genuinely need a multi-subagent orchestrator that
   doesn't exist yet, per `docs/agent_response_and_output.md`), or has the
   orchestrator's reality moved since that doc was written?
3. **CLI/TUI duplication** — does zedup re-derive anything from raw
   `PipelineEvent`s that claudart's own `AgentResponse`/`StepStatusFromEvent`
   already computes? (Precedent: `StepStatusFromEvent.fromEvent` was added
   specifically to kill one instance of this — check whether new
   duplication crept back in.)
4. **Token cost of the live surface** — `AgentFlowPoller` and
   `AgentFlowSession` run continuously while a session is open. Is polling
   frequency, payload size, or re-render scope larger than the information
   actually changing? This is a design/perf review question as much as a
   correctness one — minimizing token/compute cost here compounds every
   session.
5. **Folder structure** — `agent_flow_*.dart` is split across
   `features/dashboard/` (4 files) and `features/chat/` (1 file,
   `agent_flow_ext.dart`). Is that split defensible (dashboard vs. chat
   are genuinely different consumers) or should `agent_flow_ext.dart` move
   to sit with its siblings?
6. **The stacked-layout gap** — a prior session's research memory
   (`project_agentflow_pane_research.md`) called for a stacked layout
   (plan steps above, live output below) as the target design; the
   current implementation keeps the pre-existing split-pane layout with
   typed cards inside it. Given the user's own stated direction (TUI
   needs more mouse-click interactivity), does the stacked layout still
   make sense, or has the target design itself moved?

## Constraints

- **Read-only. Report findings — do not edit code.** This is Phase 12's
  ad hoc inspection pass, not Phase 5's build-out.
- **Token-conscious**: read the files listed above; do not additionally
  grep/glob-explore the wider repo unless a specific finding requires
  confirming a claim (e.g., "is this really the only caller"). Prefer one
  targeted check over a broad sweep.
- Cite dartrix's actual PARADIGMS.md dimension for every architecture
  finding — a generic "this could be cleaner" is not a finding.
- Distinguish clearly between "this is wrong today" and "this was a
  correct decision that a later change (mouse-click interactivity) may
  now supersede" — the second category needs a recommendation, not a bug
  report.

## Deliverable

A structured concerns report: one entry per finding, each with
`file:line`, the specific dimension/doc it checks against, and a
recommendation. Rank by what would most reduce future token cost or
prevent a future regression — not by what's easiest to fix.
