import 'package:clean_architecture_linter/src/rules/data_rules/repository_implementation_rule.dart';
import 'package:test/test.dart';

import '../../../v2_harness/analysis_rule_harness.dart';

void main() {
  group('RepositoryImplementationRule v2', () {
    test('reports RepositoryImpl without implements clause', () async {
      final result = await V2RuleHarness(rule: RepositoryImplementationRule())
          .analyze(
            files: {
              'lib/features/todo/data/repositories/todo_repository_impl.dart':
                  '''
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
          codeName: 'repository_implementation',
          line: 1,
          problemMessage:
              'Repository implementation must implement a domain repository interface: TodoRepositoryImpl',
          correctionMessage:
              'Add implements clause with domain repository interface. Example: class UserRepositoryImpl implements UserRepository',
        ),
      ]);
    });

    test('reports RepositoryImpl implementing non-repository interface', () async {
      final result = await V2RuleHarness(rule: RepositoryImplementationRule())
          .analyze(
            files: {
              'lib/features/todo/data/repositories/todo_repository_impl.dart':
                  '''
class TodoDataPort {}
class TodoRepositoryImpl implements TodoDataPort {}
''',
            },
            definingFile:
                'lib/features/todo/data/repositories/todo_repository_impl.dart',
          );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath:
              'lib/features/todo/data/repositories/todo_repository_impl.dart',
          codeName: 'repository_implementation',
          problemMessage:
              'Repository implementation should implement a domain repository interface: TodoRepositoryImpl implements TodoDataPort',
          correctionMessage:
              'Implement the corresponding domain repository interface. Example: class UserRepositoryImpl implements UserRepository',
        ),
      ]);
    });

    test('accepts RepositoryImpl implementing repository interface', () async {
      final result = await V2RuleHarness(rule: RepositoryImplementationRule())
          .analyze(
            files: {
              'lib/features/todo/domain/repositories/todo_repository.dart': '''
abstract class TodoRepository {}
''',
              'lib/features/todo/data/repositories/todo_repository_impl.dart':
                  '''
import '../../domain/repositories/todo_repository.dart';

class TodoRepositoryImpl implements TodoRepository {}
''',
            },
            definingFile:
                'lib/features/todo/data/repositories/todo_repository_impl.dart',
          );

      result.expectNoDiagnostics();
    });

    test('reports abstract repository interface in data layer', () async {
      final result = await V2RuleHarness(rule: RepositoryImplementationRule())
          .analyze(
            files: {
              'lib/features/todo/data/repositories/todo_repository.dart': '''
abstract class TodoRepository {}
''',
            },
            definingFile:
                'lib/features/todo/data/repositories/todo_repository.dart',
          );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath:
              'lib/features/todo/data/repositories/todo_repository.dart',
          codeName: 'repository_implementation',
          problemMessage:
              'Repository interface should be in domain layer, not data layer: TodoRepository',
          correctionMessage:
              'Move abstract repository interface to domain layer. Data layer should only contain RepositoryImpl classes.',
        ),
      ]);
    });

    test('reports RepositoryImpl in domain layer', () async {
      final result = await V2RuleHarness(rule: RepositoryImplementationRule())
          .analyze(
            files: {
              'lib/features/todo/domain/repositories/todo_repository_impl.dart':
                  '''
class TodoRepositoryImpl {}
''',
            },
            definingFile:
                'lib/features/todo/domain/repositories/todo_repository_impl.dart',
          );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath:
              'lib/features/todo/domain/repositories/todo_repository_impl.dart',
          codeName: 'repository_implementation',
          problemMessage:
              'Repository implementation should be in data layer, not domain layer: TodoRepositoryImpl',
          correctionMessage:
              'Move TodoRepositoryImpl to data layer. Domain layer should only contain abstract repository interfaces.',
        ),
      ]);
    });

    test('ignores generated files', () async {
      final result = await V2RuleHarness(rule: RepositoryImplementationRule())
          .analyze(
            files: {
              'lib/features/todo/data/repositories/todo_repository_impl.g.dart':
                  '''
class TodoRepositoryImpl {}
''',
            },
            definingFile:
                'lib/features/todo/data/repositories/todo_repository_impl.g.dart',
          );

      result.expectNoDiagnostics();
    });
  });
}
