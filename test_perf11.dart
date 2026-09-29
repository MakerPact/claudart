import 'package:claudart/sensitivity/abstractor.dart';
import 'package:claudart/sensitivity/token_map.dart';
import 'package:claudart/sensitivity/detector.dart';

void main() {
  final map = TokenMap();

  // Create 50 tokens
  final tokens = List.generate(50, (i) => 'SensitiveToken$i');
  final detector = _DummyDetector(tokens);

  final textBuffer = StringBuffer();
  for (int i = 0; i < 50; i++) {
    textBuffer.write('This is some text with SensitiveToken$i and other things. ');
  }
  final text = textBuffer.toString();

  final cached = CachedAbstractor();
  for (int i = 0; i < 2; i++) {
    cached.abstract(text, map, detector);
  }
  final stopwatch1 = Stopwatch()..start();
  for (int i = 0; i < 5000; i++) {
    cached.abstract(text, map, detector);
  }
  stopwatch1.stop();

  final compileInLoop = CompileInLoopAbstractor();
  for (int i = 0; i < 2; i++) {
    compileInLoop.abstract(text, map, detector);
  }
  final stopwatch2 = Stopwatch()..start();
  for (int i = 0; i < 5000; i++) {
    compileInLoop.abstract(text, map, detector);
  }
  stopwatch2.stop();

  print('Cached RegExp in static member (fewer tokens, more iterations): ${stopwatch1.elapsedMilliseconds}ms');
  print('Compile in loop (fewer tokens, more iterations): ${stopwatch2.elapsedMilliseconds}ms');
}

class CachedAbstractor extends Abstractor {
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
