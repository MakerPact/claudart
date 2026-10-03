import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:claudart/ui/line_editor.dart';
import 'package:mocktail/mocktail.dart';

class _MockStdout extends Mock implements Stdout {
  final bool unsupportedWidth;
  _MockStdout({this.unsupportedWidth = false});
  @override
  int get terminalColumns {
    if (unsupportedWidth) throw UnsupportedError('no width');
    return 80;
  }
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockStdin extends Mock implements Stdin {
  final bool hasTerminalOverride;
  final List<String> inputs;
  final List<int> byteInputs;
  int _inputIndex = 0;
  int _byteIndex = 0;

  _MockStdin({this.hasTerminalOverride = true, this.inputs = const [], this.byteInputs = const []});

  @override
  bool get hasTerminal => hasTerminalOverride;

  @override
  String? readLineSync({
    Encoding encoding = systemEncoding,
    bool retainNewlines = false,
  }) {
    if (_inputIndex < inputs.length) {
      return inputs[_inputIndex++];
    }
    return null;
  }

  @override
  int readByteSync() {
    if (_byteIndex < byteInputs.length) {
      return byteInputs[_byteIndex++];
    }
    return 10;
  }

  @override
  set echoMode(bool value) {}

  @override
  set lineMode(bool value) {}

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('wrappedLineCount calculation', () {
    expect(wrappedLineCount(2, 0, 80), 1);
    expect(wrappedLineCount(2, 78, 80), 1);
    expect(wrappedLineCount(2, 80, 80), 2);
    expect(wrappedLineCount(2, 158, 80), 2);
    expect(wrappedLineCount(2, 10, -1), 1);
    expect(wrappedLineCount(0, 0, 80), 1);
  });

  test('readLine non-terminal fallback', () {
    final mockStdout = _MockStdout();
    final mockStdin = _MockStdin(hasTerminalOverride: false, inputs: ['  input text  ']);

    final result = IOOverrides.runZoned(
      () => readLine(),
      stdout: () => mockStdout,
      stdin: () => mockStdin,
    );
    expect(result, 'input text');
  });

  test('readLine non-terminal fallback empty not optional loops', () {
    final mockStdout = _MockStdout();
    final mockStdin = _MockStdin(hasTerminalOverride: false, inputs: ['', '  input text  ']);

    final result = IOOverrides.runZoned(
      () => readLine(optional: false),
      stdout: () => mockStdout,
      stdin: () => mockStdin,
    );
    expect(result, 'input text');
  });

  test('readLine non-terminal fallback optional empty returns null', () {
    final mockStdout = _MockStdout();
    final mockStdin = _MockStdin(hasTerminalOverride: false, inputs: ['']);

    final result = IOOverrides.runZoned(
      () => readLine(optional: true),
      stdout: () => mockStdout,
      stdin: () => mockStdin,
    );
    expect(result, isNull);
  });

  test('readLine non-terminal fallback EOF returns null', () {
    final mockStdout = _MockStdout();
    final mockStdin = _MockStdin(hasTerminalOverride: false, inputs: []);

    final result = IOOverrides.runZoned(
      () => readLine(),
      stdout: () => mockStdout,
      stdin: () => mockStdin,
    );
    expect(result, isNull);
  });

  test('readLine terminal mode key interactions', () {
    final mockStdout = _MockStdout();
    final mockStdin = _MockStdin(hasTerminalOverride: true, byteInputs: [
      97, 98, 99, // 'abc'
      27, 91, 68, // Left
      127,        // Backspace
      27, 91, 67, // Right
      10          // Enter
    ]);

    final result = IOOverrides.runZoned(
      () => readLine(),
      stdout: () => mockStdout,
      stdin: () => mockStdin,
    );
    expect(result, 'ac');
  });

  test('readLine terminal mode key interactions 2', () {
    final mockStdout = _MockStdout();
    final mockStdin = _MockStdin(hasTerminalOverride: true, byteInputs: [
      97, 98, 99, // 'abc'
      1,          // Home
      27, 91, 51, 126, // Delete
      5,          // End
      21,         // Ctrl+U
      10          // Enter
    ]);

    final result = IOOverrides.runZoned(
      () => readLine(optional: true),
      stdout: () => mockStdout,
      stdin: () => mockStdin,
    );
    expect(result, isNull);
  });

  test('readLine terminal mode utf8 sequences', () {
    final mockStdout = _MockStdout();
    final mockStdin = _MockStdin(hasTerminalOverride: true, byteInputs: [
      195, 182, // 'ö'
      10        // Enter
    ]);

    final result = IOOverrides.runZoned(
      () => readLine(),
      stdout: () => mockStdout,
      stdin: () => mockStdin,
    );
    expect(result, 'ö');
  });

  test('readLine terminal mode Home and End sequences', () {
    final mockStdout = _MockStdout();
    final mockStdin = _MockStdin(hasTerminalOverride: true, byteInputs: [
      97, 98, // ab
      27, 91, 72, // Home (xterm)
      99, // c -> cab
      27, 91, 70, // End (xterm)
      100, // d -> cabd
      10
    ]);

    final result = IOOverrides.runZoned(
      () => readLine(),
      stdout: () => mockStdout,
      stdin: () => mockStdin,
    );
    expect(result, 'cabd');
  });

  test('readLine terminal mode vt sequences', () {
    final mockStdout = _MockStdout();
    final mockStdin = _MockStdin(hasTerminalOverride: true, byteInputs: [
      97, 98, // ab
      27, 91, 49, 126, // Home (vt)
      99, // c -> cab
      27, 91, 52, 126, // End (vt)
      100, // d -> cabd
      10
    ]);

    final result = IOOverrides.runZoned(
      () => readLine(),
      stdout: () => mockStdout,
      stdin: () => mockStdin,
    );
    expect(result, 'cabd');
  });

  test('readLine terminal mode invalid utf8', () {
    final mockStdout = _MockStdout();
    final mockStdin = _MockStdin(hasTerminalOverride: true, byteInputs: [
      255, // invalid utf8
      10
    ]);

    final result = IOOverrides.runZoned(
      () => readLine(),
      stdout: () => mockStdout,
      stdin: () => mockStdin,
    );
    expect(result, '');
  });

  test('readLine terminal mode 3-byte and 4-byte utf8', () {
    final mockStdout = _MockStdout();
    final mockStdin = _MockStdin(hasTerminalOverride: true, byteInputs: [
      226, 130, 172,
      240, 144, 141, 136,
      10
    ]);

    final result = IOOverrides.runZoned(
      () => readLine(),
      stdout: () => mockStdout,
      stdin: () => mockStdin,
    );
    expect(result, '€𐍈');
  });

  test('readLine unsupported terminal width gracefully handled', () {
    final mockStdout = _MockStdout(unsupportedWidth: true);
    final mockStdin = _MockStdin(hasTerminalOverride: true, byteInputs: [
      97, 10
    ]);

    final result = IOOverrides.runZoned(
      () => readLine(),
      stdout: () => mockStdout,
      stdin: () => mockStdin,
    );
    expect(result, 'a');
  });
}
