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

  final singleRegexMap = SingleRegexMapAbstractor();
  for (int i = 0; i < 2; i++) {
    singleRegexMap.abstract(text, map, detector);
  }
  final stopwatch1 = Stopwatch()..start();
  for (int i = 0; i < 100; i++) {
    singleRegexMap.abstract(text, map, detector);
  }
  stopwatch1.stop();

  print('Single replaceAllMapped (compiled once): ${stopwatch1.elapsedMilliseconds}ms');
  print('RegExp loop recompile: ${stopwatch2.elapsedMilliseconds}ms');
}

class SingleRegexMapAbstractor extends Abstractor {
  @override
  String abstract(String text, TokenMap map, SensitivityDetector detector) {
    final sensitive = detector.detectInText(text);
    if (sensitive.isEmpty) return text;

    sensitive.sort((a, b) => b.length.compareTo(a.length));

    // Instead of replaceAll in a loop, create one large regex with word boundaries
    final escapedTokens = sensitive.map(RegExp.escape).join('|');
    final regex = RegExp(r'\b(' + escapedTokens + r')\b');

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
