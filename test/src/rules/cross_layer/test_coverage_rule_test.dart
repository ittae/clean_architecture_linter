import 'package:clean_architecture_linter/src/rules/cross_layer/test_coverage_rule.dart';
import 'package:test/test.dart';

import '../../../v2_harness/analysis_rule_harness.dart';

void main() {
  group('TestCoverageRule', () {
    test('reports missing tests for UseCases', () async {
      final result = await V2RuleHarness(rule: TestCoverageRule()).analyze(
        files: {
          'lib/features/todo/domain/usecases/get_todo_usecase.dart': '''
class GetTodoUseCase {
  void call() {}
}
''',
        },
        definingFile: 'lib/features/todo/domain/usecases/get_todo_usecase.dart',
      );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath:
              'lib/features/todo/domain/usecases/get_todo_usecase.dart',
          codeName: 'clean_architecture_linter_require_test',
          line: 1,
        ),
      ]);
    });

    test('allows existing expected test file', () async {
      final result = await V2RuleHarness(rule: TestCoverageRule()).analyze(
        files: {
          'lib/features/todo/domain/usecases/get_todo_usecase.dart': '''
class GetTodoUseCase {
  void call() {}
}
''',
          'test/features/todo/domain/usecases/get_todo_usecase_test.dart': '''
void main() {}
''',
        },
        definingFile: 'lib/features/todo/domain/usecases/get_todo_usecase.dart',
      );

      result.expectNoDiagnostics();
    });

    test('honors disabled component flags', () async {
      final result =
          await V2RuleHarness(
            rule: TestCoverageRule(checkUsecases: false),
          ).analyze(
            files: {
              'lib/features/todo/domain/usecases/get_todo_usecase.dart': '''
class GetTodoUseCase {
  void call() {}
}
''',
            },
            definingFile:
                'lib/features/todo/domain/usecases/get_todo_usecase.dart',
          );

      result.expectNoDiagnostics();
    });

    test('converts relative lib paths to test paths', () {
      expect(
        TestCoverageRule.expectedTestFilePathForTesting(
          'lib/features/todo/domain/usecases/get_todo_usecase.dart',
        ),
        'test/features/todo/domain/usecases/get_todo_usecase_test.dart',
      );
    });

    test('excludes generated files', () async {
      final result = await V2RuleHarness(rule: TestCoverageRule()).analyze(
        files: {
          'lib/features/todo/presentation/providers/schedule_notifier.g.dart':
              '''
class ScheduleNotifier {
  void build() {}
}
''',
        },
        definingFile:
            'lib/features/todo/presentation/providers/schedule_notifier.g.dart',
      );

      result.expectNoDiagnostics();
    });

    test('reports missing tests for repository implementations', () async {
      final result = await V2RuleHarness(rule: TestCoverageRule()).analyze(
        files: {
          'lib/features/todo/data/repositories/todo_repository_impl.dart': '''
class TodoRepositoryImpl {}
''',
        },
        definingFile:
            'lib/features/todo/data/repositories/todo_repository_impl.dart',
      );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath:
              'lib/features/todo/data/repositories/todo_repository_impl.dart',
          codeName: 'clean_architecture_linter_require_test',
          line: 1,
        ),
      ]);
    });

    test('reports missing tests for data sources', () async {
      final result = await V2RuleHarness(rule: TestCoverageRule()).analyze(
        files: {
          'lib/features/todo/data/datasources/todo_remote_datasource.dart': '''
class TodoRemoteDataSource {}
''',
        },
        definingFile:
            'lib/features/todo/data/datasources/todo_remote_datasource.dart',
      );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath:
              'lib/features/todo/data/datasources/todo_remote_datasource.dart',
          codeName: 'clean_architecture_linter_require_test',
          line: 1,
        ),
      ]);
    });

    test('reports missing tests for notifiers', () async {
      final result = await V2RuleHarness(rule: TestCoverageRule()).analyze(
        files: {
          'lib/features/todo/presentation/providers/todo_notifier.dart': '''
class TodoNotifier {}
''',
        },
        definingFile:
            'lib/features/todo/presentation/providers/todo_notifier.dart',
      );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath:
              'lib/features/todo/presentation/providers/todo_notifier.dart',
          codeName: 'clean_architecture_linter_require_test',
          line: 1,
        ),
      ]);
    });
  });
}
