import 'package:test/test.dart';
import 'package:claudart/workspace/workspace_index.dart';
import 'package:claudart/session/archive_entry.dart';
import 'package:path/path.dart' as p;
import '../helpers/mocks.dart';

void main() {
  group('workspace_index', () {
    const workspace = '/mock/workspace';
    late MemoryFileIO fileIO;

    setUp(() {
      fileIO = MemoryFileIO();
    });

    ArchiveEntry createEntry(String id, String desc, ArchiveKind kind) {
      return ArchiveEntry(
        id: id,
        kind: kind,
        description: desc,
        branch: 'main',
        createdAt: DateTime.parse('2024-01-01T12:00:00Z'),
        handoffFile: 'handoff.md',
      );
    }

    group('loadIndex', () {
      test('returns empty list if file does not exist', () {
        final entries = loadIndex(workspace, io: fileIO);
        expect(entries, isEmpty);
      });

      test('returns empty list if file is empty or invalid JSON', () {
        final indexPath = p.join(workspace, 'archive', 'index.json');
        fileIO.write(indexPath, 'invalid json');
        final entries = loadIndex(workspace, io: fileIO);
        expect(entries, isEmpty);

        fileIO.write(indexPath, '');
        final emptyEntries = loadIndex(workspace, io: fileIO);
        expect(emptyEntries, isEmpty);
      });

      test('returns entries reversed', () {
        final entry1 = createEntry('1', 'first', ArchiveKind.archive);
        final entry2 = createEntry('2', 'second', ArchiveKind.reminder);

        // write directly using the JSON helper
        final indexPath = p.join(workspace, 'archive', 'index.json');
        fileIO.write(indexPath, archiveEntriesToJson([entry1, entry2]));

        final entries = loadIndex(workspace, io: fileIO);
        expect(entries.length, 2);
        // Should be newest first (reversed)
        expect(entries[0].id, '2');
        expect(entries[1].id, '1');
      });
    });

    group('appendToIndex', () {
      test('creates archive dir and file if they do not exist', () {
        final entry = createEntry('1', 'first', ArchiveKind.archive);
        appendToIndex(workspace, entry, io: fileIO);

        final archiveDir = p.join(workspace, 'archive');
        final indexPath = p.join(archiveDir, 'index.json');

        expect(fileIO.dirExists(archiveDir), isTrue);
        expect(fileIO.fileExists(indexPath), isTrue);

        final entries = loadIndex(workspace, io: fileIO);
        expect(entries.length, 1);
        expect(entries.first.id, '1');
      });

      test('appends to existing index', () {
        final entry1 = createEntry('1', 'first', ArchiveKind.archive);
        appendToIndex(workspace, entry1, io: fileIO);

        final entry2 = createEntry('2', 'second', ArchiveKind.reminder);
        appendToIndex(workspace, entry2, io: fileIO);

        final entries = loadIndex(workspace, io: fileIO);
        expect(entries.length, 2);
        // loadIndex reverses, so newest is first
        expect(entries[0].id, '2');
        expect(entries[1].id, '1');
      });
    });

    group('findEntry', () {
      test('returns null if entry is not found', () {
        final entry = findEntry(workspace, 'non-existent', io: fileIO);
        expect(entry, isNull);
      });

      test('returns correct entry when multiple exist', () {
        final entry1 = createEntry('1', 'first', ArchiveKind.archive);
        final entry2 = createEntry('2', 'second', ArchiveKind.reminder);

        appendToIndex(workspace, entry1, io: fileIO);
        appendToIndex(workspace, entry2, io: fileIO);

        final found = findEntry(workspace, '1', io: fileIO);
        expect(found, isNotNull);
        expect(found?.id, '1');
        expect(found?.description, 'first');
      });
    });
  });
}
