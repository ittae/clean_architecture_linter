import 'package:clean_architecture_linter/src/rules/presentation_rules/no_presentation_models_rule.dart';
import 'package:test/test.dart';

import '../../../v2_harness/analysis_rule_harness.dart';

void main() {
  group('NoPresentationModelsRule v2', () {
    test('reports presentation models directory', () async {
      final result = await V2RuleHarness(rule: NoPresentationModelsRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/models/todo_ui_model.dart': '''
class TodoUiModel {}
''',
            },
            definingFile:
                'lib/features/todo/presentation/models/todo_ui_model.dart',
          );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath:
              'lib/features/todo/presentation/models/todo_ui_model.dart',
          codeName: 'no_presentation_models',
          problemMessage: 'Presentation models directory is not allowed',
          correctionMessage:
              'Remove presentation/models/ directory. Use states/ directory with Freezed State containing Entities.',
        ),
      ]);
    });

    test('reports viewmodels directory and ViewModel class', () async {
      final result = await V2RuleHarness(rule: NoPresentationModelsRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/viewmodels/todo_viewmodel.dart':
                  '''
class TodoViewModel {}
''',
            },
            definingFile:
                'lib/features/todo/presentation/viewmodels/todo_viewmodel.dart',
          );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath:
              'lib/features/todo/presentation/viewmodels/todo_viewmodel.dart',
          codeName: 'no_presentation_models',
          problemMessage: 'ViewModels directory is not allowed',
          correctionMessage:
              'Remove presentation/viewmodels/ directory. Use Freezed State with Riverpod instead.',
        ),
        const ExpectedV2Diagnostic(
          relativePath:
              'lib/features/todo/presentation/viewmodels/todo_viewmodel.dart',
          codeName: 'no_presentation_models',
          problemMessage: 'ViewModel pattern is not allowed: TodoViewModel',
          correctionMessage:
              'Use Freezed State with riverpod_generator (@riverpod annotation) instead.',
        ),
      ]);
    });

    test('reports ChangeNotifier usage', () async {
      final result = await V2RuleHarness(rule: NoPresentationModelsRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/providers/todo_notifier.dart': '''
class ChangeNotifier {}
class TodoNotifier extends ChangeNotifier {}
''',
            },
            definingFile:
                'lib/features/todo/presentation/providers/todo_notifier.dart',
          );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath:
              'lib/features/todo/presentation/providers/todo_notifier.dart',
          codeName: 'no_presentation_models',
          problemMessage: 'ChangeNotifier pattern is not allowed',
          correctionMessage:
              'Use Freezed State with Riverpod instead. Define state with @freezed and notifier with @riverpod.',
        ),
      ]);
    });

    test('skips generated files', () async {
      final result = await V2RuleHarness(rule: NoPresentationModelsRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/models/todo_ui_model.g.dart': '''
class ChangeNotifier {}
class TodoViewModel extends ChangeNotifier {}
''',
            },
            definingFile:
                'lib/features/todo/presentation/models/todo_ui_model.g.dart',
          );

      result.expectNoDiagnostics();
    });
  });
}
