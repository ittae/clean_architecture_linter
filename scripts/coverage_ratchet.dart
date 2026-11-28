// Line-coverage ratchet for scripts/verify.sh. It is local only: Codecov in
// CI stays informational and does not read the committed baseline.
//
// usage: dart scripts/coverage_ratchet.dart [--update]
// Exit 0: coverage is at or above the baseline, or --update wrote the baseline.
// Exit 1: coverage fell below the baseline.
// Exit 2: usage error, or an LCOV report or baseline that cannot be trusted.
import 'dart:convert';
import 'dart:io';

const _usage = 'usage: coverage_ratchet.dart [--update]';
const _pctTolerance = 0.005;

class LineCoverage {
  const LineCoverage({required this.found, required this.hit});

  final int found;
  final int hit;

  double get pct => hit * 100 / found;
  String get summary => '${pct.toStringAsFixed(2)}% ($hit/$found lines)';

  /// Compares the two ratios as integers, so rounding cannot hide a drop.
  bool isBelow(LineCoverage baseline) =>
      hit * baseline.found < baseline.hit * found;
}

/// Counts the `DA:<line>,<hits>` records of an LCOV report.
LineCoverage parseLcov(String lcov) {
  var found = 0;
  var hit = 0;
  for (final line in const LineSplitter().convert(lcov)) {
    if (!line.startsWith('DA:')) continue;
    final fields = line.substring(3).split(',');
    final hits = fields.length < 2 ? null : int.tryParse(fields[1]);
    if (int.tryParse(fields[0]) == null || hits == null || hits < 0) {
      throw FormatException('Malformed LCOV record: $line');
    }
    found++;
    if (hits > 0) hit++;
  }
  if (found == 0) throw const FormatException('LCOV report has no DA records');
  return LineCoverage(found: found, hit: hit);
}

/// Reads `{"lines": {"found": n, "hit": n, "pct": n}}`.
LineCoverage parseBaseline(String source) {
  final Object? decoded;
  try {
    decoded = jsonDecode(source);
  } on FormatException catch (e) {
    throw FormatException('Baseline is not JSON: ${e.message}');
  }
  final lines = decoded is Map ? decoded['lines'] : null;
  final found = lines is Map ? lines['found'] : null;
  final hit = lines is Map ? lines['hit'] : null;
  final pct = lines is Map ? lines['pct'] : null;
  if (found is! int || hit is! int || found <= 0 || hit < 0 || hit > found) {
    throw const FormatException(
      'Baseline needs integer lines.found > 0 and 0 <= lines.hit <= lines.found',
    );
  }
  final baseline = LineCoverage(found: found, hit: hit);
  if (pct is! num || (baseline.pct - pct).abs() > _pctTolerance) {
    throw FormatException(
      'Baseline lines.pct must be ${_roundedPct(baseline)}',
    );
  }
  return baseline;
}

String encodeBaseline(LineCoverage coverage) {
  final lines = {
    'found': coverage.found,
    'hit': coverage.hit,
    'pct': _roundedPct(coverage),
  };
  return '${const JsonEncoder.withIndent('  ').convert({'lines': lines})}\n';
}

double _roundedPct(LineCoverage coverage) =>
    double.parse(coverage.pct.toStringAsFixed(2));

int runRatchet(
  List<String> args,
  StringSink out,
  StringSink err, {
  String lcovPath = 'coverage/lcov.info',
  String baselinePath = '.github/coverage_baseline.json',
}) {
  if (args.any((arg) => arg != '--update')) {
    err.writeln(_usage);
    return 2;
  }
  final update = args.isNotEmpty;
  try {
    final current = parseLcov(File(lcovPath).readAsStringSync());
    if (update) {
      File(baselinePath).writeAsStringSync(encodeBaseline(current));
      out.writeln('coverage baseline written: ${current.summary}');
      return 0;
    }
    final baseline = parseBaseline(File(baselinePath).readAsStringSync());
    if (current.isBelow(baseline)) {
      err.writeln(
        'coverage FELL: ${current.summary} is below the baseline '
        '${baseline.summary}. Add tests, or re-run with --update and commit '
        'the baseline when the drop is intended.',
      );
      return 1;
    }
    out.writeln(
      'coverage ok: ${current.summary}, baseline ${baseline.summary}',
    );
    return 0;
  } on FormatException catch (e) {
    err.writeln('coverage ratchet: ${e.message}');
    return 2;
  } on FileSystemException catch (e) {
    err.writeln('coverage ratchet: ${e.message}: ${e.path}');
    return 2;
  }
}

void main(List<String> args) {
  exitCode = runRatchet(args, stdout, stderr);
}
