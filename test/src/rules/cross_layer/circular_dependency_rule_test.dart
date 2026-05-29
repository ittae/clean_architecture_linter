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

    test('reports indirect file cycles across analyzed libraries', () async {
      final result = await V2RuleHarness(rule: CircularDependencyRule())
          .analyze(
            files: {
              'lib/features/todo/domain/a.dart': '''
import 'b.dart';

class A {}
''',
              'lib/features/todo/domain/b.dart': '''
import 'c.dart';

class B {}
''',
              'lib/features/todo/domain/c.dart': '''
import 'a.dart';

class C {}
''',
            },
            definingFile: 'lib/features/todo/domain/a.dart',
            additionalDefiningFiles: const [
              'lib/features/todo/domain/b.dart',
              'lib/features/todo/domain/c.dart',
            ],
          );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath: 'lib/features/todo/domain/c.dart',
          codeName: 'circular_dependency',
          line: 1,
        ),
      ]);
    });

    test('reports layer-level cycles', () async {
      final result = await V2RuleHarness(rule: CircularDependencyRule())
          .analyze(
            files: {
              'lib/features/todo/domain/entity.dart': '''
import '../data/repository.dart';

class Entity {}
''',
              'lib/features/todo/data/repository.dart': '''
import '../presentation/page.dart';

class Repository {}
''',
              'lib/features/todo/presentation/page.dart': '''
import '../domain/entity.dart';

class Page {}
''',
            },
            definingFile: 'lib/features/todo/domain/entity.dart',
            additionalDefiningFiles: const [
              'lib/features/todo/data/repository.dart',
              'lib/features/todo/presentation/page.dart',
            ],
          );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath: 'lib/features/todo/presentation/page.dart',
          codeName: 'circular_dependency',
          line: 1,
        ),
      ]);
    });

    test(
      'resolves package imports without assuming root folder name',
      () async {
        final result = await V2RuleHarness(rule: CircularDependencyRule())
            .analyze(
              files: {
                'lib/features/todo/domain/a.dart': '''
import 'package:cal_v2_harness_app/features/todo/data/b.dart';

class A {}
''',
                'lib/features/todo/data/b.dart': '''
import 'package:cal_v2_harness_app/features/todo/domain/a.dart';

class B {}
''',
              },
              definingFile: 'lib/features/todo/domain/a.dart',
              additionalDefiningFiles: const ['lib/features/todo/data/b.dart'],
            );

        result.expectDiagnostics([
          const ExpectedV2Diagnostic(
            relativePath: 'lib/features/todo/data/b.dart',
            codeName: 'circular_dependency',
            line: 1,
          ),
        ]);
      },
    );
  });
}
