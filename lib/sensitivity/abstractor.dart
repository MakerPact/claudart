import 'token_map.dart';
import 'detector.dart';

/// Replaces sensitive tokens in text with their mapped abstract tokens,
/// and provides the inverse operation.
class Abstractor {
  /// Replaces all sensitive tokens in [text] with their mapped counterparts.
  /// New tokens are assigned in [map] for any unmapped sensitive identifiers.
  String abstract(String text, TokenMap map, SensitivityDetector detector) {
    final sensitive = detector.detectInText(text);
    if (sensitive.isEmpty) return text;

    // Sort longest first to avoid partial replacement conflicts.
    sensitive.sort((a, b) => b.length.compareTo(a.length));

    var result = text;
    for (final token in sensitive) {
      final typePrefix = _inferType(token, map);
      final mapped = map.tokenFor(token, typePrefix);
      result = result.replaceAll(token, mapped);
    }
    return result;
  }

  /// Restores abstracted tokens to real names using the [map].
  String deabstract(String text, TokenMap map) {
    // Build reverse: mapped token -> real name
    // Replace all token-shaped strings in the text with their mapped real names.
    final tokenPattern = RegExp(r'[A-Za-z]+:[A-Z]{1,2}');
    return text.replaceAllMapped(tokenPattern, (match) {
      final tok = match.group(0)!;
      return map.realFor(tok) ?? tok;
    });
  }

  /// Returns true when [text] contains no sensitive tokens.
  bool isNotSensitive(String text, SensitivityDetector detector) {
    return detector.detectInText(text).isEmpty;
  }

  String _inferType(String name, TokenMap map) {
    // If already in map, return its existing prefix
    if (map.contains(name)) {
      final token = map.tokenFor(name, 'Class');
      final colon = token.indexOf(':');
      if (colon >= 0) return token.substring(0, colon);
    }
    if (name.endsWith('Bloc')) return 'Bloc';
    if (name.endsWith('Cubit')) return 'Cubit';
    if (name.endsWith('State')) return 'BlocState';
    if (name.endsWith('Event')) return 'BlocEvent';
    if (name.endsWith('Repository')) return 'Repository';
    if (name.endsWith('Widget')) return 'Widget';
    if (name.endsWith('Provider')) return 'Provider';
    if (name.endsWith('Model')) return 'Model';
    if (name.endsWith('Enum') || _isEnum(name)) return 'Enum';
    if (name.endsWith('X') && name.length > 2) return 'Extension';
    return 'Class';
  }

  bool _isEnum(String name) => false; // enum detection is handled at scan time
}

/// Shared singleton instance.
final abstractor = Abstractor();
