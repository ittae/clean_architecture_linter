import 'package:clean_architecture_linter/src/rules/domain_rules/dependency_inversion_rule.dart';
import 'package:test/test.dart';

import '../../../v2_harness/analysis_rule_harness.dart';

void main() {
  group('DependencyInversionRule v2', () {
    test('reports dynamic dependency messages', () async {
      final result = await V2RuleHarness(rule: DependencyInversionRule())
          .analyze(
            files: {
              'lib/features/todo/domain/usecases/get_todo_usecase.dart': '''
import '../../data/repositories/todo_repository_impl.dart';

class GetTodoUseCase {
  final TodoRepositoryImpl repository;
  GetTodoUseCase(this.repository);
}
''',
              'lib/features/todo/data/repositories/todo_repository_impl.dart':
                  '''
class TodoRepositoryImpl {}
''',
            },
            definingFile:
                'lib/features/todo/domain/usecases/get_todo_usecase.dart',
          );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath:
              'lib/features/todo/domain/usecases/get_todo_usecase.dart',
          codeName: 'dependency_inversion',
          problemMessage:
              'Domain layer importing from data layer: ../../data/repositories/todo_repository_impl.dart',
          correctionMessage:
              'Domain should not depend on data layer. Use dependency inversion.',
        ),
        const ExpectedV2Diagnostic(
          relativePath:
              'lib/features/todo/domain/usecases/get_todo_usecase.dart',
          codeName: 'dependency_inversion',
          problemMessage:
              'Field depends on concrete implementation: TodoRepositoryImpl',
          correctionMessage: 'Use abstract type for field declaration.',
        ),
      ]);
    });

    test('skips generated files', () async {
      final result = await V2RuleHarness(rule: DependencyInversionRule()).analyze(
        files: {
          'lib/features/todo/domain/usecases/get_todo_usecase.freezed.dart': '''
import '../../data/repositories/todo_repository_impl.dart';

class GetTodoUseCase {
  final TodoRepositoryImpl repository;
  GetTodoUseCase(this.repository);
}
''',
          'lib/features/todo/data/repositories/todo_repository_impl.dart': '''
class TodoRepositoryImpl {}
''',
        },
        definingFile:
            'lib/features/todo/domain/usecases/get_todo_usecase.freezed.dart',
      );

      result.expectNoDiagnostics();
    });

    test('reports constructor, inheritance, dio, and presentation imports', () async {
      const domain = 'lib/features/todo/domain/usecases/get_todo_usecase.dart';
      final result = await V2RuleHarness(rule: DependencyInversionRule())
          .analyze(
            files: {
              domain: '''
import 'package:dio/dio.dart';
import '../../presentation/pages/todo_page.dart';

class GetTodoUseCase extends StatefulWidget with CacheImpl implements TodoRepositoryImpl {
  final Database database;
  GetTodoUseCase(TodoRepositoryImpl repository, Database database, Widget widget);
}

class StatefulWidget {}
class TodoRepositoryImpl {}
class CacheImpl {}
class Database {}
class Widget {}
''',
              'lib/features/todo/presentation/pages/todo_page.dart':
                  'class TodoPage {}',
            },
            definingFile: domain,
          );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath: domain,
          codeName: 'dependency_inversion',
          problemMessage:
              'Direct infrastructure import in domain layer: package:dio/dio.dart',
          correctionMessage:
              'Create domain abstraction and move infrastructure to data layer.',
        ),
        const ExpectedV2Diagnostic(
          relativePath: domain,
          codeName: 'dependency_inversion',
          problemMessage:
              'Domain layer importing from presentation layer: ../../presentation/pages/todo_page.dart',
          correctionMessage: 'Domain should not depend on presentation layer.',
        ),
        const ExpectedV2Diagnostic(
          relativePath: domain,
          codeName: 'dependency_inversion',
          problemMessage:
              'Domain field directly references infrastructure: Database',
          correctionMessage:
              'Create domain abstraction for infrastructure dependency.',
        ),
        const ExpectedV2Diagnostic(
          relativePath: domain,
          codeName: 'dependency_inversion',
          problemMessage:
              'Constructor parameter depends on concrete implementation: TodoRepositoryImpl',
          correctionMessage:
              'Use abstract interface or base class instead of concrete implementation.',
        ),
        const ExpectedV2Diagnostic(
          relativePath: domain,
          codeName: 'dependency_inversion',
          problemMessage:
              'Domain layer directly depends on infrastructure: Database',
          correctionMessage:
              'Create domain interface and inject through dependency inversion.',
        ),
        const ExpectedV2Diagnostic(
          relativePath: domain,
          codeName: 'dependency_inversion',
          problemMessage: 'Domain layer depends on external framework: Widget',
          correctionMessage:
              'Abstract framework dependency behind domain interface.',
        ),
        const ExpectedV2Diagnostic(
          relativePath: domain,
          codeName: 'dependency_inversion',
          problemMessage: 'Domain class extends framework type: StatefulWidget',
          correctionMessage:
              'Create domain abstraction instead of depending on framework.',
        ),
        const ExpectedV2Diagnostic(
          relativePath: domain,
          codeName: 'dependency_inversion',
          problemMessage:
              'Domain class implements concrete implementation: TodoRepositoryImpl',
          correctionMessage:
              'Use abstract base class or interface for inheritance.',
        ),
        const ExpectedV2Diagnostic(
          relativePath: domain,
          codeName: 'dependency_inversion',
          problemMessage:
              'Domain class mixes concrete implementation: CacheImpl',
          correctionMessage:
              'Use abstract base class or interface for inheritance.',
        ),
      ]);
    });

    test('allows an abstract repository dependency in domain', () async {
      const domain = 'lib/features/todo/domain/usecases/get_todo_usecase.dart';
      final result = await V2RuleHarness(rule: DependencyInversionRule())
          .analyze(
            files: {
              domain: '''
class GetTodoUseCase {
  final TodoRepository repository;
  GetTodoUseCase(this.repository);
}

abstract interface class TodoRepository {}
''',
            },
            definingFile: domain,
          );

      result.expectNoDiagnostics();
    });

    test(
      'allows a non-abstract repository type without an implementation suffix',
      () async {
        const domain =
            'lib/features/todo/domain/usecases/get_todo_usecase.dart';
        final result = await V2RuleHarness(rule: DependencyInversionRule())
            .analyze(
              files: {
                domain: '''
class GetTodoUseCase {
  final TodoRepository repository;
  GetTodoUseCase(this.repository);
}

class TodoRepository {}
''',
              },
              definingFile: domain,
            );

        result.expectNoDiagnostics();
      },
    );

    test(
      'skips the same concrete dependency outside the domain layer',
      () async {
        const data =
            'lib/features/todo/data/repositories/todo_repository_impl.dart';
        final result = await V2RuleHarness(rule: DependencyInversionRule())
            .analyze(
              files: {
                data: '''
import 'package:dio/dio.dart';

class TodoRepositoryImpl {
  final Database database;
  TodoRepositoryImpl(TodoRepositoryImpl other);
}

class Database {}
''',
              },
              definingFile: data,
            );

        result.expectNoDiagnostics();
      },
    );
  });
}
