import 'package:clean_architecture_linter/src/rules/data_rules/repository_pass_through_rule.dart';
import 'package:test/test.dart';

import '../../../v2_harness/analysis_rule_harness.dart';

void main() {
  group('RepositoryPassThroughRule v2', () {
    test('reports repository method returning entity without Future', () async {
      final result = await V2RuleHarness(rule: RepositoryPassThroughRule())
          .analyze(
            files: {
              'lib/features/todo/data/repositories/todo_repository_impl.dart':
                  '''
class Todo {}
abstract class TodoRepository {}

class TodoRepositoryImpl implements TodoRepository {
  Todo getTodo() => Todo();
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
          codeName: 'repository_pass_through',
          problemMessage:
              'Repository method "getTodo" should return Future<Todo>.',
          correctionMessage: 'Wrap in Future: Future<Todo>',
        ),
      ]);
    });

    test('reports Future Result return type', () async {
      final result = await V2RuleHarness(rule: RepositoryPassThroughRule())
          .analyze(
            files: {
              'lib/features/todo/data/repositories/todo_repository_impl.dart':
                  '''
class Todo {}
class Failure {}
class Result<T, E> {}
abstract class TodoRepository {}

class TodoRepositoryImpl implements TodoRepository {
  Future<Result<Todo, Failure>> getTodo() async => Result<Todo, Failure>();
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
          codeName: 'repository_pass_through',
          problemMessage:
              'Repository should NOT use Result pattern. Use pass-through pattern instead.',
          correctionMessage:
              'Return Future<Entity> directly. Let errors pass through to AsyncValue.guard().',
        ),
      ]);
    });

    test('reports direct Either return type as Result pattern', () async {
      final result = await V2RuleHarness(rule: RepositoryPassThroughRule())
          .analyze(
            files: {
              'lib/features/todo/data/repositories/todo_repository_impl.dart':
                  '''
class Todo {}
class Failure {}
class Either<L, R> {}
abstract class TodoRepository {}

class TodoRepositoryImpl implements TodoRepository {
  Either<Failure, Todo> getTodo() => Either<Failure, Todo>();
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
          codeName: 'repository_pass_through',
          problemMessage:
              'Repository should NOT use Result pattern. Use pass-through pattern instead.',
          correctionMessage:
              'Return Future<Entity> directly. Let errors pass through to AsyncValue.guard().',
        ),
      ]);
    });

    test('reports catch block returning converted fallback', () async {
      final result = await V2RuleHarness(rule: RepositoryPassThroughRule())
          .analyze(
            files: {
              'lib/features/todo/data/repositories/todo_repository_impl.dart':
                  '''
class Todo {}
abstract class TodoRepository {}

class TodoRepositoryImpl implements TodoRepository {
  Future<Todo> getTodo() async {
    try {
      return Todo();
    } catch (e) {
      return Todo();
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
          codeName: 'repository_pass_through',
          problemMessage:
              'Repository should not handle/re-wrap exceptions. Use pass-through.',
          correctionMessage:
              'Do not convert/wrap exceptions in catch. Prefer logging + rethrow (or let it pass through).',
        ),
      ]);
    });

    test('reports nested catch block fallback return', () async {
      final result = await V2RuleHarness(rule: RepositoryPassThroughRule())
          .analyze(
            files: {
              'lib/features/todo/data/repositories/todo_repository_impl.dart':
                  '''
class Todo {}
abstract class TodoRepository {}

class TodoRepositoryImpl implements TodoRepository {
  Future<Todo> getTodo(bool useFallback) async {
    try {
      return Todo();
    } catch (e) {
      if (useFallback) {
        return Todo();
      }
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
          codeName: 'repository_pass_through',
          problemMessage:
              'Repository should not handle/re-wrap exceptions. Use pass-through.',
          correctionMessage:
              'Do not convert/wrap exceptions in catch. Prefer logging + rethrow (or let it pass through).',
        ),
      ]);
    });

    test('reports nested catch block exception conversion', () async {
      final result = await V2RuleHarness(rule: RepositoryPassThroughRule())
          .analyze(
            files: {
              'lib/features/todo/data/repositories/todo_repository_impl.dart':
                  '''
class Todo {}
class RepositoryException implements Exception {
  RepositoryException(Object error);
}
abstract class TodoRepository {}

class TodoRepositoryImpl implements TodoRepository {
  Future<Todo> getTodo(bool shouldWrap) async {
    try {
      return Todo();
    } catch (e) {
      if (shouldWrap) {
        throw RepositoryException(e);
      }
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
          codeName: 'repository_pass_through',
          problemMessage:
              'Repository should not handle/re-wrap exceptions. Use pass-through.',
          correctionMessage:
              'Do not convert/wrap exceptions in catch. Prefer logging + rethrow (or let it pass through).',
        ),
      ]);
    });

    test('reports try statements nested under control flow', () async {
      final result = await V2RuleHarness(rule: RepositoryPassThroughRule())
          .analyze(
            files: {
              'lib/features/todo/data/repositories/todo_repository_impl.dart':
                  '''
class Todo {}
abstract class TodoRepository {}

class TodoRepositoryImpl implements TodoRepository {
  Future<Todo> getTodo(bool shouldFetch) async {
    if (shouldFetch) {
      try {
        return Todo();
      } catch (e) {
        return Todo();
      }
    }
    return Todo();
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
          codeName: 'repository_pass_through',
          problemMessage:
              'Repository should not handle/re-wrap exceptions. Use pass-through.',
          correctionMessage:
              'Do not convert/wrap exceptions in catch. Prefer logging + rethrow (or let it pass through).',
        ),
      ]);
    });

    test('does not let nested try catch returns taint outer catch', () async {
      final result = await V2RuleHarness(rule: RepositoryPassThroughRule())
          .analyze(
            files: {
              'lib/features/todo/data/repositories/todo_repository_impl.dart':
                  '''
class Todo {}
abstract class TodoRepository {}

class TodoRepositoryImpl implements TodoRepository {
  Future<Todo> getTodo() async {
    try {
      return Todo();
    } catch (e) {
      try {
        print(e);
      } catch (_) {
        return Todo();
      }
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
          codeName: 'repository_pass_through',
          line: 9,
          problemMessage:
              'Repository should not handle/re-wrap exceptions. Use pass-through.',
          correctionMessage:
              'Do not convert/wrap exceptions in catch. Prefer logging + rethrow (or let it pass through).',
        ),
      ]);
    });

    test('allows logging and rethrow catch block', () async {
      final result = await V2RuleHarness(rule: RepositoryPassThroughRule())
          .analyze(
            files: {
              'lib/features/todo/data/repositories/todo_repository_impl.dart':
                  '''
class Todo {}
abstract class TodoRepository {}

class TodoRepositoryImpl implements TodoRepository {
  Future<Todo> getTodo() async {
    try {
      return Todo();
    } catch (e) {
      print(e);
      rethrow;
    }
  }
}
''',
            },
            definingFile:
                'lib/features/todo/data/repositories/todo_repository_impl.dart',
          );

      result.expectNoDiagnostics();
    });

    test('ignores Stream return type and private helpers', () async {
      final result = await V2RuleHarness(rule: RepositoryPassThroughRule())
          .analyze(
            files: {
              'lib/features/todo/data/repositories/todo_repository_impl.dart':
                  '''
class Todo {}
abstract class TodoRepository {}

class TodoRepositoryImpl implements TodoRepository {
  Stream<Todo> watchTodos() async* {}
  Todo _buildTodo() => Todo();
}
''',
            },
            definingFile:
                'lib/features/todo/data/repositories/todo_repository_impl.dart',
          );

      result.expectNoDiagnostics();
    });

    test('ignores generated files', () async {
      final result = await V2RuleHarness(rule: RepositoryPassThroughRule()).analyze(
        files: {
          'lib/features/todo/data/repositories/todo_repository_impl.freezed.dart':
              '''
class Todo {}
abstract class TodoRepository {}

class TodoRepositoryImpl implements TodoRepository {
  Todo getTodo() => Todo();
}
''',
        },
        definingFile:
            'lib/features/todo/data/repositories/todo_repository_impl.freezed.dart',
      );

      result.expectNoDiagnostics();
    });
  });
}
