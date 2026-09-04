import 'dart:io';

import 'package:clean_architecture_linter/src/rules/presentation_rules/presentation_no_throw_rule.dart';
import 'package:clean_architecture_linter/src/rules/presentation_rules/riverpod_keep_alive_rule.dart';
import 'package:test/test.dart';

import '../v2_harness/analysis_rule_harness.dart';

/// Contract for tools/lint_sentinel/zz_lint_sentinel_provider.dart.
///
/// Consumers copy that file to lib/zz_lint_sentinel/presentation/providers/
/// and gate CI on it reporting riverpod_keep_alive and presentation_no_throw.
/// If a heuristic change (a new keep-alive keyword, a path-layout change)
/// stops either diagnostic, every consumer gate would fail with a misleading
/// "plugin diagnostics were not delivered" message. This test pins the
/// contract on the rules themselves, independent of the dart analyze race.
void main() {
  const consumerPath =
      'lib/zz_lint_sentinel/presentation/providers/zz_lint_sentinel_provider.dart';
  final sentinelSource = File(
    'tools/lint_sentinel/zz_lint_sentinel_provider.dart',
  ).readAsStringSync();

  group('lint sentinel fixture', () {
    test('is reported by riverpod_keep_alive exactly once', () async {
      final result = await V2RuleHarness(rule: RiverpodKeepAliveRule()).analyze(
        files: {consumerPath: sentinelSource},
        definingFile: consumerPath,
      );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath: consumerPath,
          codeName: 'riverpod_keep_alive',
        ),
      ]);
    });

    test('is reported by presentation_no_throw exactly once', () async {
      final result = await V2RuleHarness(rule: PresentationNoThrowRule())
          .analyze(
            files: {consumerPath: sentinelSource},
            definingFile: consumerPath,
          );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath: consumerPath,
          codeName: 'presentation_no_throw',
        ),
      ]);
    });
  });
}
