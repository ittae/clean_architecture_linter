import 'package:clean_architecture_linter/src/rules/cross_layer/boundary_crossing_rule.dart';
import 'package:test/test.dart';

import '../../../v2_harness/analysis_rule_harness.dart';

void main() {
  group('BoundaryCrossingRule', () {
    test('reports concrete implementation imports', () async {
      final result = await V2RuleHarness(rule: BoundaryCrossingRule()).analyze(
        files: {
          'lib/features/todo/domain/usecases/get_todo_usecase.dart': '''
import '../../data/repositories/todo_repository_impl.dart';

class GetTodoUseCase {}
''',
          'lib/features/todo/data/repositories/todo_repository_impl.dart': '''
class TodoRepositoryImpl {}
''',
        },
        definingFile: 'lib/features/todo/domain/usecases/get_todo_usecase.dart',
      );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath:
              'lib/features/todo/domain/usecases/get_todo_usecase.dart',
          codeName: 'boundary_crossing',
          line: 1,
        ),
      ]);
    });

    test('skips dependency injection files', () async {
      final result = await V2RuleHarness(rule: BoundaryCrossingRule()).analyze(
        files: {
          'lib/features/todo/presentation/providers/todo_providers.dart': '''
import '../../data/repositories/todo_repository_impl.dart';

final providers = <Object>[];
''',
          'lib/features/todo/data/repositories/todo_repository_impl.dart': '''
class TodoRepositoryImpl {}
''',
        },
        definingFile:
            'lib/features/todo/presentation/providers/todo_providers.dart',
      );

      result.expectNoDiagnostics();
    });
  });
}
