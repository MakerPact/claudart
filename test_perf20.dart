import 'package:claudart/sensitivity/abstractor.dart';
import 'package:claudart/sensitivity/token_map.dart';
import 'package:claudart/sensitivity/detector.dart';

void main() {
  final map = TokenMap();

  // Real world usage: long file content
  final tokens = List.generate(100, (i) => 'SensitiveToken$i');
  final detector = _DummyDetector(tokens);

  final textBuffer = StringBuffer();
  for (int i = 0; i < 500; i++) { // Very long text, ~50,000 words
    textBuffer.write('This is some code. ');
    if (i % 10 == 0) {
      textBuffer.write('class ${tokens[i % 100]} { } ');
    }
  }
  final text = textBuffer.toString();

  final regexLoop = RegexLoopAbstractor();
  for (int i = 0; i < 2; i++) {
    regexLoop.abstract(text, map, detector);
  }
  final stopwatch2 = Stopwatch()..start();
  for (int i = 0; i < 100; i++) {
    regexLoop.abstract(text, map, detector);
  }
  stopwatch2.stop();

  final cachedMap = RegexCachedAbstractor();
  for (int i = 0; i < 2; i++) {
    cachedMap.abstract(text, map, detector);
  }
  final stopwatch1 = Stopwatch()..start();
  for (int i = 0; i < 100; i++) {
    cachedMap.abstract(text, map, detector);
  }
  stopwatch1.stop();

  print('RegExp cached map: ${stopwatch1.elapsedMilliseconds}ms');
  print('RegExp loop recompile: ${stopwatch2.elapsedMilliseconds}ms');
}

class RegexCachedAbstractor extends Abstractor {
  final _regexCache = <String, RegExp>{};

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
    return tokens.where((t) => text.contains(t)).toList();
  }

  @override
  bool isSensitive(String token) => true;
}
