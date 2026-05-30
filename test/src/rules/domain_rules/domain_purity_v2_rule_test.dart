import 'package:clean_architecture_linter/src/rules/domain_rules/domain_purity_rule.dart';
import 'package:test/test.dart';

import '../../../v2_harness/analysis_rule_harness.dart';

void main() {
  group('DomainPurityRule v2', () {
    test('reports dynamic import violation message', () async {
      final result = await V2RuleHarness(rule: DomainPurityRule()).analyze(
        files: {
          'lib/features/todo/domain/entities/todo.dart': '''
import 'package:flutter/widgets.dart';

class Todo extends Widget {}
''',
        },
        definingFile: 'lib/features/todo/domain/entities/todo.dart',
      );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath: 'lib/features/todo/domain/entities/todo.dart',
          codeName: 'domain_purity',
          problemMessage:
              'Domain layer violation: UI Framework dependency detected',
        ),
        const ExpectedV2Diagnostic(
          relativePath: 'lib/features/todo/domain/entities/todo.dart',
          codeName: 'domain_purity',
          problemMessage:
              'Domain layer violation: Domain entities should not extend external framework classes (Widget)',
        ),
      ]);
    });

    test('skips generated files', () async {
      final result = await V2RuleHarness(rule: DomainPurityRule()).analyze(
        files: {
          'lib/features/todo/domain/entities/todo.g.dart': '''
import 'package:flutter/widgets.dart';

class Todo extends Widget {}
''',
        },
        definingFile: 'lib/features/todo/domain/entities/todo.g.dart',
      );

      result.expectNoDiagnostics();
    });
  });
}
