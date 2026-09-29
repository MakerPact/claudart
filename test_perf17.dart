import 'package:claudart/sensitivity/abstractor.dart';
import 'package:claudart/sensitivity/token_map.dart';
import 'package:claudart/sensitivity/detector.dart';

void main() {
  final map = TokenMap();

  // Need to measure performance impact in a scenario where looping with RegExp is actually slow
  // Let's create a large corpus with repeating tokens
  final tokens = List.generate(500, (i) => 'Token${i}Name');
  final detector = _DummyDetector(tokens);

  final textBuffer = StringBuffer();
  for (int i = 0; i < 50; i++) {
    for (final token in tokens) {
      textBuffer.write('This is some text $token and other text. ');
    }
  }
  final text = textBuffer.toString();

  final regexCached = RegexCachedAbstractor();
  for (int i = 0; i < 2; i++) {
    regexCached.abstract(text, map, detector);
  }
  final stopwatch1 = Stopwatch()..start();
  for (int i = 0; i < 100; i++) {
    regexCached.abstract(text, map, detector);
  }
  stopwatch1.stop();

  final regexLoop = RegexLoopAbstractor();
  for (int i = 0; i < 2; i++) {
    regexLoop.abstract(text, map, detector);
  }
  final stopwatch2 = Stopwatch()..start();
  for (int i = 0; i < 100; i++) {
    regexLoop.abstract(text, map, detector);
  }
  stopwatch2.stop();

  print('RegExp cached static: ${stopwatch1.elapsedMilliseconds}ms');
  print('RegExp loop recompile: ${stopwatch2.elapsedMilliseconds}ms');
}

class RegexCachedAbstractor extends Abstractor {
  static final _regexCache = <String, RegExp>{};

  @override
  String abstract(String text, TokenMap map, SensitivityDetector detector) {
    final sensitive = detector.detectInText(text);
    if (sensitive.isEmpty) return text;

    sensitive.sort((a, b) => b.length.compareTo(a.length));

    var result = text;
    for (final token in sensitive) {
      final typePrefix = _inferType(token, map);
      final mapped = map.tokenFor(token, typePrefix);

      var regExp = _regexCache[token];
      if (regExp == null) {
        regExp = RegExp(r'\b' + RegExp.escape(token) + r'\b');
        if (_regexCache.length > 1000) _regexCache.clear();
        _regexCache[token] = regExp;
      }

      result = result.replaceAll(regExp, mapped);
    }
    return result;
  }
  String _inferType(String name, TokenMap map) { return 'Class'; }
}

class RegexLoopAbstractor extends Abstractor {
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
  List<String> detectInText(String text) {
    return tokens;
  }

  @override
  bool isSensitive(String token) => true;
}
