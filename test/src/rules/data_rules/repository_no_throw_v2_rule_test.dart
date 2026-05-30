import 'package:clean_architecture_linter/src/rules/data_rules/repository_no_throw_rule.dart';
import 'package:test/test.dart';

import '../../../v2_harness/analysis_rule_harness.dart';

void main() {
  group('RepositoryNoThrowRule v2', () {
    test('reports non-standard exception thrown in repository', () async {
      final result = await V2RuleHarness(rule: RepositoryNoThrowRule()).analyze(
        files: {
          'lib/features/todo/data/repositories/todo_repository_impl.dart': '''
abstract class TodoRepository {}

class TodoRepositoryImpl implements TodoRepository {
  Future<void> save() async {
    throw Exception('failed');
  }
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
          codeName: 'repository_no_throw',
          problemMessage:
              'Repository throws non-standard exception type "Exception". Consider using AppException types for consistent error handling.',
          correctionMessage:
              'Use AppException types (NotFoundException, ServerException, etc.) or let DataSource handle error conversion.',
        ),
      ]);
    });

    test('allows AppException and data layer exception types', () async {
      final result = await V2RuleHarness(rule: RepositoryNoThrowRule()).analyze(
        files: {
          'lib/features/todo/data/repositories/todo_repository_impl.dart': '''
class NotFoundException implements Exception {}
class CacheException implements Exception {}
abstract class TodoRepository {}

class TodoRepositoryImpl implements TodoRepository {
  Future<void> load() async {
    throw NotFoundException();
  }

  Future<void> cache() async {
    throw CacheException();
  }
}
''',
        },
        definingFile:
            'lib/features/todo/data/repositories/todo_repository_impl.dart',
      );

      result.expectNoDiagnostics();
    });

    test('allows rethrow in catch block', () async {
      final result = await V2RuleHarness(rule: RepositoryNoThrowRule()).analyze(
        files: {
          'lib/features/todo/data/repositories/todo_repository_impl.dart': '''
abstract class TodoRepository {}

class TodoRepositoryImpl implements TodoRepository {
  Future<void> save() async {
    try {
      throw Exception('failed');
    } catch (e) {
      rethrow;
    }
  }
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
          codeName: 'repository_no_throw',
          problemMessage:
              'Repository throws non-standard exception type "Exception". Consider using AppException types for consistent error handling.',
          correctionMessage:
              'Use AppException types (NotFoundException, ServerException, etc.) or let DataSource handle error conversion.',
        ),
      ]);
    });

    test('allows throws in private methods and constructors', () async {
      final result = await V2RuleHarness(rule: RepositoryNoThrowRule()).analyze(
        files: {
          'lib/features/todo/data/repositories/todo_repository_impl.dart': '''
abstract class TodoRepository {}

class TodoRepositoryImpl implements TodoRepository {
  TodoRepositoryImpl() {
    throw ArgumentError('invalid');
  }

  void _validate() {
    throw Exception('invalid');
  }
}
''',
        },
        definingFile:
            'lib/features/todo/data/repositories/todo_repository_impl.dart',
      );

      result.expectNoDiagnostics();
    });

    test('ignores non-repository classes', () async {
      final result = await V2RuleHarness(rule: RepositoryNoThrowRule()).analyze(
        files: {
          'lib/features/todo/data/services/todo_service.dart': '''
class TodoService {
  Future<void> save() async {
    throw Exception('failed');
  }
}
''',
        },
        definingFile: 'lib/features/todo/data/services/todo_service.dart',
      );

      result.expectNoDiagnostics();
    });

    test('ignores generated files', () async {
      final result = await V2RuleHarness(rule: RepositoryNoThrowRule()).analyze(
        files: {
          'lib/features/todo/data/repositories/todo_repository_impl.g.dart': '''
abstract class TodoRepository {}

class TodoRepositoryImpl implements TodoRepository {
  Future<void> save() async {
    throw Exception('failed');
  }
}
''',
        },
        definingFile:
            'lib/features/todo/data/repositories/todo_repository_impl.g.dart',
      );

      result.expectNoDiagnostics();
    });
  });
}
