import 'package:clean_architecture_linter/src/rules/domain_rules/repository_interface_rule.dart';
import 'package:test/test.dart';

import '../../../v2_harness/analysis_rule_harness.dart';

void main() {
  group('RepositoryInterfaceRule v2', () {
    test('reports dynamic repository messages', () async {
      final result = await V2RuleHarness(rule: RepositoryInterfaceRule())
          .analyze(
            files: {
              'lib/features/todo/domain/repositories/todo_repository.dart': '''
import '../../data/repositories/todo_repository_impl.dart';

class TodoRepository {
  Future<UserModel> getTodo() async => UserModel();
}
class UserModel {}
''',
              'lib/features/todo/data/repositories/todo_repository_impl.dart':
                  '''
class TodoRepositoryImpl {}
''',
            },
            definingFile:
                'lib/features/todo/domain/repositories/todo_repository.dart',
          );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath:
              'lib/features/todo/domain/repositories/todo_repository.dart',
          codeName: 'repository_interface',
          problemMessage:
              'Importing concrete repository implementation from data layer',
          correctionMessage:
              'Import only abstract repository interfaces. Move concrete implementations to data layer.',
        ),
        const ExpectedV2Diagnostic(
          relativePath:
              'lib/features/todo/domain/repositories/todo_repository.dart',
          codeName: 'repository_interface',
          problemMessage:
              'Repository in domain layer should be abstract: TodoRepository',
          correctionMessage:
              'Make repository abstract or move implementation to data layer.',
        ),
        const ExpectedV2Diagnostic(
          relativePath:
              'lib/features/todo/domain/repositories/todo_repository.dart',
          codeName: 'repository_interface',
          problemMessage:
              'Repository method uses data layer model in generic type: UserModel',
          correctionMessage:
              'Use domain entities in generic types. Example: Future<User> or AsyncValue<User> patterns should never expose UserModel.',
        ),
      ]);
    });

    test('reports data models inside nested generic return types', () async {
      final result = await V2RuleHarness(rule: RepositoryInterfaceRule())
          .analyze(
            files: {
              'lib/features/todo/domain/repositories/todo_repository.dart': '''
abstract class TodoRepository {
  Future<Result<UserModel>> getTodo();
  Future<List<UserModel>> getTodos();
}

class Result<T> {}
class UserModel {}
''',
            },
            definingFile:
                'lib/features/todo/domain/repositories/todo_repository.dart',
          );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath:
              'lib/features/todo/domain/repositories/todo_repository.dart',
          codeName: 'repository_interface',
          problemMessage:
              'Repository method uses data layer model in generic type: UserModel',
          correctionMessage:
              'Use domain entities in generic types. Example: Future<User> or AsyncValue<User> patterns should never expose UserModel.',
        ),
        const ExpectedV2Diagnostic(
          relativePath:
              'lib/features/todo/domain/repositories/todo_repository.dart',
          codeName: 'repository_interface',
          problemMessage:
              'Repository method uses data layer model in generic type: UserModel',
          correctionMessage:
              'Use domain entities in generic types. Example: Future<User> or AsyncValue<User> patterns should never expose UserModel.',
        ),
      ]);
    });

    test('reports data models inside nested generic parameter types', () async {
      final result = await V2RuleHarness(rule: RepositoryInterfaceRule())
          .analyze(
            files: {
              'lib/features/todo/domain/repositories/todo_repository.dart': '''
abstract class TodoRepository {
  Future<void> save(Result<UserModel> user);
  Future<void> saveAll(Future<List<UserModel>> users);
}

class Result<T> {}
class UserModel {}
''',
            },
            definingFile:
                'lib/features/todo/domain/repositories/todo_repository.dart',
          );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath:
              'lib/features/todo/domain/repositories/todo_repository.dart',
          codeName: 'repository_interface',
          problemMessage:
              'Repository parameter uses data layer model in generic type: UserModel',
          correctionMessage:
              'Use domain entities in generic types. Example: List<User> instead of List<UserModel>',
        ),
        const ExpectedV2Diagnostic(
          relativePath:
              'lib/features/todo/domain/repositories/todo_repository.dart',
          codeName: 'repository_interface',
          problemMessage:
              'Repository parameter uses data layer model in generic type: UserModel',
          correctionMessage:
              'Use domain entities in generic types. Example: List<User> instead of List<UserModel>',
        ),
      ]);
    });

    test(
      'allows domain entities inside nested generic repository signatures',
      () async {
        final result = await V2RuleHarness(rule: RepositoryInterfaceRule())
            .analyze(
              files: {
                'lib/features/todo/domain/repositories/todo_repository.dart':
                    '''
abstract class TodoRepository {
  Future<Result<User>> getTodo();
  Future<void> saveAll(Result<List<User>> users);
}

class Result<T> {}
class User {}
''',
              },
              definingFile:
                  'lib/features/todo/domain/repositories/todo_repository.dart',
            );

        result.expectNoDiagnostics();
      },
    );

    test('skips generated files', () async {
      final result = await V2RuleHarness(rule: RepositoryInterfaceRule())
          .analyze(
            files: {
              'lib/features/todo/domain/repositories/todo_repository.g.dart':
                  '''
import '../../data/repositories/todo_repository_impl.dart';

class TodoRepository {
  Future<UserModel> getTodo() async => UserModel();
}
class UserModel {}
''',
              'lib/features/todo/data/repositories/todo_repository_impl.dart':
                  '''
class TodoRepositoryImpl {}
''',
            },
            definingFile:
                'lib/features/todo/domain/repositories/todo_repository.g.dart',
          );

      result.expectNoDiagnostics();
    });
  });
}
