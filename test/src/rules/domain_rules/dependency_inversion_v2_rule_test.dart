import 'package:clean_architecture_linter/src/rules/domain_rules/dependency_inversion_rule.dart';
import 'package:test/test.dart';

import '../../../v2_harness/analysis_rule_harness.dart';

void main() {
  group('DependencyInversionRule v2', () {
    test('reports dynamic dependency messages', () async {
      final result = await V2RuleHarness(rule: DependencyInversionRule())
          .analyze(
            files: {
              'lib/features/todo/domain/usecases/get_todo_usecase.dart': '''
import '../../data/repositories/todo_repository_impl.dart';

class GetTodoUseCase {
  final TodoRepositoryImpl repository;
  GetTodoUseCase(this.repository);
}
''',
              'lib/features/todo/data/repositories/todo_repository_impl.dart':
                  '''
class TodoRepositoryImpl {}
''',
            },
            definingFile:
                'lib/features/todo/domain/usecases/get_todo_usecase.dart',
          );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath:
              'lib/features/todo/domain/usecases/get_todo_usecase.dart',
          codeName: 'dependency_inversion',
          problemMessage:
              'Domain layer importing from data layer: ../../data/repositories/todo_repository_impl.dart',
          correctionMessage:
              'Domain should not depend on data layer. Use dependency inversion.',
        ),
        const ExpectedV2Diagnostic(
          relativePath:
              'lib/features/todo/domain/usecases/get_todo_usecase.dart',
          codeName: 'dependency_inversion',
          problemMessage:
              'Field depends on concrete implementation: TodoRepositoryImpl',
          correctionMessage: 'Use abstract type for field declaration.',
        ),
      ]);
    });

    test('skips generated files', () async {
      final result = await V2RuleHarness(rule: DependencyInversionRule()).analyze(
        files: {
          'lib/features/todo/domain/usecases/get_todo_usecase.freezed.dart': '''
import '../../data/repositories/todo_repository_impl.dart';

class GetTodoUseCase {
  final TodoRepositoryImpl repository;
  GetTodoUseCase(this.repository);
}
''',
          'lib/features/todo/data/repositories/todo_repository_impl.dart': '''
class TodoRepositoryImpl {}
''',
        },
        definingFile:
            'lib/features/todo/domain/usecases/get_todo_usecase.freezed.dart',
      );

      result.expectNoDiagnostics();
    });
  });
}
