import 'package:claudart/sensitivity/abstractor.dart';
import 'package:claudart/sensitivity/token_map.dart';
import 'package:claudart/sensitivity/detector.dart';

void main() {
  final map = TokenMap();

  // We need to trigger compilation without much searching overhead
  // Lots of unique tokens every time (cache busting) vs compiling in loop vs compiling once per token

  final tokens = List.generate(100, (i) => 'Token${i}Name');
  final detector = _DummyDetector(tokens);

  final textBuffer = StringBuffer();
  for (final token in tokens.take(10)) {
    textBuffer.write('This is some text $token. ');
  }
  final text = textBuffer.toString();

  final singleRegex = SingleRegexAbstractor();
  for (int i = 0; i < 2; i++) {
    singleRegex.abstract(text, map, detector);
  }
  final stopwatch3 = Stopwatch()..start();
  for (int i = 0; i < 2000; i++) {
    singleRegex.abstract(text, map, detector);
  }
  stopwatch3.stop();

  final cached = RegexCachedAbstractor();
  for (int i = 0; i < 2; i++) {
    cached.abstract(text, map, detector);
  }
  final stopwatch1 = Stopwatch()..start();
  for (int i = 0; i < 2000; i++) {
    cached.abstract(text, map, detector);
  }
  stopwatch1.stop();

  final loop = RegexLoopAbstractor();
  for (int i = 0; i < 2; i++) {
    loop.abstract(text, map, detector);
  }
  final stopwatch2 = Stopwatch()..start();
  for (int i = 0; i < 2000; i++) {
    loop.abstract(text, map, detector);
  }
  stopwatch2.stop();

  print('Single replaceAllMapped (cached RegExp): ${stopwatch3.elapsedMilliseconds}ms');
  print('RegExp cached map: ${stopwatch1.elapsedMilliseconds}ms');
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

class SingleRegexAbstractor extends Abstractor {
  static final _regexCache = <String, RegExp>{};

  @override
  String abstract(String text, TokenMap map, SensitivityDetector detector) {
    final sensitive = detector.detectInText(text);
    if (sensitive.isEmpty) return text;

    sensitive.sort((a, b) => b.length.compareTo(a.length));

    final cacheKey = sensitive.join('|');
    var regex = _regexCache[cacheKey];
    if (regex == null) {
      final escaped = sensitive.map(RegExp.escape).join('|');
      regex = RegExp(r'\b(' + escaped + r')\b');
      if (_regexCache.length > 100) _regexCache.clear();
      _regexCache[cacheKey] = regex;
    }

    final tokenMap = <String, String>{};
    for (final token in sensitive) {
      final typePrefix = _inferType(token, map);
      tokenMap[token] = map.tokenFor(token, typePrefix);
    }

    return text.replaceAllMapped(regex, (match) {
      final token = match.group(0)!;
      return tokenMap[token] ?? token;
    });
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
