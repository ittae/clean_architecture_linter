import 'package:clean_architecture_linter/src/rules/presentation_rules/widget_no_usecase_call_rule.dart';
import 'package:test/test.dart';

import '../../../v2_harness/analysis_rule_harness.dart';

void main() {
  group('WidgetNoUseCaseCallRule v2', () {
    test('reports UseCase imports and provider calls in widgets', () async {
      final result = await V2RuleHarness(rule: WidgetNoUseCaseCallRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/pages/todo_page.dart': '''
import 'package:app/features/todo/domain/usecases/get_todos_usecase.dart';

class TodoPage {
  void build(ref) {
    ref.read(getTodosUseCaseProvider);
  }
}
''',
            },
            definingFile: 'lib/features/todo/presentation/pages/todo_page.dart',
          );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath: 'lib/features/todo/presentation/pages/todo_page.dart',
          codeName: 'widget_no_usecase_call',
          problemMessage:
              'Widget/Page should NOT import UseCase: package:app/features/todo/domain/usecases/get_todos_usecase.dart',
          correctionMessage:
              'Remove UseCase import. Create a Provider that calls the UseCase instead.',
        ),
        const ExpectedV2Diagnostic(
          relativePath: 'lib/features/todo/presentation/pages/todo_page.dart',
          codeName: 'widget_no_usecase_call',
          problemMessage:
              'Widget/Page should NOT call UseCase provider "getTodosUseCaseProvider" directly via read()',
          correctionMessage:
              'Create an Entity Provider that calls the UseCase, then ref.watch() that provider.',
        ),
      ]);
    });

    test('ignores provider files and non-usecase providers', () async {
      final result = await V2RuleHarness(rule: WidgetNoUseCaseCallRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/providers/todo_provider.dart': '''
void build(ref) {
  ref.read(getTodosUseCaseProvider);
}
''',
              'lib/features/todo/presentation/widgets/todo_card.dart': '''
void build(ref) {
  ref.watch(todoListProvider);
}
''',
            },
            definingFile:
                'lib/features/todo/presentation/providers/todo_provider.dart',
            additionalDefiningFiles: [
              'lib/features/todo/presentation/widgets/todo_card.dart',
            ],
          );

      result.expectNoDiagnostics();
    });

    test('skips generated files', () async {
      final result = await V2RuleHarness(rule: WidgetNoUseCaseCallRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/pages/todo_page.g.dart': '''
import 'package:app/features/todo/domain/usecases/get_todos_usecase.dart';
void build(ref) {
  ref.read(getTodosUseCaseProvider);
}
''',
            },
            definingFile:
                'lib/features/todo/presentation/pages/todo_page.g.dart',
          );

      result.expectNoDiagnostics();
    });
  });
}
