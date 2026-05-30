import 'package:clean_architecture_linter/src/rules/cross_layer/allowed_instance_variables_rule.dart';
import 'package:test/test.dart';

import '../../../v2_harness/analysis_rule_harness.dart';

void main() {
  group('AllowedInstanceVariablesRule', () {
    test('reports direct DataSource dependencies in UseCases', () async {
      final result = await V2RuleHarness(rule: AllowedInstanceVariablesRule())
          .analyze(
            files: {
              'lib/features/todo/domain/usecases/get_todo_usecase.dart': '''
class TodoRemoteDataSource {}

class GetTodoUseCase {
  final TodoRemoteDataSource dataSource;

  const GetTodoUseCase(this.dataSource);
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
          codeName: 'allowed_instance_variables',
          line: 4,
          problemMessage:
              'UseCase "GetTodoUseCase" has invalid instance variable "dataSource" of type "TodoRemoteDataSource".',
        ),
      ]);
    });

    test('allows repository infrastructure dependencies', () async {
      final result = await V2RuleHarness(rule: AllowedInstanceVariablesRule())
          .analyze(
            files: {
              'lib/features/todo/data/repositories/todo_repository_impl.dart':
                  '''
class TodoRemoteDataSource {}
class Dio {}

class TodoRepositoryImpl {
  final TodoRemoteDataSource remoteDataSource;
  final Dio dio;

  const TodoRepositoryImpl(this.remoteDataSource, this.dio);
}
''',
            },
            definingFile:
                'lib/features/todo/data/repositories/todo_repository_impl.dart',
          );

      result.expectNoDiagnostics();
    });

    test('allows datasource infrastructure dependencies', () async {
      final result = await V2RuleHarness(rule: AllowedInstanceVariablesRule())
          .analyze(
            files: {
              'lib/features/todo/data/datasources/todo_remote_data_source.dart':
                  '''
class Dio {}

class TodoRemoteDataSource {
  Dio client;
}
''',
            },
            definingFile:
                'lib/features/todo/data/datasources/todo_remote_data_source.dart',
          );

      result.expectNoDiagnostics();
    });

    test('reports mutable business state in DataSources', () async {
      final result = await V2RuleHarness(rule: AllowedInstanceVariablesRule())
          .analyze(
            files: {
              'lib/features/todo/data/datasources/todo_remote_data_source.dart':
                  '''
class TodoEntity {}

class TodoRemoteDataSource {
  TodoEntity cachedEntity;
}
''',
            },
            definingFile:
                'lib/features/todo/data/datasources/todo_remote_data_source.dart',
          );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath:
              'lib/features/todo/data/datasources/todo_remote_data_source.dart',
          codeName: 'allowed_instance_variables',
          line: 4,
        ),
      ]);
    });

    test('reports mutable repository state', () async {
      final result = await V2RuleHarness(rule: AllowedInstanceVariablesRule())
          .analyze(
            files: {
              'lib/features/todo/data/repositories/todo_repository_impl.dart':
                  '''
class TodoRepositoryImpl {
  int cacheHits = 0;
}
''',
            },
            definingFile:
                'lib/features/todo/data/repositories/todo_repository_impl.dart',
          );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath:
              'lib/features/todo/data/repositories/todo_repository_impl.dart',
          codeName: 'allowed_instance_variables',
          line: 2,
        ),
      ]);
    });

    test('reports disallowed datasource domain dependencies', () async {
      final result = await V2RuleHarness(rule: AllowedInstanceVariablesRule())
          .analyze(
            files: {
              'lib/features/todo/data/datasources/todo_remote_data_source.dart':
                  '''
class UserRepository {}

class TodoRemoteDataSource {
  final UserRepository repository;

  const TodoRemoteDataSource(this.repository);
}
''',
            },
            definingFile:
                'lib/features/todo/data/datasources/todo_remote_data_source.dart',
          );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath:
              'lib/features/todo/data/datasources/todo_remote_data_source.dart',
          codeName: 'allowed_instance_variables',
          line: 4,
        ),
      ]);
    });
  });
}
