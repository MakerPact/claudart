import 'package:claudart/sensitivity/abstractor.dart';
import 'package:claudart/sensitivity/token_map.dart';
import 'package:claudart/sensitivity/detector.dart';

void main() {
  final abstractor = Abstractor();
  final map = TokenMap();

  // Let's generate a large string and a large number of sensitive tokens
  final buffer = StringBuffer();
  final sensitive = <String>[];

  for (int i = 0; i < 1000; i++) {
    final token = 'SecretToken$i';
    sensitive.add(token);
    buffer.write('This is some text with $token and some other words. ');
  }

  final text = buffer.toString();
  final detector = _DummyDetector(sensitive);

  // Warm up
  for (int i = 0; i < 10; i++) {
    abstractor.abstract(text, map, detector);
  }

  final stopwatch = Stopwatch()..start();
  for (int i = 0; i < 100; i++) {
    abstractor.abstract(text, map, detector);
  }
  stopwatch.stop();

  print('Baseline time: ${stopwatch.elapsedMilliseconds} ms');
}

class _DummyDetector implements SensitivityDetector {
  final List<String> tokens;
  _DummyDetector(this.tokens);

  @override
  List<String> detectInText(String text) {
    return List.from(tokens);
  }

  @override
  bool isSensitive(String token) => true;
}
