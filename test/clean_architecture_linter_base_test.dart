import 'package:analyzer/error/error.dart' as analyzer_error;
import 'package:clean_architecture_linter/src/clean_architecture_linter_base.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:test/test.dart';

void main() {
  group('toAnalyzerLintCode', () {
    test('preserves lint metadata for explicit severities', () {
      const code = LintCode(
        name: 'stable_bridge',
        problemMessage: 'Keep lint metadata intact.',
        correctionMessage: 'Use the analyzer bridge helper.',
        uniqueName: 'clean_architecture_linter.stable_bridge',
        errorSeverity: analyzer_error.ErrorSeverity.WARNING,
      );

      final converted = toAnalyzerLintCode(code);

      expect(converted.name, code.name);
      expect(converted.problemMessage, code.problemMessage);
      expect(converted.correctionMessage, code.correctionMessage);
      expect(converted.uniqueName, code.uniqueName);
      expect(converted.severity, analyzer_error.DiagnosticSeverity.WARNING);
    });

    test('uses INFO when the lint relies on the default severity', () {
      const code = LintCode(
        name: 'default_severity_bridge',
        problemMessage: 'Default severities should stay stable.',
      );

      final converted = toAnalyzerLintCode(code);

      expect(converted.uniqueName, code.uniqueName);
      expect(converted.severity, analyzer_error.DiagnosticSeverity.INFO);
    });

    test('reuses the converted analyzer lint code for repeated reports', () {
      const code = LintCode(
        name: 'cached_bridge',
        problemMessage: 'Avoid rebuilding analyzer lint codes.',
        errorSeverity: analyzer_error.ErrorSeverity.ERROR,
      );

      final first = toAnalyzerLintCode(code);
      final second = toAnalyzerLintCode(code);

      expect(second, same(first));
    });
  });
}
