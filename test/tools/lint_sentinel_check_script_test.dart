import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Runs `tools/lint_sentinel/check.sh` against a fake `dart` on PATH so the
/// gate logic (fallback, pass, missing rows, real findings) is pinned without
/// analyzing a real package.
void main() {
  final script = p.absolute('tools/lint_sentinel/check.sh');
  const sentinelRow =
      'INFO|STATIC_WARNING|RIVERPOD_KEEP_ALIVE|/w/lib/zz_lint_sentinel/presentation/providers/zz.dart|9|1|5|m';
  const sentinelRow2 =
      'WARNING|STATIC_WARNING|PRESENTATION_NO_THROW|/w/lib/zz_lint_sentinel/presentation/providers/zz.dart|12|5|9|m';
  const realRow =
      'INFO|STATIC_WARNING|RIVERPOD_KEEP_ALIVE|/w/lib/features/a/presentation/providers/a.dart|3|1|5|m';

  Future<({int code, String out, List<String> calls})> run({
    required bool sentinelPresent,
    required String dartOut,
    int dartRc = 0,
    String? firstAttemptOut,
    String attempts = '1',
  }) async {
    final tmp = await Directory.systemTemp.createTemp('sentinel_check_');
    try {
      if (sentinelPresent) {
        await Directory(
          p.join(tmp.path, 'lib', 'zz_lint_sentinel'),
        ).create(recursive: true);
      }
      final bin = await Directory(p.join(tmp.path, 'bin')).create();
      final log = p.join(tmp.path, 'dart.log');
      final outFile = File(p.join(tmp.path, 'dart.out'))
        ..writeAsStringSync(dartOut);
      // With [firstAttemptOut] the shim prints that text on its first call and
      // [dartOut] afterwards, which exercises the retry loop.
      final firstFile = File(p.join(tmp.path, 'dart.first'))
        ..writeAsStringSync(firstAttemptOut ?? '');
      final shim = File(p.join(bin.path, 'dart'))
        ..writeAsStringSync(
          '#!/bin/sh\n'
          'echo "\$@" >> "$log"\n'
          'n=\$(wc -l < "$log")\n'
          'if [ "\$n" -eq 1 ] && [ -s "${firstFile.path}" ]; then cat "${firstFile.path}"; else cat "${outFile.path}"; fi\n'
          'exit $dartRc\n',
        );
      await Process.run('chmod', ['+x', shim.path]);
      final env = Map<String, String>.from(Platform.environment)
        ..['PATH'] = '${bin.path}:${Platform.environment['PATH']}'
        ..['SENTINEL_ATTEMPTS'] = attempts
        ..['SENTINEL_BACKOFF'] = '0';
      final result = await Process.run(
        'bash',
        [script],
        workingDirectory: tmp.path,
        environment: env,
      );
      final calls = File(log).existsSync()
          ? File(log).readAsLinesSync().where((l) => l.isNotEmpty).toList()
          : <String>[];
      return (
        code: result.exitCode,
        out: '${result.stdout}${result.stderr}',
        calls: calls,
      );
    } finally {
      await tmp.delete(recursive: true);
    }
  }

  test(
    'falls back to dart analyze --fatal-* without the sentinel dir',
    () async {
      final r = await run(
        sentinelPresent: false,
        dartOut: 'No issues found!\n',
      );
      expect(r.code, 0, reason: r.out);
      expect(r.calls, ['analyze --fatal-infos --fatal-warnings']);
      final failing = await run(
        sentinelPresent: false,
        dartOut: 'x',
        dartRc: 3,
      );
      expect(failing.code, 3);
    },
  );

  test('passes when only the sentinel rows are present', () async {
    final r = await run(
      sentinelPresent: true,
      dartOut: '$sentinelRow\n$sentinelRow2\n',
      dartRc: 2,
    );
    expect(r.code, 0, reason: r.out);
    expect(r.calls, ['analyze --format=machine']);
    expect(r.out, contains('sentinel rows received: 2'));
  });

  test('fails and keeps raw output when no sentinel row arrives', () async {
    final r = await run(sentinelPresent: true, dartOut: 'No issues found!\n');
    expect(r.code, 1);
    expect(r.out, contains('were not delivered'));
    expect(r.out, contains('No issues found!'));
  });

  test('retries when the first attempt has no sentinel rows', () async {
    final r = await run(
      sentinelPresent: true,
      firstAttemptOut: 'No issues found!\n',
      dartOut: '$sentinelRow\n$sentinelRow2\n',
      attempts: '3',
    );
    expect(r.code, 0, reason: r.out);
    expect(r.calls, ['analyze --format=machine', 'analyze --format=machine']);
    expect(r.out, contains('diagnostics missing (attempt 1/3)'));
    expect(r.out, contains('sentinel rows received: 2'));
  });

  test('gives up after SENTINEL_ATTEMPTS without sentinel rows', () async {
    final r = await run(
      sentinelPresent: true,
      dartOut: 'No issues found!\n',
      attempts: '2',
    );
    expect(r.code, 1);
    expect(r.calls.length, 2);
    expect(r.out, contains('(attempt 2/2)'));
  });

  test('counts an escaped Windows path as a sentinel row', () async {
    // `dart analyze --format=machine` escapes backslashes in the path field.
    final windowsRow = sentinelRow.replace(
      '/w/lib/zz_lint_sentinel/',
      r'C:\\w\\lib\\zz_lint_sentinel\\',
    );
    final r = await run(sentinelPresent: true, dartOut: '$windowsRow\n');
    expect(r.code, 0, reason: r.out);
    expect(r.out, contains('sentinel rows received: 1'));
  });

  test('a built-in diagnostic inside the sentinel file still fails', () async {
    const builtin =
        'INFO|LINT|UNUSED_IMPORT|/w/lib/zz_lint_sentinel/presentation/providers/zz.dart|1|1|5|m';
    final r = await run(
      sentinelPresent: true,
      dartOut: '$sentinelRow\n$builtin\n',
    );
    expect(r.code, 1);
    expect(r.out, contains('UNUSED_IMPORT'));
  });

  test('fails on a real finding even with the sentinel rows', () async {
    final r = await run(
      sentinelPresent: true,
      dartOut: '$sentinelRow\n$realRow\n$sentinelRow2\n',
    );
    expect(r.code, 1);
    expect(r.out, contains('reported 1 diagnostic(s)'));
    expect(r.out, contains('/lib/features/a/presentation/providers/a.dart'));
  });
}
