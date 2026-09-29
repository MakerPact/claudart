import 'package:claudart/sensitivity/abstractor.dart';
import 'package:claudart/sensitivity/token_map.dart';
import 'package:claudart/sensitivity/detector.dart';

void main() {
  final map = TokenMap();

  // Create 100 tokens
  final tokens = List.generate(100, (i) => 'SensitiveToken$i');
  final detector = _DummyDetector(tokens);

  final textBuffer = StringBuffer();
  for (int i = 0; i < 100; i++) {
    textBuffer.write('This is some text with SensitiveToken$i and other things. ');
  }
  final text = textBuffer.toString();

  final singlePassCached = SinglePassCachedAbstractor();
  for (int i = 0; i < 2; i++) {
    singlePassCached.abstract(text, map, detector);
  }
  final stopwatch1 = Stopwatch()..start();
  for (int i = 0; i < 2000; i++) {
    singlePassCached.abstract(text, map, detector);
  }
  stopwatch1.stop();

  final compileInLoop = CompileInLoopAbstractor();
  for (int i = 0; i < 2; i++) {
    compileInLoop.abstract(text, map, detector);
  }
  final stopwatch2 = Stopwatch()..start();
  for (int i = 0; i < 2000; i++) {
    compileInLoop.abstract(text, map, detector);
  }
  stopwatch2.stop();

  print('Single pass with cached RegExp: ${stopwatch1.elapsedMilliseconds}ms');
  print('Compile in loop: ${stopwatch2.elapsedMilliseconds}ms');
}

class SinglePassCachedAbstractor extends Abstractor {
  static final _regexCache = <String, RegExp>{};

  @override
  String abstract(String text, TokenMap map, SensitivityDetector detector) {
    final sensitive = detector.detectInText(text);
    if (sensitive.isEmpty) return text;

    sensitive.sort((a, b) => b.length.compareTo(a.length));

    final mappedTokens = <String, String>{};
    for (final token in sensitive) {
      final typePrefix = _inferType(token, map);
      mappedTokens[token] = map.tokenFor(token, typePrefix);
    }

    final cacheKey = sensitive.join('|');
    var regex = _regexCache[cacheKey];
    if (regex == null) {
      final escapedTokens = sensitive.map(RegExp.escape).join('|');
      regex = RegExp(r'\b(' + escapedTokens + r')\b');
      if (_regexCache.length > 50) _regexCache.clear();
      _regexCache[cacheKey] = regex;
    }

    return text.replaceAllMapped(regex, (match) {
      final token = match.group(0)!;
      return mappedTokens[token] ?? token;
    });
  }
  String _inferType(String name, TokenMap map) { return 'Class'; }
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
  List<String> detectInText(String text) {
    return tokens.where((t) => text.contains(t)).toList();
  }

  @override
  bool isSensitive(String token) => true;
}
