import 'package:clean_architecture_linter/src/rules/presentation_rules/riverpod_provider_naming_rule.dart';
import 'package:test/test.dart';

import '../../../v2_harness/analysis_rule_harness.dart';

void main() {
  group('RiverpodProviderNamingRule v2', () {
    test('reports provider functions missing matching suffixes', () async {
      final result = await V2RuleHarness(rule: RiverpodProviderNamingRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/providers/todo_providers.dart':
                  '''
class riverpod {
  const riverpod();
}

class GetTodosUseCase {}
class TodoRepository {}
class TodoDataSource {}

@riverpod
GetTodosUseCase getTodos(ref) => GetTodosUseCase();

@riverpod
TodoRepository todoRepo(ref) => TodoRepository();

@riverpod
TodoDataSource todoData(ref) => TodoDataSource();
''',
            },
            definingFile:
                'lib/features/todo/presentation/providers/todo_providers.dart',
          );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath:
              'lib/features/todo/presentation/providers/todo_providers.dart',
          codeName: 'riverpod_provider_naming',
          problemMessage:
              'Provider function "getTodos" returning GetTodosUseCase must end with "UseCase".',
          correctionMessage:
              'Rename to "getTodosUseCase" to generate "getTodosUseCaseProvider".',
        ),
        const ExpectedV2Diagnostic(
          relativePath:
              'lib/features/todo/presentation/providers/todo_providers.dart',
          codeName: 'riverpod_provider_naming',
          problemMessage:
              'Provider function "todoRepo" returning TodoRepository must end with "Repository".',
          correctionMessage:
              'Rename to "todoRepoRepository" to generate "todoRepoRepositoryProvider".',
        ),
        const ExpectedV2Diagnostic(
          relativePath:
              'lib/features/todo/presentation/providers/todo_providers.dart',
          codeName: 'riverpod_provider_naming',
          problemMessage:
              'Provider function "todoData" returning TodoDataSource must end with "DataSource".',
          correctionMessage:
              'Rename to "todoDataDataSource" to generate "todoDataDataSourceProvider".',
        ),
      ]);
    });

    test('allows correctly suffixed provider names', () async {
      final result = await V2RuleHarness(rule: RiverpodProviderNamingRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/providers/todo_providers.dart':
                  '''
class riverpod {
  const riverpod();
}

class GetTodosUsecase {}

@riverpod
GetTodosUsecase getTodosUsecase(ref) => GetTodosUsecase();
''',
            },
            definingFile:
                'lib/features/todo/presentation/providers/todo_providers.dart',
          );

      result.expectNoDiagnostics();
    });

    test('skips generated files', () async {
      final result = await V2RuleHarness(rule: RiverpodProviderNamingRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/providers/todo_providers.g.dart':
                  '''
class riverpod {
  const riverpod();
}
class TodoRepository {}
@riverpod
TodoRepository todo(ref) => TodoRepository();
''',
            },
            definingFile:
                'lib/features/todo/presentation/providers/todo_providers.g.dart',
          );

      result.expectNoDiagnostics();
    });
  });
}
