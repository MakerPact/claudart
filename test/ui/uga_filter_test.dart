import 'package:test/test.dart';
import 'package:claudart/ui/uga_filter.dart';
import 'package:claudart/file_io.dart';

class MockFileIO implements FileIO {
  final Map<String, String> files = {};

  @override
  bool fileExists(String path) => files.containsKey(path);

  @override
  String read(String path) => files[path]!;

  @override
  void write(String path, String content) => files[path] = content;

  @override
  void delete(String path) => files.remove(path);

  @override
  List<String> listFiles(String path, {String? extension}) => [];

  @override
  void createDir(String path) {}

  @override
  bool dirExists(String path) => false;

  @override
  void createLink(String linkPath, String targetPath) {}

  @override
  void deleteLink(String path) {}

  @override
  bool linkExists(String path) => false;

  @override
  void writeAtomic(String path, String content) {}
}

void main() {
  group('UgaFilter', () {
    test('initializes with default words', () {
      final filter = UgaFilter();
      expect(filter.getWords().isNotEmpty, isTrue);
    });

    test('initializes with custom words', () {
      final filter = UgaFilter('one two three four five');
      expect(filter.getWords(), ['one', 'two', 'three', 'four', 'five']);
    });

    test('calculates correct chunks based on levels', () {
      final filter = UgaFilter('one two three four five six seven eight nine ten');

      expect(filter.getWordsForLevel(0), isEmpty);
      expect(filter.getWordsForLevel(1), ['one', 'two']); // 10 * 1 / 5 = 2
      expect(filter.getWordsForLevel(2), ['one', 'two', 'three', 'four']); // 10 * 2 / 5 = 4
      expect(filter.getWordsForLevel(3), ['one', 'two', 'three', 'four', 'five', 'six']); // 10 * 3 / 5 = 6
      expect(filter.getWordsForLevel(4), ['one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight']); // 10 * 4 / 5 = 8
      expect(filter.getWordsForLevel(5), ['one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten']); // 10
      expect(filter.getWordsForLevel(6), ['one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten']); // max
    });

    test('filters text correctly', () {
      final filter = UgaFilter('can you please');

      const input = 'Can you please make the button larger?';

      expect(filter.applyFilter(input, 0), input);

      // level 5 applies all words 'can', 'you', 'please'
      expect(filter.applyFilter(input, 5), 'make the button larger?');
    });

    test('filters words regardless of case', () {
       final filter = UgaFilter('HELLO world');
       expect(filter.applyFilter('hello WORLD and universe', 5), 'and universe');
    });

    test('loads and saves using FileIO', () {
       final io = MockFileIO();
       io.write('uga.txt', 'custom word list');

       final filter = UgaFilter.load(io, 'uga.txt');
       expect(filter.getWords(), ['custom', 'word', 'list']);

       filter.save(io, 'uga2.txt');
       expect(io.read('uga2.txt'), 'custom word list');
    });
  });
}
