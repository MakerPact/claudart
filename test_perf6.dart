import 'package:claudart/sensitivity/abstractor.dart';
import 'package:claudart/sensitivity/token_map.dart';
import 'package:claudart/sensitivity/detector.dart';

void main() {
  final map = TokenMap();

  // Create 600 unique tokens (TokenMap alphabet size limitation avoids larger sets)
  final tokens = List.generate(600, (i) => 'SensitiveToken$i');
  final detector = _DummyDetector(tokens);

  final textBuffer = StringBuffer();
  for (int i = 0; i < 600; i++) {
    textBuffer.write('This is some text with SensitiveToken$i and other things. ');
  }
  final text = textBuffer.toString();

  final abstractor = Abstractor();
  for (int i = 0; i < 2; i++) {
    abstractor.abstract(text, map, detector);
  }
  final stopwatch1 = Stopwatch()..start();
  for (int i = 0; i < 50; i++) {
    abstractor.abstract(text, map, detector);
  }
  stopwatch1.stop();

  final singlePass = SinglePassAbstractor();
  for (int i = 0; i < 2; i++) {
    singlePass.abstract(text, map, detector);
  }
  final stopwatch3 = Stopwatch()..start();
  for (int i = 0; i < 50; i++) {
    singlePass.abstract(text, map, detector);
  }
  stopwatch3.stop();

  print('Current (cached RegExp): ${stopwatch1.elapsedMilliseconds}ms');
  print('Single pass (RegExp): ${stopwatch3.elapsedMilliseconds}ms');

  final out1 = abstractor.abstract('Test SensitiveToken1 test', map, detector);
  final out3 = singlePass.abstract('Test SensitiveToken1 test', map, detector);
  print('Output 1: $out1');
  print('Output 3: $out3');
}

class SinglePassAbstractor extends Abstractor {
  @override
  String abstract(String text, TokenMap map, SensitivityDetector detector) {
    final sensitive = detector.detectInText(text);
    if (sensitive.isEmpty) return text;

    sensitive.sort((a, b) => b.length.compareTo(a.length));

    // Create a map from token to mapped value
    final mappedTokens = <String, String>{};
    for (final token in sensitive) {
      final typePrefix = _inferType(token, map);
      mappedTokens[token] = map.tokenFor(token, typePrefix);
    }

    // Build a single regex to match any of the sensitive tokens with word boundaries
    final escapedTokens = sensitive.map(RegExp.escape).join('|');
    final regex = RegExp(r'\b(' + escapedTokens + r')\b');

    return text.replaceAllMapped(regex, (match) {
      final token = match.group(0)!;
      return mappedTokens[token] ?? token;
    });
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
