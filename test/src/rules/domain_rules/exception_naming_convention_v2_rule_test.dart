import 'package:clean_architecture_linter/src/rules/domain_rules/exception_naming_convention_rule.dart';
import 'package:test/test.dart';

import '../../../v2_harness/analysis_rule_harness.dart';

void main() {
  group('ExceptionNamingConventionRule v2', () {
    test('reports dynamic class and suggested name', () async {
      final result = await V2RuleHarness(rule: ExceptionNamingConventionRule())
          .analyze(
            files: {
              'lib/features/todo/domain/exceptions/todo_exceptions.dart': '''
class DataException implements Exception {}
''',
            },
            definingFile:
                'lib/features/todo/domain/exceptions/todo_exceptions.dart',
          );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath:
              'lib/features/todo/domain/exceptions/todo_exceptions.dart',
          codeName: 'exception_naming_convention',
          problemMessage:
              'Domain Exception "DataException" should have feature prefix',
        ),
      ]);
    });

    test('skips generated files', () async {
      final result = await V2RuleHarness(rule: ExceptionNamingConventionRule())
          .analyze(
            files: {
              'lib/features/todo/domain/exceptions/todo_exceptions.g.dart': '''
class DataException implements Exception {}
''',
            },
            definingFile:
                'lib/features/todo/domain/exceptions/todo_exceptions.g.dart',
          );

      result.expectNoDiagnostics();
    });
  });
}
