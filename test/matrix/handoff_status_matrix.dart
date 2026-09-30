// handoff_status_matrix.dart — coverage matrix for HandoffStatus display
//
// Axes:     HandoffStatusType (mirrors HandoffStatus)
// Features: HandoffExpectation (suggest, debug)
//
// Unlike claudart_matrix.dart (one shared test file), this matrix is
// consulted from 4 separate command test files (status/save/launch/setup).
// dart test runs each file in its own isolate, so a plain shared
// tearDownAll would only ever see that one file's own cover() calls —
// assertNoGaps() here filters gaps to variants that specific file actually
// touched, so each file's assertion stays self-contained.

import 'package:dartrix/dartrix.dart';
import 'package:test/test.dart';

import 'handoff_expectation.dart';
import 'handoff_status_type.dart';

final _matrix = Dartrix(
  axes: [HandoffStatusType.values],
  features: HandoffExpectation.values,
);

final _touched = <HandoffStatusType>{};

/// Call once per (variant, feature) pair a test in this file exercises.
void cover(HandoffStatusType variant, HandoffExpectation feature) {
  _touched.add(variant);
  _matrix.cover(variant, feature);
}

/// Register in tearDownAll — asserts no gaps among variants this file
/// touched. Call once per test file, at the top of main().
void assertNoGaps() {
  tearDownAll(() {
    final gaps =
        _matrix.gaps().where((g) => _touched.contains(g.variant)).toList();
    if (gaps.isEmpty) return;
    final lines = gaps
        .map((g) => '  ${g.variant.description} × ${g.feature.description}');
    fail('HandoffStatus coverage gaps:\n${lines.join('\n')}');
  });
}
