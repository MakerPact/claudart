import 'package:claudart/sensitivity/abstractor.dart';
import 'package:claudart/sensitivity/token_map.dart';
import 'package:claudart/sensitivity/detector.dart';

void main() {
  final map = TokenMap();

  // Create tokens
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

  final manualReplace = ManualReplaceAbstractor();
  for (int i = 0; i < 2; i++) {
    manualReplace.abstract(text, map, detector);
  }
  final stopwatch2 = Stopwatch()..start();
  for (int i = 0; i < 50; i++) {
    manualReplace.abstract(text, map, detector);
  }
  stopwatch2.stop();

  print('Current (cached RegExp): ${stopwatch1.elapsedMilliseconds}ms');
  print('Manual string replace with word boundaries: ${stopwatch2.elapsedMilliseconds}ms');
}

class ManualReplaceAbstractor extends Abstractor {
  @override
  String abstract(String text, TokenMap map, SensitivityDetector detector) {
    final sensitive = detector.detectInText(text);
    if (sensitive.isEmpty) return text;

    sensitive.sort((a, b) => b.length.compareTo(a.length));

    var result = text;
    for (final token in sensitive) {
      final typePrefix = _inferType(token, map);
      final mapped = map.tokenFor(token, typePrefix);
      result = _replaceAllWord(result, token, mapped);
    }
    return result;
  }

  String _replaceAllWord(String text, String token, String replacement) {
    if (text.isEmpty || token.isEmpty) return text;

    final buffer = StringBuffer();
    var startIndex = 0;
    final tokenLen = token.length;
    final textLen = text.length;

    while (true) {
      final index = text.indexOf(token, startIndex);
      if (index == -1) {
        buffer.write(text.substring(startIndex));
        break;
      }

      // Check word boundaries
      final beforeOk = index == 0 || !_isWordChar(text.codeUnitAt(index - 1));
      final afterOk = index + tokenLen == textLen || !_isWordChar(text.codeUnitAt(index + tokenLen));

      if (beforeOk && afterOk) {
        buffer.write(text.substring(startIndex, index));
        buffer.write(replacement);
      } else {
        buffer.write(text.substring(startIndex, index + tokenLen));
      }

      startIndex = index + tokenLen;
    }

    return buffer.toString();
  }

  bool _isWordChar(int codeUnit) {
    // a-z: 97-122, A-Z: 65-90, 0-9: 48-57, _: 95
    return (codeUnit >= 97 && codeUnit <= 122) ||
           (codeUnit >= 65 && codeUnit <= 90) ||
           (codeUnit >= 48 && codeUnit <= 57) ||
           (codeUnit == 95);
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
