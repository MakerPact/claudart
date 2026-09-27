// state_hue_test.dart — StateHue.label matrix.
//
// The .color/.tickDuration half of this enum is tested in zedup
// (test/enums/state_hue_test.dart) alongside its StateHueRendering
// extension — this file covers only what claudart itself owns.

import 'package:claudart/pipeline/state_hue.dart';
import 'package:test/test.dart';

void main() {
  group('StateHue.label', () {
    const expected = {
      StateHue.inactive: 'inactive',
      StateHue.loading: 'loading',
      StateHue.ready: 'ready',
      StateHue.active: 'active',
      StateHue.paused: 'paused',
      StateHue.error: 'error',
      StateHue.success: 'success',
    };

    for (final hue in StateHue.values) {
      test(hue.name, () {
        expect(hue.label, equals(expected[hue]));
      });
    }
  });
}
