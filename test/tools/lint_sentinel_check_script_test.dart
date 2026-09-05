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
      final shim = File(p.join(bin.path, 'dart'))
        ..writeAsStringSync(
          '#!/bin/sh\necho "\$@" >> "$log"\ncat "${outFile.path}"\nexit $dartRc\n',
        );
      await Process.run('chmod', ['+x', shim.path]);
      final env = Map<String, String>.from(Platform.environment)
        ..['PATH'] = '${bin.path}:${Platform.environment['PATH']}'
        ..['SENTINEL_ATTEMPTS'] = '1';
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
