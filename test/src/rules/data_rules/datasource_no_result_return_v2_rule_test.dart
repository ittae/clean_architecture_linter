import 'package:clean_architecture_linter/src/rules/data_rules/datasource_no_result_return_rule.dart';
import 'package:test/test.dart';

import '../../../v2_harness/analysis_rule_harness.dart';

void main() {
  group('DataSourceNoResultReturnRule v2', () {
    test('reports Result return type with dynamic method context', () async {
      final result = await V2RuleHarness(rule: DataSourceNoResultReturnRule())
          .analyze(
            files: {
              'lib/features/todo/data/datasources/todo_remote_datasource.dart':
                  '''
class Result<T, E> {}
class TodoModel {}
class Failure {}

class TodoRemoteDataSource {
  Future<Result<TodoModel, Failure>> getTodo() async => Result();
}
''',
            },
            definingFile:
                'lib/features/todo/data/datasources/todo_remote_datasource.dart',
          );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath:
              'lib/features/todo/data/datasources/todo_remote_datasource.dart',
          codeName: 'datasource_no_result_return',
          line: 6,
          problemMessage:
              'DataSource method "getTodo" should NOT return Result. DataSource should throw exceptions instead.',
          correctionMessage:
              'Remove Result wrapper and throw exceptions for errors:\n'
              '  Before: Future<Result<TodoModel, Failure>> getTodo()\n'
              '  After:  Future<TodoModel> getTodo() // throws AppException\n\n'
              'Exceptions pass through to AsyncValue.guard(). See UNIFIED_ERROR_GUIDE.md',
        ),
      ]);
    });

    test('reports typedef alias resolving to Result', () async {
      final result = await V2RuleHarness(rule: DataSourceNoResultReturnRule())
          .analyze(
            files: {
              'lib/features/todo/data/datasources/todo_remote_datasource.dart':
                  '''
class Result<T, E> {}
class TodoModel {}
class Failure {}
typedef DataOutcome<T> = Result<T, Failure>;

class TodoRemoteDataSource {
  Future<DataOutcome<TodoModel>> getTodo() async => Result();
}
''',
            },
            definingFile:
                'lib/features/todo/data/datasources/todo_remote_datasource.dart',
          );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath:
              'lib/features/todo/data/datasources/todo_remote_datasource.dart',
          codeName: 'datasource_no_result_return',
          problemMessage:
              'DataSource method "getTodo" should NOT return Result. DataSource should throw exceptions instead.',
        ),
      ]);
    });

    test('accepts direct model return type', () async {
      final result = await V2RuleHarness(rule: DataSourceNoResultReturnRule())
          .analyze(
            files: {
              'lib/features/todo/data/datasources/todo_remote_datasource.dart':
                  '''
class TodoModel {}

class TodoRemoteDataSource {
  Future<TodoModel> getTodo() async => TodoModel();
}
''',
            },
            definingFile:
                'lib/features/todo/data/datasources/todo_remote_datasource.dart',
          );

      result.expectNoDiagnostics();
    });

    test('ignores non-DataSource classes', () async {
      final result = await V2RuleHarness(rule: DataSourceNoResultReturnRule())
          .analyze(
            files: {
              'lib/features/todo/data/repositories/todo_repository_impl.dart':
                  '''
class Result<T, E> {}
class TodoModel {}
class Failure {}

class TodoRepositoryImpl {
  Future<Result<TodoModel, Failure>> getTodo() async => Result();
}
''',
            },
            definingFile:
                'lib/features/todo/data/repositories/todo_repository_impl.dart',
          );

      result.expectNoDiagnostics();
    });

    test('ignores generated files', () async {
      final result = await V2RuleHarness(rule: DataSourceNoResultReturnRule())
          .analyze(
            files: {
              'lib/features/todo/data/datasources/todo_remote_datasource.g.dart':
                  '''
class Result<T, E> {}
class TodoModel {}
class Failure {}

class TodoRemoteDataSource {
  Future<Result<TodoModel, Failure>> getTodo() async => Result();
}
''',
            },
            definingFile:
                'lib/features/todo/data/datasources/todo_remote_datasource.g.dart',
          );

      result.expectNoDiagnostics();
    });
  });
}
