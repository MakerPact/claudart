# claudart — Session Log

> Running record of design decisions, cleanups, and known issues.
> Updated manually at the end of each significant work session.

---

## 2026-09-22 — PR #46 merged: StepResult metadata, headless teardown, README rewrite, plus 5 audit follow-ups

### What this session did

Closed out an earlier codebase audit's 5 remaining actionable follow-ups, then
pushed 4 rounds of fixes against PR #46 in response to Copilot's actual
re-reviews (not assumed-resolved), then merged. Every fix ran through
claudart's own self-hosting workflow — `setup`/confirmed-KT → `save` →
implement → `dart analyze`/`custom_lint`/`test` → real `teardown` — closing
the self-hosting loop each time, per the standing law this project holds
itself to.

### Audit follow-ups (5 items, item 2 skipped)

1. **`tool/claudart_lints` analyzer strictness** — added its own
   `analysis_options.yaml` matching the root workspace's shape (minus the
   circular `custom_lint` self-reference), fixed 3 `deprecated_member_use`
   warnings (`ErrorReporter` → `DiagnosticReporter`, analyzer 8.x's rename).
2. **Dead `ModelTier` methods — skipped.** The audit's premise ("zero call
   sites") was wrong: zedup's own `test/features/chat/claudart_model_test.dart`
   imports `AgentModel` from `package:claudart/claudart.dart` and exercises
   `bestForLookup`/`bestForAnalysis`/`bestForExplore` directly. Deleting them
   would have broken zedup's test suite. No change made.
3. **Branch-display bug cluster** — `kill.dart`, `rotate.dart`, `save.dart`,
   `setup.dart` all displayed the handoff's stale `state.branch` instead of
   the live `detectGitContext()` branch, same bug already fixed once in
   `status.dart`/`launch.dart`. Fixed all 4, one regression test each.
4. **`ClaudartSurface`/`SurfaceExecutorConfig` test coverage** — zero tests
   despite being real, zedup-consumed public API. Added 8 tests covering both
   surfaces' declaration, build success, and runner/strict wiring — each
   printing its observed value so `dart test` output reads as a per-case
   report, not silent pass/fail.
5. **`workspace/workspace_config.dart` test coverage** — `StackType`,
   `WorkspaceRole`, `ProofNotation`, `WorkspaceConfig` (distinct from the
   already-tested, unrelated `lib/config.dart` class of the same name) had
   zero tests. Added 22, enum-owned loop generating one `test()` per
   `StackType` variant (loop wraps `test()`, not inside it) plus
   `WorkspaceConfig.load()` coverage for missing-file/malformed-json/
   defaults/silent-drop paths.

### PR #46 review rounds (4 rounds, post the audit follow-ups)

Copilot's reviews were verified against the actual code each round, not
trusted at face value — one finding ("unused analyzer error listener import"
in `claudart_lints.dart`) was checked twice by actually removing the import
and confirming `dart analyze` broke with `undefined_class DiagnosticReporter`
— a confirmed false positive, left open on GitHub with an explanation rather
than silently resolved.

Real findings fixed:
- Headless teardown's hot-files sentinel (`'unspecified'`) was written into
  `skills.md` as if it were a real file.
- The new stream-to-metadata parsing (`_accumulateThinking`) had no test
  seam — extracted `consumeClaudeStream` so it's testable without spawning a
  real `claude` subprocess.
- **HIGH severity**: `_accumulateThinking`'s `jsonDecode(line) as
  Map<String, dynamic>` cast threw an uncaught `TypeError` (not the
  `FormatException` the try/catch anticipated) on valid-but-non-object JSON
  at any nested level. Guarded every object/string access through
  `_asJsonMap`/`_asJsonString` helpers instead. Verified the fix was real by
  reverting it locally and confirming the regression test failed with
  exactly the predicted error before restoring.
- `step_status.dart`'s doc comment showed `StepStatus.fromEvent` as the call
  syntax; `fromEvent` is a static member of the `StepStatusFromEvent`
  extension, so that line doesn't compile. Compiler-probed to confirm,
  corrected the doc comment.
- Extracted `parseClaudeResultLine` out of `defaultClaudeRunner` so
  `stop_reason`/`duration_ms`/`num_turns` extraction is directly testable —
  closed the remaining half of the stream-metadata coverage gap.
- Added an executor-level test asserting `AgentCompleted` actually forwards
  `StepResult`'s metadata fields, not just that the parsing helpers produce
  them correctly in isolation.
- `teardown.dart`'s headless mode printed a "Headless decisions" summary
  before archiving a *resolved* fix, but the non-resolved reminder path
  wrote its archive entry with no equivalent summary — a write with no
  human prompt and no visible confirmation. Added a matching summary print.
- Manually reviewed the full PR diff (standing in for Copilot while it hit a
  quota limit) and found two more real, pre-existing README issues: the
  "Full command table"'s `bin/claudart.dart` line citations were wrong from
  the commit that wrote them (traced to `880866e`), and `teardown --headless`
  was never documented anywhere. Fixed both.
- 5 of 6 GitHub review threads marked resolved with commit citations; the
  1 false positive left open with its verification method attached.

### Merge

PR #46 merged as `e75ba27` (14 commits, `main` fast-forwarded, feature branch
deleted locally and remotely). `claudart compile` re-run afterward — the
installed `~/bin/claudart` binary had gone stale mid-session once already
(its `save`/`teardown` output still showed `Branch : unknown` after the
branch-display fix landed in source, until recompiled), which is itself a
live demonstration of the self-hosting law: claudart caught its own bug via
its own workflow output, not via a separate check.

### Test coverage summary

| Area | Tests |
|------|-------|
| (unchanged from 2026-03-18 baseline — not re-broken out per-area this entry) | — |
| `claudart_surface_test.dart` (new) | 8 |
| `workspace_config_test.dart` (new) | 22 |
| `pipeline_executor_test.dart` (stream/result-line/forwarding additions) | +10 |
| `step_status_test.dart` | 5 |
| `kill_test.dart`/`rotate_test.dart`/`save_test.dart`/`setup_test.dart` (branch-display regression tests) | +4 |
| `teardown_test.dart` (headless-summary regression test) | +1 |
| **Total** | **1047 passing** (11 pre-existing, unrelated `test/ui/render*.dart` ANSI failures — environment-dependent, not this session's code) |

> **As of 2026-09-22:** 1047 passing / 1058 total. Was 449 at the 2026-03-18
> entry — six merged PRs' worth of growth in between, only some of which
> (this entry) got a session-log write-up.

### Commit at end of session

```
e75ba27 Merge pull request #46 from liitx/feature/step-result-metadata
```

---

## 2026-03-18 — Audit: enum-first enforcement, matrix completion, test depth, fixture namespace sweep

### What this session did

**Full compliance audit against the laws captured in the design session experiment.**
The reasoning mode was working. The tests were not yet verifying it. That gap is closed.

### Enforcement work

**`ClaudartOperation` enum — enum-first law applied to `sync_check.dart`:**

`checkHandoffStatus` previously accepted a bare `String` and switched on
`'debug'` / `'save'` / `'test'` literals. Replaced with an exhaustive enum:

```dart
enum ClaudartOperation {
  debug, save, test;
  static ClaudartOperation fromString(String s) => switch (s) {
    'debug' => debug,
    'save'  => save,
    _       => test,
  };
}
```

Parse-once at boundary: `preflight_cmd.dart` calls `fromString` once on the CLI
arg; the enum passes through the entire call chain. No bare string comparisons
inside the library.

**Typed catches — `session_ops.dart`:**

Three `closeSession` rollback steps had bare `catch (e)`. Replaced with
`on Exception catch (e)`. Dart's typed catch rule: `Error` subclasses are
programmer mistakes that should propagate, not be swallowed.

**`TeardownCategory.label` — matrix completion:**

Enum test matrix M(E) = V × G. `TeardownCategory` has 8 variants × 3 getters
(`area`, `value`, `label`) = 24 required cells. The `label` getter was only
tested for `other` (1/8 cells). Added 7 missing assertions to complete the matrix.

**`incrementHotPath` area fix:**

Test used `'bloc'` as the area argument — not a real `TeardownCategory.area`
value. Changed to `'state'` (correct `stateManagement.area`).

### `knowledge_templates_test.dart` — mathematical content verification

The design session (`experiments/2026-03-17-reasoning-design-session.md`)
produced templates embedding formal math. Tests only checked heading presence —
the math itself was untested. Full rewrite:

| Template | What is now tested |
|---|---|
| `codeTemplate` | Theory/Rule/Example layer presence; O(n×k) parse-once proof; compile-time security rationale; enum capability table; enum-vs-sealed-vs-record-vs-extension-type table |
| `dartTemplate` | O(1)/O(log n) complexity in collection table; `const Set` lookup rule; `enum.values × getters` formula; isolate decision table; sealed class vs enum |
| `testingTemplate` | `T ⊇ C` set notation; `Gap = T − C`; `gap = ∅` session-done condition; `enum.values × getters`; `Every cell must have an assertion`; FileIO/confirmFn/exitFn injectable table; `randomize-ordering-seed` rule |
| `claudeMdTemplate` | Verify-before-commit workflow; `Never push to remote` git rule; `## Environment` section with SDK/Flutter constraints |

### Fixture namespace sweep

All project-specific class and domain names removed from source, tests, READMEs,
and git commit history. Replaced with fictional Buster/Rover/Pilot namespace
throughout test fixtures. History rewrite across all branches, gc run.

### Test count

| Session | Tests |
|---|---|
| 2026-03-17 | 375 |
| 2026-03-18 | 449 |

### Commits this session

```
5fdb1c6 test: expand knowledge_templates to verify mathematical content
9d2b4e5 fix: enum-first and matrix compliance
fe9f529 merge: refactor/audit — audit, Buster fixtures, rotate, typed catches, 413 tests
309a044 refactor: replace project-specific fixture names with Buster/Rover namespace
9b45855 refactor: audit — typed catches, falsifiable tests, setup coverage, generic fixture cleanup
```

---

## 2026-03-17 — Framework-agnostic cleanup + line editor + teardown improvements

### What claudart is

A generic Dart CLI that manages a structured suggest → debug → teardown workflow
for AI-assisted debugging sessions. It is not Flutter-specific. It runs on any
Dart project.

The workflow:

```
claudart link          — register project in workspace registry
claudart setup         — describe the bug; writes handoff.md
  ↓
/suggest               — AI explores the codebase, writes root cause to handoff
claudart save          — checkpoint confirmed root cause to skills.md (Pending)
  ↓
/debug                 — AI implements the fix, scoped to handoff
  ↓
claudart teardown      — classify session, archive handoff, update skills.md, suggest commit
```

### Commands (as of this session)

| Command               | What it does |
|-----------------------|--------------|
| `claudart`            | Interactive launcher — list projects, route into setup |
| `claudart init`       | Scaffold workspace: dart.md, testing.md, slash commands |
| `claudart init -p X`  | Add project knowledge file |
| `claudart link [name]`| Register project; write CLAUDE.md with workspace refs |
| `claudart unlink`     | Remove symlinks |
| `claudart setup`      | Prompt for bug context; write handoff.md |
| `claudart status`     | Show active session state; `--prompt` for shell RPROMPT |
| `claudart save`       | Snapshot handoff to archive/checkpoint_*; deposit root cause to skills.md Pending |
| `claudart teardown`   | Categorise session; archive handoff; update skills.md; suggest commit |
| `claudart kill`       | Abandon session without skills update |
| `claudart preflight`  | Sync check before debug/save/test |
| `claudart scan`       | Re-scan project for sensitive tokens |
| `claudart report`     | Diagnostic report |
| `claudart map`        | Generate token_map.md from token_map.json |
| `claudart experiment` | Run command and tee output to experiments/ |

### Files written by the workflow

```
~/.claudart/                        ← CLAUDART_WORKSPACE (global root, v2)
  registry.json                     ← maps project roots to workspace paths
  <project-name>/
    handoff.md                      ← live session state (suggest ↔ debug)
    skills.md                       ← accumulated cross-session learnings
    archive/
      checkpoint_<branch>_<ts>.md  ← save snapshots
      handoff_<branch>_<ts>.md     ← teardown archives
    knowledge/
      generic/
        dart.md                     ← generic Dart practices
        testing.md                  ← generic testing practices
      projects/
        <name>.md                   ← project-specific context
    commands/                       ← Claude Code slash commands
      suggest.md
      debug.md
      save.md
      teardown.md
    logs/
    token_map.json / token_map.md
```

### What was cleaned up this session

**Flutter/BLoC context removed from the generic CLI:**

Previously, claudart had hardcoded Flutter-specific assumptions throughout:
- `handoff_template.dart` had a `### BLoCs / providers in play` section
- `setup.dart` stored the answer in a `blocs` variable
- `teardown.dart` had Flutter-specific categories: `bloc-event-handling`,
  `widget-lifecycle`, `provider-state`, `ffi-bridge`
- `teardown_utils.dart` mapped categories to commit areas using BLoC/widget/ffi terms
- `suggest_template.dart` and `debug_template.dart` told the AI to read `bloc.md`
  and `riverpod.md` and traced `API → repository → BLoC/provider → widget`
- `knowledge_templates.dart` contained `blocTemplate` and `riverpodTemplate`
- `init.dart` wrote `bloc.md` and `riverpod.md` to the workspace on init

**Root cause:** These were claudart-specific assumptions carried over from the
original claudart workflow and never genericised.

**What replaced them:**
- Handoff section: `### Key entry points in play`
- Setup variable: `entryPoints`
- Teardown categories: `api-integration`, `concurrency`, `configuration`,
  `data-parsing`, `io-filesystem`, `state-management`, `general`, `other`
- `TeardownCategory` constants: `apiIntegration`, `concurrency`, `configuration`,
  `dataParsing`, `ioFilesystem`, `stateManagement`, `general`, `other`
- `areaFromCategory()`: maps to `api`, `async`, `config`, `io`, `state`, `data`, `fix`
- Knowledge starters: `dart.md` + `testing.md` only (no framework assumptions)
- Templates: generic data flow language; no framework-specific file references

**Note:** The scanner (`lib/scanner/`) and sensitivity modules (`lib/sensitivity/`)
still detect BLoC/Riverpod patterns — this is correct. Those modules scan
*target* project code, not claudart itself.

### Other improvements this session

- **Line editor** (`lib/ui/line_editor.dart`): raw-mode mini readline for all
  text prompts — left/right arrows, home/end, backspace, delete, Ctrl+A/E/U
- **Teardown pre-population**: hot files pre-filled from "What changed"; root
  cause pattern pre-filled from handoff Root Cause section
- **Arrow-key category menu**: teardown category selection uses `arrowMenu`
  instead of free-text entry
- **`TeardownCategory` named constants**: replaces magic indices in tests
- **Legacy path migration** (scan + logger): `scan.dart` and `logger.dart` now
  resolve paths per-project via `workspacePath` instead of the global `claudeDir`
- **21 unit tests** for teardown + **3 e2e smoke tests** (save → teardown pipeline)

### Known issues / open questions

1. **`setup` has no unit tests** — highest-priority coverage gap. Setup is the
   most complex command (prompts, handoff write, scan, logging) and has zero test
   coverage. Drift is likely here.

2. **`init` still detects Flutter version** — removed from template generation but
   `_detectVersion('flutter', ...)` call can be removed entirely since `claudeMdTemplate`
   accepts `flutterConstraint` as an optional param (used when target project is Flutter).

3. **skills.md Pending section** — the current `skills.md` in the self-hosted
   workspace has a malformed Pending entry (from a prior session where the category
   leaked). Review and clean manually if needed.

4. **`claudart scan` standalone** — resolves workspace from registry correctly now
   but has no dedicated test for the standalone binary path.

5. **Category selection is fixed-length** — if a user wants a project-specific
   category not in the list, they must pick `other (type manually)`. A future
   improvement: derive additional options from existing skills.md Root Cause Patterns.

### Test coverage summary

| Area                        | Tests |
|-----------------------------|-------|
| Registry                    | ✓     |
| HandoffTemplate             | ✓     |
| KnowledgeTemplates          | ✓     |
| TeardownUtils               | ✓     |
| SessionState                | ✓     |
| SyncCheck                   | ✓     |
| WorkspaceGuard              | ✓     |
| Link                        | ✓ 16  |
| Save                        | ✓     |
| Teardown                    | ✓ 21  |
| Kill                        | ✓     |
| Status                      | ✓     |
| Launch                      | ✓     |
| Preflight                   | ✓     |
| Scan                        | ✓     |
| E2E (save → teardown)       | ✓ 3   |
| **Setup**                   | ✗ 0   |
| README sync                 | ✓     |
| Total                       | 375   |

> **As of 2026-03-18:** 449 tests. See session entry above for what was added.

### Commit at end of session

```
ebcf12f fix: remove Flutter/BLoC context — claudart is framework-agnostic
```
