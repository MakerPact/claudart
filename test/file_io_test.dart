import 'package:test/test.dart';
import 'package:claudart/file_io.dart';
import 'dart:io';

void main() {
  test('RealFileIO implementation', () {
    final io = RealFileIO();

    // fileExists, dirExists
    expect(io.fileExists('pubspec.yaml'), isTrue);
    expect(io.fileExists('non_existent_file_123.txt'), isFalse);
    expect(io.dirExists('lib'), isTrue);
    expect(io.dirExists('pubspec.yaml'), isFalse);

    // read
    final pubspec = io.read('pubspec.yaml');
    expect(pubspec, contains('claudart'));
    expect(io.read('non_existent_file_123.txt'), '');

    // write and delete
    final tempDir = Directory.systemTemp.createTempSync('claudart_io_test_');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    final testFile = '${tempDir.path}/test_io_temp.txt';
    io.write(testFile, 'hello');
    expect(io.read(testFile), 'hello');
    io.delete(testFile);
    expect(io.fileExists(testFile), isFalse);

    // writeAtomic
    io.writeAtomic(testFile, 'atomic');
    expect(io.read(testFile), 'atomic');
    io.delete(testFile);

    // createDir
    final testDir = '${tempDir.path}/test_io_dir_temp';
    io.createDir(testDir);
    expect(io.dirExists(testDir), isTrue);
    io.write('$testDir/file1.txt', '1');
    io.write('$testDir/file2.txt', '2');
    io.write('$testDir/file3.csv', '3');

    // listFiles
    final allFiles = io.listFiles(testDir);
    expect(allFiles.length, 3);

    final txtFiles = io.listFiles(testDir, extension: '.txt');
    expect(txtFiles.length, 2);

    final noneFiles = io.listFiles('non_existent_dir_123');
    expect(noneFiles, isEmpty);

    // links
    final linkPath = '$testDir/my_link';
    io.createLink(linkPath, 'file1.txt');
    expect(io.linkExists(linkPath), isTrue);
    io.deleteLink(linkPath);
    expect(io.linkExists(linkPath), isFalse);

    // cleanup
    // cleanup handled by tearDown
  });
}
