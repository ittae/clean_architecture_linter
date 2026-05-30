import 'package:clean_architecture_linter/src/rules/domain_rules/usecase_no_result_return_rule.dart';
import 'package:test/test.dart';

import '../../../v2_harness/analysis_rule_harness.dart';

void main() {
  group('UseCaseNoResultReturnRule v2', () {
    test('reports dynamic method message', () async {
      final result = await V2RuleHarness(rule: UseCaseNoResultReturnRule())
          .analyze(
            files: {
              'lib/features/todo/domain/usecases/get_todo_usecase.dart': '''
class Result<T, E> {}
class Todo {}
class Failure {}

class GetTodoUseCase {
  Result<Todo, Failure> call() => Result<Todo, Failure>();
}
''',
            },
            definingFile:
                'lib/features/todo/domain/usecases/get_todo_usecase.dart',
          );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath:
              'lib/features/todo/domain/usecases/get_todo_usecase.dart',
          codeName: 'usecase_no_result_return',
          problemMessage:
              'UseCase method "call" should NOT return Result/Either (including typedef alias).',
        ),
      ]);
    });

    test('skips generated files', () async {
      final result = await V2RuleHarness(rule: UseCaseNoResultReturnRule())
          .analyze(
            files: {
              'lib/features/todo/domain/usecases/get_todo_usecase.freezed.dart':
                  '''
class Result<T, E> {}
class Todo {}
class Failure {}

class GetTodoUseCase {
  Result<Todo, Failure> call() => Result<Todo, Failure>();
}
''',
            },
            definingFile:
                'lib/features/todo/domain/usecases/get_todo_usecase.freezed.dart',
          );

      result.expectNoDiagnostics();
    });
  });
}
