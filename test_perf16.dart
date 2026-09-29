import 'package:claudart/sensitivity/abstractor.dart';
import 'package:claudart/sensitivity/token_map.dart';
import 'package:claudart/sensitivity/detector.dart';

void main() {
  final map = TokenMap();

  // Test replacing smaller parts inside longer ones to see word boundaries effect
  // Like "User" vs "UserRepository" vs "LocalUser"
  final tokens = ['User', 'UserRepository', 'LocalUser', 'Repository', 'Local'];
  final detector = _DummyDetector(tokens);

  final text = 'User UserRepository LocalUser Repository Local UserLocal';

  final regexReplace = RegexReplaceAbstractor();
  print('Regex boundaries: ${regexReplace.abstract(text, map, detector)}');

  final map2 = TokenMap();
  final simpleReplace = SimpleReplaceAbstractor();
  print('Simple replace: ${simpleReplace.abstract(text, map2, detector)}');
}

class RegexReplaceAbstractor extends Abstractor {
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

class SimpleReplaceAbstractor extends Abstractor {
  @override
  String abstract(String text, TokenMap map, SensitivityDetector detector) {
    final sensitive = detector.detectInText(text);
    if (sensitive.isEmpty) return text;
    sensitive.sort((a, b) => b.length.compareTo(a.length));
    var result = text;
    for (final token in sensitive) {
      final typePrefix = _inferType(token, map);
      final mapped = map.tokenFor(token, typePrefix);
      result = result.replaceAll(token, mapped);
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
