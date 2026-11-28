import 'dart:io';

import 'package:test/test.dart';

import '../../scripts/coverage_ratchet.dart';

const _lcov = '''
SF:lib/a.dart
DA:1,3
DA:2,0
LF:2
LH:1
end_of_record
SF:lib/b.dart
DA:7,1
DA:9,1
end_of_record
''';

String _baseline(Object? found, Object? hit, Object? pct) =>
    '{"lines": {"found": $found, "hit": $hit, "pct": $pct}}';

void main() {
  group('parseLcov', () {
    test('counts DA records and the ones with hits', () {
      final coverage = parseLcov(_lcov);
      expect([coverage.found, coverage.hit], [4, 3]);
      expect(coverage.pct, 75.0);
    });

    test('rejects a report without DA records', () {
      expect(
        () => parseLcov('SF:lib/a.dart\nend_of_record\n'),
        _fails('no DA'),
      );
    });

    for (final record in ['DA:1', 'DA:x,1', 'DA:1,y', 'DA:1,-1']) {
      test('rejects the malformed record $record', () {
        expect(() => parseLcov('$record\n'), _fails('Malformed LCOV'));
      });
    }
  });

  group('parseBaseline', () {
    test('reads found, hit and a matching pct', () {
      final baseline = parseBaseline(_baseline(200, 150, 75.0));
      expect([baseline.found, baseline.hit], [200, 150]);
    });

    const counts = 'integer lines.found > 0';
    const pct = 'lines.pct must be 75.0';
    final invalid = {
      'not JSON': ('lines', 'Baseline is not JSON'),
      'no lines object': ('{"percent": 75}', counts),
      'fractional found': (_baseline(200.5, 150, 74.81), counts),
      'zero found': (_baseline(0, 0, 0), counts),
      'negative hit': (_baseline(200, -1, -0.5), counts),
      'hit above found': (_baseline(200, 201, 100.5), counts),
      'pct that is not hit/found': (_baseline(200, 150, 80.0), pct),
      'pct that is not a number': (_baseline(200, 150, '"75"'), pct),
    };
    for (final MapEntry(:key, value: (source, message)) in invalid.entries) {
      test('rejects $key', () {
        expect(() => parseBaseline(source), _fails(message));
      });
    }
  });

  test('isBelow compares ratios, not totals', () {
    const baseline = LineCoverage(found: 200, hit: 150);
    bool below(int found, int hit) =>
        LineCoverage(found: found, hit: hit).isBelow(baseline);
    expect(below(4, 3), isFalse, reason: 'same ratio');
    expect(below(200, 151), isFalse, reason: 'above');
    expect(below(200, 149), isTrue, reason: 'one line below');
  });

  group('runRatchet', () {
    late Directory temp;
    late File baseline;
    final out = StringBuffer();
    final err = StringBuffer();

    setUp(() {
      temp = Directory.systemTemp.createTempSync('cal_ratchet_');
      File('${temp.path}/lcov.info').writeAsStringSync(_lcov);
      baseline = File('${temp.path}/baseline.json');
      out.clear();
      err.clear();
    });
    tearDown(() => temp.deleteSync(recursive: true));

    int run([List<String> args = const []]) => runRatchet(
      args,
      out,
      err,
      lcovPath: '${temp.path}/lcov.info',
      baselinePath: baseline.path,
    );

    test('exits 0 when coverage equals the baseline', () {
      baseline.writeAsStringSync(_baseline(4, 3, 75.0));
      expect(run(), 0);
      expect('$out', contains('coverage ok: 75.00% (3/4 lines)'));
    });

    test('exits 1 and names both numbers when coverage fell', () {
      baseline.writeAsStringSync(_baseline(4, 4, 100.0));
      expect(run(), 1);
      expect('$err', contains('75.00% (3/4 lines) is below the baseline 100'));
    });

    test('--update writes a baseline that the next run accepts', () {
      expect(run(['--update']), 0);
      final written = parseBaseline(baseline.readAsStringSync());
      expect([written.found, written.hit], [4, 3]);
      expect(run(), 0);
    });

    test('exits 2 when the baseline file is missing', () {
      expect(run(), 2);
      expect('$err', contains(baseline.path));
    });

    test('exits 2 on an invalid baseline instead of passing', () {
      baseline.writeAsStringSync(_baseline(0, 0, 0));
      expect(run(), 2);
    });

    test('exits 2 on an unknown argument', () {
      expect(run(['--nope']), 2);
      expect('$err', contains('usage:'));
    });
  });
}

Matcher _fails(String message) => throwsA(
  isA<FormatException>().having((e) => e.message, 'message', contains(message)),
);
