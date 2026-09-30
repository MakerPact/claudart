import 'dart:io';
import '../file_io.dart';

class UgaFilter {
  static const int maxLevel = 5;
  static const int minLevel = 0;
  static const String defaultWords =
      '''can you please if could i would appreciate thank just
really very so basically honestly actually definitely completely totally literally
absolutely apparently seemingly arguably perhaps maybe somehow somewhat anyway moreover
furthermore nevertheless nonetheless instead although however whereas otherwise essentially practically
virtually roughly approximately nearly almost anyhow besides kinda sorta probably
hopefully certainly surely clearly obviously like know mean guess think
feel in my opinion to be honest tell the truth
as a matter of fact it happens seems me that
from point view far am concerned book personally speaking generally
broadly technically theoretically statistically historically geographically politically economically socially culturally
psychologically philosophically scientifically mathematically logically rationally reasonably objectively subjectively relatively
strictly loosely figuratively metaphorically allegorically symbolically umm uhh seriously anyways
well right okay ok yeah yes no sure fine alright
cool whatever whoever whenever wherever sometimes always never possibly too
quite rather fairly pretty slightly mostly mainly chiefly principally primarily
largely typically usually customarily habitually routinely normally ordinarily frequently often
regularly repeatedly constantly continually continuously perpetually forever ever rarely seldom
infrequently hardly scarcely barely fundamentally stuff things thing something anything
nothing everything someone anyone no-one everyone somebody anybody nobody everybody
somewhere anywhere nowhere everywhere suppose believe understand see hear listen
''';

  late List<String> _words;

  UgaFilter([String? customWords]) {
    final rawWords = customWords ?? defaultWords;
    _words = rawWords
        .replaceAll(RegExp(r'\s+'), ' ')
        .split(' ')
        .map((w) => w.trim().toLowerCase())
        .where((w) => w.isNotEmpty)
        .toList();
    _words = _words.toSet().toList(); // Deduplicate custom lists too
    // In a real implementation we would distinct them, but let's keep the exact list for now to allow user ordering.
    // _words = _words.toSet().toList(); // Wait, instructions said to let the user order them.
    // Ensure we have words
    if (_words.isEmpty) {
      _words = [
        'please',
        'can',
        'you',
        'if',
        'could',
        'would',
        'appreciate',
        'thank',
      ];
    }
  }

  factory UgaFilter.load(FileIO io, String configPath) {
    if (io.fileExists(configPath)) {
      return UgaFilter(io.read(configPath));
    }
    return UgaFilter();
  }

  void save(FileIO io, String configPath) {
    io.write(configPath, _words.join(' '));
  }

  List<String> getWords() => List.unmodifiable(_words);

  List<String> getWordsForLevel(int level) {
    if (level <= 0) return [];
    if (level >= maxLevel) return List.unmodifiable(_words);

    // Calculate chunk size. 5 levels means 4 non-zero levels (1, 2, 3, 4) plus level 5 (all words).
    // The request said:
    // level 5: all 200 words
    // level 4: first 160 words (4/5)
    // level 3: first 120 words (3/5)
    // level 2: first 80 words (2/5)
    // level 1: first 40 words (1/5)

    int wordsToTake = (_words.length * level ~/ maxLevel);
    return _words.take(wordsToTake).toList();
  }

  String applyFilter(String text, int level) {
    if (level <= 0) return text;

    final wordsToFilter = getWordsForLevel(level);
    if (wordsToFilter.isEmpty) return text;

    // Build a regex to match these words as whole words, case-insensitively
    // We sort by length descending to match longest phrases first if any existed, though we split by space above.
    // Actually, the user asked for words like "thank you" which we split into "thank" and "you".
    // If they provided "thank you" on one line, we split it. Let's make sure it handles regex safely.
    final sortedWords = wordsToFilter.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    final pattern = sortedWords.map(RegExp.escape).join('|');
    final regex = RegExp(r'\b(' + pattern + r')\b', caseSensitive: false);

    // Replace the matched words with empty string, then clean up extra spaces
    String result = text.replaceAll(regex, '');
    result = result.replaceAll(RegExp(r'\s+'), ' ').trim();
    return result;
  }
}
