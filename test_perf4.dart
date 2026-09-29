import 'package:claudart/sensitivity/abstractor.dart';
import 'package:claudart/sensitivity/token_map.dart';
import 'package:claudart/sensitivity/detector.dart';

void main() {
  final map = TokenMap();

  // Create lots of unique tokens to constantly bust the cache or ensure loop compilation happens often
  final tokens = List.generate(5000, (i) => 'SensitiveToken$i');
  final detector = _DummyDetector(tokens);

  final textBuffer = StringBuffer();
  for (int i = 0; i < 5000; i++) {
    textBuffer.write('This is some text with SensitiveToken$i and other things. ');
  }
  final text = textBuffer.toString();

  final abstractor = Abstractor();
  for (int i = 0; i < 2; i++) {
    abstractor.abstract(text, map, detector);
  }
  final stopwatch1 = Stopwatch()..start();
  for (int i = 0; i < 10; i++) {
    abstractor.abstract(text, map, detector);
  }
  stopwatch1.stop();

  final compileInLoop = CompileInLoopAbstractor();
  for (int i = 0; i < 2; i++) {
    compileInLoop.abstract(text, map, detector);
  }
  final stopwatch2 = Stopwatch()..start();
  for (int i = 0; i < 10; i++) {
    compileInLoop.abstract(text, map, detector);
  }
  stopwatch2.stop();

  print('Current (cached RegExp): ${stopwatch1.elapsedMilliseconds}ms');
  print('Compile in loop (RegExp): ${stopwatch2.elapsedMilliseconds}ms');
}

class CompileInLoopAbstractor extends Abstractor {
  @override
  String abstract(String text, TokenMap map, SensitivityDetector detector) {
    final sensitive = detector.detectInText(text);
    if (sensitive.isEmpty) return text;
    sensitive.sort((a, b) => b.length.compareTo(a.length));
    var result = text;
    for (final token in sensitive) {
      final typePrefix = _inferType(token, map);
      final mapped = map.tokenFor(token, typePrefix);
      result = result.replaceAll(RegExp(r'\b' + RegExp.escape(token) + r'\b'), mapped);
    }
    return result;
  }
  String _inferType(String name, TokenMap map) { return 'Class'; }
}

class _DummyDetector implements SensitivityDetector {
  final List<String> tokens;
  _DummyDetector(this.tokens);

  @override
  List<String> detectInText(String text) => List.from(tokens);

  @override
  bool isSensitive(String token) => true;
}
