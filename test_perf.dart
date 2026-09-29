import 'package:claudart/sensitivity/abstractor.dart';
import 'package:claudart/sensitivity/token_map.dart';
import 'package:claudart/sensitivity/detector.dart';

void main() {
  final map = TokenMap();

  // Create a lot of tokens to replace.
  final tokens = List.generate(500, (i) => 'SensitiveToken$i');
  final detector = _DummyDetector(tokens);

  final textBuffer = StringBuffer();
  for (int i = 0; i < 500; i++) {
    textBuffer.write('This is some text with SensitiveToken$i and other things. ');
  }
  final text = textBuffer.toString();

  // Test current version (with caching)
  final abstractor = Abstractor();
  // Warmup
  for (int i = 0; i < 5; i++) {
    abstractor.abstract(text, map, detector);
  }

  final stopwatch1 = Stopwatch()..start();
  for (int i = 0; i < 50; i++) {
    abstractor.abstract(text, map, detector);
  }
  stopwatch1.stop();

  // Test baseline version (compiling in loop)
  final baseline = BaselineAbstractor();
  for (int i = 0; i < 5; i++) {
    baseline.abstract(text, map, detector);
  }

  final stopwatch2 = Stopwatch()..start();
  for (int i = 0; i < 50; i++) {
    baseline.abstract(text, map, detector);
  }
  stopwatch2.stop();

  print('Current (cached): ${stopwatch1.elapsedMilliseconds}ms');
  print('Baseline (compiling): ${stopwatch2.elapsedMilliseconds}ms');
}

class BaselineAbstractor extends Abstractor {
  @override
  String abstract(String text, TokenMap map, SensitivityDetector detector) {
    final sensitive = detector.detectInText(text);
    if (sensitive.isEmpty) return text;

    sensitive.sort((a, b) => b.length.compareTo(a.length));

    var result = text;
    for (final token in sensitive) {
      final typePrefix = _inferType(token, map);
      final mapped = map.tokenFor(token, typePrefix);
      // Use word boundaries to avoid corrupting related tokens
      result = result.replaceAll(RegExp(r'\b' + RegExp.escape(token) + r'\b'), mapped);
    }
    return result;
  }

  String _inferType(String name, TokenMap map) {
    if (map.contains(name)) {
      final token = map.tokenFor(name, 'Class');
      final colon = token.indexOf(':');
      if (colon >= 0) return token.substring(0, colon);
    }
    return 'Class';
  }
}

class _DummyDetector implements SensitivityDetector {
  final List<String> tokens;
  _DummyDetector(this.tokens);

  @override
  List<String> detectInText(String text) => List.from(tokens);

  @override
  bool isSensitive(String token) => true;
}
