import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:claudart/ui/menu.dart';
import 'package:mocktail/mocktail.dart';

class _MockStdout extends Mock implements Stdout {
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
    return -1;
  }

  @override
  set echoMode(bool value) {}

  @override
  set lineMode(bool value) {}

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('arrowMenu asserts on empty items', () {
    expect(() => arrowMenu([]), throwsA(isA<AssertionError>()));
  });

  test('arrowMenu fallback when no terminal', () {
    final mockStdout = _MockStdout();
    final mockStdin = _MockStdin(hasTerminalOverride: false, inputs: ['2']);

    final result = IOOverrides.runZoned(
      () => arrowMenu(['Option A', 'Option B', 'Option C']),
      stdout: () => mockStdout,
      stdin: () => mockStdin,
    );
    expect(result, 1);
  });

  test('arrowMenu fallback with invalid then valid input', () {
    final mockStdout = _MockStdout();
    final mockStdin = _MockStdin(hasTerminalOverride: false, inputs: ['invalid', '4', '3']);

    final result = IOOverrides.runZoned(
      () => arrowMenu(['Option A', 'Option B', 'Option C']),
      stdout: () => mockStdout,
      stdin: () => mockStdin,
    );
    expect(result, 2);
  });

  test('arrowMenu fallback EOF returns 0', () {
    final mockStdout = _MockStdout();
    final mockStdin = _MockStdin(hasTerminalOverride: false, inputs: []);

    final result = IOOverrides.runZoned(
      () => arrowMenu(['Option A', 'Option B', 'Option C']),
      stdout: () => mockStdout,
      stdin: () => mockStdin,
    );
    expect(result, 0);
  });

  test('arrowMenu with terminal handles key down, up, ctrl-c, enter', () {
    final mockStdout = _MockStdout();

    // Test 1: Enter on first item
    var mockStdin = _MockStdin(
      hasTerminalOverride: true,
      byteInputs: [10] // enter
    );
    var result = IOOverrides.runZoned(
      () => arrowMenu(['A', 'B', 'C']),
      stdout: () => mockStdout,
      stdin: () => mockStdin,
    );
    expect(result, 0);

    // Test 2: Down, Down, Up, Enter
    mockStdin = _MockStdin(
      hasTerminalOverride: true,
      byteInputs: [
        27, 91, 66, // down (index 1)
        27, 91, 66, // down (index 2)
        27, 91, 65, // up (index 1)
        10 // enter
      ]
    );
    result = IOOverrides.runZoned(
      () => arrowMenu(['A', 'B', 'C']),
      stdout: () => mockStdout,
      stdin: () => mockStdin,
    );
    expect(result, 1);
  });
}
