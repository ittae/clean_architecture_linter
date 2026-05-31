import 'package:clean_architecture_linter/src/rules/data_rules/datasource_exception_types_rule.dart';
import 'package:test/test.dart';

import '../../../v2_harness/analysis_rule_harness.dart';

void main() {
  group('DataSourceExceptionTypesRule v2', () {
    test('reports generic exception in DataSource file', () async {
      final result = await V2RuleHarness(rule: DataSourceExceptionTypesRule())
          .analyze(
            files: {
              'lib/features/todo/data/datasources/todo_remote_datasource.dart':
                  '''
class TodoRemoteDataSource {
  Future<void> getTodo() async {
    throw Exception('boom');
  }
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
          codeName: 'datasource_exception_types',
          line: 3,
          problemMessage:
              'DataSource should NOT use "Exception". Use AppException types instead.',
          correctionMessage:
              'Use AppException types: NotFoundException, UnauthorizedException, ServerException, NetworkException, etc.',
        ),
      ]);
    });

    test('allows AppException and Data layer exceptions', () async {
      final result = await V2RuleHarness(rule: DataSourceExceptionTypesRule())
          .analyze(
            files: {
              'lib/features/todo/data/datasources/todo_remote_datasource.dart':
                  '''
class NotFoundException implements Exception {
  const NotFoundException();
}
class CacheException implements Exception {
  const CacheException();
}

class TodoRemoteDataSource {
  void throwNotFound() {
    throw const NotFoundException();
  }

  void throwCache() {
    throw const CacheException();
  }
}
''',
            },
            definingFile:
                'lib/features/todo/data/datasources/todo_remote_datasource.dart',
          );

      result.expectNoDiagnostics();
    });

    test('checks DataSource class even outside datasource file path', () async {
      final result = await V2RuleHarness(rule: DataSourceExceptionTypesRule())
          .analyze(
            files: {
              'lib/features/todo/data/remote/todo_api.dart': '''
class TodoRemoteDataSource {
  void getTodo() {
    throw StateError('bad');
  }
}
''',
            },
            definingFile: 'lib/features/todo/data/remote/todo_api.dart',
          );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath: 'lib/features/todo/data/remote/todo_api.dart',
          codeName: 'datasource_exception_types',
          problemMessage:
              'DataSource should NOT use "StateError". Use AppException types instead.',
        ),
      ]);
    });

    test('skips variable throws because type cannot be determined', () async {
      final result = await V2RuleHarness(rule: DataSourceExceptionTypesRule())
          .analyze(
            files: {
              'lib/features/todo/data/datasources/todo_remote_datasource.dart':
                  '''
class TodoRemoteDataSource {
  void getTodo(Object error) {
    throw error;
  }
}
''',
            },
            definingFile:
                'lib/features/todo/data/datasources/todo_remote_datasource.dart',
          );

      result.expectNoDiagnostics();
    });

    test('ignores non-DataSource code', () async {
      final result = await V2RuleHarness(rule: DataSourceExceptionTypesRule())
          .analyze(
            files: {
              'lib/features/todo/data/repositories/todo_repository_impl.dart':
                  '''
class TodoRepositoryImpl {
  void getTodo() {
    throw Exception('repository rule owns this');
  }
}
''',
            },
            definingFile:
                'lib/features/todo/data/repositories/todo_repository_impl.dart',
          );

      result.expectNoDiagnostics();
    });

    test('ignores generated files', () async {
      final result = await V2RuleHarness(rule: DataSourceExceptionTypesRule())
          .analyze(
            files: {
              'lib/features/todo/data/datasources/todo_remote_datasource.g.dart':
                  '''
class TodoRemoteDataSource {
  void getTodo() {
    throw Exception('generated');
  }
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
