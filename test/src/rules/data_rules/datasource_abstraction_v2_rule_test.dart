import 'package:clean_architecture_linter/src/rules/data_rules/datasource_abstraction_rule.dart';
import 'package:test/test.dart';

import '../../../v2_harness/analysis_rule_harness.dart';

void main() {
  group('DataSourceAbstractionRule v2', () {
    test('reports concrete DataSource without interface', () async {
      final result = await V2RuleHarness(rule: DataSourceAbstractionRule())
          .analyze(
            files: {
              'lib/features/todo/data/datasources/todo_remote_datasource.dart':
                  '''
class TodoRemoteDataSource {
  Future<TodoModel> getTodo() async => TodoModel();
}

class TodoModel {}
''',
            },
            definingFile:
                'lib/features/todo/data/datasources/todo_remote_datasource.dart',
          );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath:
              'lib/features/todo/data/datasources/todo_remote_datasource.dart',
          codeName: 'datasource_abstraction',
          line: 1,
          problemMessage:
              'Concrete DataSource "TodoRemoteDataSource" should implement an abstract interface for testability',
          correctionMessage:
              'Create abstract DataSource interface: TodoRemoteDataSource or add test file',
        ),
      ]);
    });

    test('accepts implementation with DataSource interface', () async {
      final result = await V2RuleHarness(rule: DataSourceAbstractionRule())
          .analyze(
            files: {
              'lib/features/todo/data/datasources/todo_remote_datasource.dart':
                  '''
abstract class TodoRemoteDataSource {
  Future<TodoModel> getTodo();
}

class TodoRemoteDataSourceImpl implements TodoRemoteDataSource {
  @override
  Future<TodoModel> getTodo() async => TodoModel();
}

class TodoModel {}
''',
            },
            definingFile:
                'lib/features/todo/data/datasources/todo_remote_datasource.dart',
          );

      result.expectNoDiagnostics();
    });

    test('accepts concrete DataSource when test file exists', () async {
      final result = await V2RuleHarness(rule: DataSourceAbstractionRule()).analyze(
        files: {
          'lib/features/todo/data/datasources/todo_remote_datasource.dart': '''
class TodoRemoteDataSource {
  Future<TodoModel> getTodo() async => TodoModel();
}

class TodoModel {}
''',
          'test/features/todo/data/datasources/todo_remote_datasource_test.dart':
              '''
void main() {}
''',
        },
        definingFile:
            'lib/features/todo/data/datasources/todo_remote_datasource.dart',
      );

      result.expectNoDiagnostics();
    });

    test('reports DataSource in domain layer', () async {
      final result = await V2RuleHarness(rule: DataSourceAbstractionRule())
          .analyze(
            files: {
              'lib/features/todo/domain/datasources/todo_datasource.dart': '''
abstract class TodoDataSource {
  Future<TodoModel> getTodo();
}

class TodoModel {}
''',
            },
            definingFile:
                'lib/features/todo/domain/datasources/todo_datasource.dart',
          );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath:
              'lib/features/todo/domain/datasources/todo_datasource.dart',
          codeName: 'datasource_abstraction',
          line: 1,
          problemMessage:
              'DataSource "TodoDataSource" should be in Data Layer, not Domain Layer',
          correctionMessage:
              'Move DataSource to data/datasources/. Domain should only depend on Repository abstractions.',
        ),
      ]);
    });

    test('reports DataSource method returning Entity', () async {
      final result = await V2RuleHarness(rule: DataSourceAbstractionRule())
          .analyze(
            files: {
              'lib/features/todo/data/datasources/todo_remote_datasource.dart':
                  '''
abstract class TodoRemoteDataSource {
  Future<TodoEntity> getTodo();
  Future<TodoModel> getTodoModel();
}

class TodoEntity {}
class TodoModel {}
''',
            },
            definingFile:
                'lib/features/todo/data/datasources/todo_remote_datasource.dart',
          );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath:
              'lib/features/todo/data/datasources/todo_remote_datasource.dart',
          codeName: 'datasource_abstraction',
          line: 2,
          problemMessage:
              'DataSource method "getTodo" returns Entity. DataSource should return Model.',
          correctionMessage:
              'Change return type to Model. DataSource works with Models, Repository converts to Entities.',
        ),
      ]);
    });

    test('skips private methods and persistence entities', () async {
      final result = await V2RuleHarness(rule: DataSourceAbstractionRule())
          .analyze(
            files: {
              'lib/features/todo/data/datasources/todo_remote_datasource.dart':
                  '''
abstract class TodoRemoteDataSource {
  Future<TodoEntity> _loadEntity();
  Future<Box<TodoEntity>> openBox();
}

class TodoEntity {}
class Box<T> {}
''',
            },
            definingFile:
                'lib/features/todo/data/datasources/todo_remote_datasource.dart',
          );

      result.expectNoDiagnostics();
    });

    test('ignores generated files', () async {
      final result = await V2RuleHarness(rule: DataSourceAbstractionRule()).analyze(
        files: {
          'lib/features/todo/data/datasources/todo_remote_datasource.g.dart':
              '''
class TodoRemoteDataSource {
  Future<TodoEntity> getTodo() async => TodoEntity();
}

class TodoEntity {}
''',
        },
        definingFile:
            'lib/features/todo/data/datasources/todo_remote_datasource.g.dart',
      );

      result.expectNoDiagnostics();
    });
  });
}
