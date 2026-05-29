import 'package:clean_architecture_linter/src/rules/cross_layer/circular_dependency_rule.dart';
import 'package:test/test.dart';

import '../../../v2_harness/analysis_rule_harness.dart';

void main() {
  group('CircularDependencyRule', () {
    test('reports self circular imports', () async {
      final result = await V2RuleHarness(rule: CircularDependencyRule())
          .analyze(
            files: {
              'lib/features/todo/domain/a.dart': '''
import './a.dart';

class A {}
''',
            },
            definingFile: 'lib/features/todo/domain/a.dart',
          );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath: 'lib/features/todo/domain/a.dart',
          codeName: 'circular_dependency',
          line: 1,
        ),
      ]);
    });

    test('ignores acyclic imports', () async {
      final result = await V2RuleHarness(rule: CircularDependencyRule())
          .analyze(
            files: {
              'lib/features/todo/domain/a.dart': '''
import 'b.dart';

class A {}
''',
              'lib/features/todo/domain/b.dart': '''
class B {}
''',
            },
            definingFile: 'lib/features/todo/domain/a.dart',
          );

      result.expectNoDiagnostics();
    });
  });
}
