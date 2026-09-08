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
  const siblingRow =
      'INFO|STATIC_WARNING|RIVERPOD_KEEP_ALIVE|/w/lib/zz_lint_sentinel/presentation/providers/other.dart|3|1|5|m';
  const sentinelFile = '/w/lib/zz_lint_sentinel/presentation/providers/zz.dart';

  Future<({int code, String out, List<String> calls})> run({
    required bool sentinelPresent,
    required String dartOut,
    int dartRc = 0,
    String? firstAttemptOut,
    String attempts = '1',
    Map<String, String> extraEnv = const {},
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
        ..['SENTINEL_BACKOFF'] = '0'
        ..addAll(extraEnv);
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
    final windowsRow = sentinelRow.replaceFirst(
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

  test('SENTINEL_REQUIRE_ALL passes when every code is delivered', () async {
    final r = await run(
      sentinelPresent: true,
      dartOut: '$sentinelRow\n$sentinelRow2\n',
      extraEnv: {'SENTINEL_REQUIRE_ALL': '1'},
    );
    expect(r.code, 0, reason: r.out);
    expect(r.out, contains('sentinel rows received: 2'));
  });

  test(
    'SENTINEL_REQUIRE_ALL retries then fails when a code never arrives',
    () async {
      final r = await run(
        sentinelPresent: true,
        // Only RIVERPOD_KEEP_ALIVE ever shows up; PRESENTATION_NO_THROW
        // never does, on every attempt.
        dartOut: '$sentinelRow\n',
        attempts: '2',
        extraEnv: {'SENTINEL_REQUIRE_ALL': '1'},
      );
      expect(r.code, 1);
      expect(r.calls.length, 2, reason: r.out);
      expect(r.out, contains('PRESENTATION_NO_THROW'));
      expect(r.out, contains('(attempt 1/2)'));
    },
  );

  test(
    'SENTINEL_FILE still passes an ordinary run at the exact path',
    () async {
      final r = await run(
        sentinelPresent: true,
        dartOut: '$sentinelRow\n$sentinelRow2\n',
        extraEnv: {'SENTINEL_FILE': sentinelFile},
      );
      expect(r.code, 0, reason: r.out);
      expect(r.out, contains('sentinel rows received: 2'));
    },
  );

  test(
    'SENTINEL_FILE fails when a same-code row comes from a sibling file',
    () async {
      final r = await run(
        sentinelPresent: true,
        dartOut: '$sentinelRow\n$siblingRow\n',
        extraEnv: {'SENTINEL_FILE': sentinelFile},
      );
      expect(r.code, 1);
      expect(r.out, contains('other.dart'));
    },
  );

  test(
    'SENTINEL_FILE also matches a shorter SENTINEL_DIR-style relative path',
    () async {
      final r = await run(
        sentinelPresent: true,
        dartOut: '$sentinelRow\n$sentinelRow2\n',
        extraEnv: {
          'SENTINEL_FILE':
              'lib/zz_lint_sentinel/presentation/providers/zz.dart',
        },
      );
      expect(r.code, 0, reason: r.out);
      expect(r.out, contains('sentinel rows received: 2'));
    },
  );

  test('SENTINEL_FILE matches a single-backslash Windows path against an '
      'escaped machine-format row', () async {
    // `dart analyze --format=machine` escapes the row's own backslashes
    // (doubled), but a Windows SENTINEL_FILE value would naturally arrive
    // with single backslashes; both must normalise to the same thing.
    final windowsRow = sentinelRow.replaceFirst(
      '/w/lib/zz_lint_sentinel/',
      r'C:\\w\\lib\\zz_lint_sentinel\\',
    );
    final r = await run(
      sentinelPresent: true,
      dartOut: '$windowsRow\n',
      extraEnv: {
        'SENTINEL_FILE':
            r'C:\w\lib\zz_lint_sentinel\presentation\providers\zz.dart',
      },
    );
    expect(r.code, 0, reason: r.out);
    expect(r.out, contains('sentinel rows received: 1'));
  });

  test('SENTINEL_FILE matches a literal copy-paste of the doubled-backslash '
      'machine-format path', () async {
    // A user who copies SENTINEL_FILE straight out of `dart analyze
    // --format=machine` output gets the doubled-backslash form the CLI
    // itself prints, not a single-backslash path. Both the row and
    // SENTINEL_FILE must normalise identically regardless of how many
    // backslashes either one started with.
    const windowsPath =
        r'C:\\w\\lib\\zz_lint_sentinel\\presentation\\providers\\zz.dart';
    final windowsRow = sentinelRow.replaceFirst(
      '/w/lib/zz_lint_sentinel/presentation/providers/zz.dart',
      windowsPath,
    );
    final r = await run(
      sentinelPresent: true,
      dartOut: '$windowsRow\n',
      extraEnv: {'SENTINEL_FILE': windowsPath},
    );
    expect(r.code, 0, reason: r.out);
    expect(r.out, contains('sentinel rows received: 1'));
  });

  test(
    'SENTINEL_REQUIRE_ALL and SENTINEL_FILE compose: both codes at the exact '
    'file pass require-all, but a sibling decoy still fails as a real finding',
    () async {
      final r = await run(
        sentinelPresent: true,
        dartOut: '$sentinelRow\n$sentinelRow2\n$siblingRow\n',
        extraEnv: {'SENTINEL_REQUIRE_ALL': '1', 'SENTINEL_FILE': sentinelFile},
      );
      expect(r.code, 1);
      expect(r.out, contains('sentinel rows received: 2'));
      expect(r.out, contains('other.dart'));
    },
  );
}
