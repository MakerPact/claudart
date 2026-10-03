import 'package:test/test.dart';
import 'package:claudart/process_runner.dart';
import 'dart:io';

void main() {
  test('RealProcessRunner implementation', () async {
    final runner = RealProcessRunner();

    // runSync
    var result = runner.runSync('echo', ['hello']);
    expect(result.exitCode, 0);
    expect((result.stdout as String).trim(), 'hello');

    // run
    result = await runner.run('echo', ['world']);
    expect(result.exitCode, 0);
    expect((result.stdout as String).trim(), 'world');
  });
}
