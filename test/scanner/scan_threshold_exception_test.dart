import 'package:test/test.dart';
import 'package:claudart/scanner/scan_threshold_exception.dart';

void main() {
  test('ScanThresholdException properties and toString', () {
    final e = ScanThresholdException(
      filesFound: 500,
      threshold: 100,
      reason: 'Too many files',
      suggestions: ['ignore more'],
    );

    expect(e.filesFound, 500);
    expect(e.threshold, 100);
    expect(e.reason, 'Too many files');
    expect(e.suggestions, ['ignore more']);
    expect(e.toString(), 'ScanThresholdException: found 500 files (threshold 100). Too many files');
  });
}
