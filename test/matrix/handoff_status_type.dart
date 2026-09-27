// handoff_status_type.dart — HandoffStatus variants as dartrix AppType
//
// Wraps HandoffStatus (lib/session/session_state.dart) as AppType so the
// matrix can derive coverage obligations per status, without lib/ itself
// ever importing dartrix (lib/'s zero-dartrix-import contract is documented
// in tool/claudart_lints/lib/claudart_lints.dart — this file is the
// test-only mirror that keeps that contract intact).
//
// features here mirrors HandoffStatus.expectsSuggest/.expectsDebug exactly —
// if those change, this file's groupings must be updated to match.

import 'package:dartrix/dartrix.dart';

import 'handoff_expectation.dart';

enum HandoffStatusType implements AppType {
  suggestInvestigating(
    description: 'suggest-investigating — mid-exploration, no root cause yet',
    features: {HandoffExpectation.suggest},
  ),
  readyForSuggest(
    description: 'ready-for-suggest — debug left a question for suggest',
    features: {HandoffExpectation.suggest},
  ),
  readyForDebug(
    description: 'ready-for-debug — root cause confirmed, implementation next',
    features: {HandoffExpectation.debug},
  ),
  debugInProgress(
    description: 'debug-in-progress — implementation started, not resolved',
    features: {HandoffExpectation.debug},
  ),
  debugComplete(
    description: 'debug-complete — fix verified, ready for teardown',
    features: {},
  ),
  needsSuggest(
    description: 'needs-suggest — debug hit a question only suggest can answer',
    features: {HandoffExpectation.suggest},
  ),
  noHandoff(
    description: 'no-handoff — zedup-local: no project or handoff file',
    features: {HandoffExpectation.suggest},
  ),
  unknown(
    description: 'unknown — unrecognised status string',
    features: {HandoffExpectation.suggest},
  );

  const HandoffStatusType({required this.description, required this.features});

  @override
  final String description;

  @override
  final Set<HandoffExpectation> features;
}
