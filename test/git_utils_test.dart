import 'dart:io';
import 'package:test/test.dart';
import 'package:claudart/git_utils.dart';

void main() {
  group('readGitAuthor', () {
    test('matches real `git config user.name`/`user.email` output', () {
      // Real subprocess, no mocking — matches detectGitContext()'s own
      // untested-in-isolation convention. `git config` falls back to
      // global scope even outside a repo, so this isn't testable against
      // a "no config at all" case without sandboxing $HOME; instead,
      // assert readGitAuthor agrees with a direct `git config` call.
      final expectedName =
          Process.runSync('git', ['config', 'user.name']).stdout.toString().trim();
      final expectedEmail =
          Process.runSync('git', ['config', 'user.email']).stdout.toString().trim();

      final author = readGitAuthor('.');
      expect(author.name, expectedName.isEmpty ? isNull : equals(expectedName));
      expect(author.email, expectedEmail.isEmpty ? isNull : equals(expectedEmail));
    });

    test('does not throw for a nonexistent directory', () {
      expect(() => readGitAuthor('/nonexistent/path/xyz'), returnsNormally);
    });
  });
}
