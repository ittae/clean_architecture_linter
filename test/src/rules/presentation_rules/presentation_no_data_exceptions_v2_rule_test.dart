import 'package:clean_architecture_linter/src/rules/presentation_rules/presentation_no_data_exceptions_rule.dart';
import 'package:test/test.dart';

import '../../../v2_harness/analysis_rule_harness.dart';

void main() {
  group('PresentationNoDataExceptionsRule v2', () {
    test('reports data exception type checks with feature suggestion', () async {
      final result =
          await V2RuleHarness(rule: PresentationNoDataExceptionsRule()).analyze(
            files: {
              'lib/features/todo/presentation/pages/todo_page.dart': '''
class NotFoundException implements Exception {}
class TodoNotFoundException implements Exception {}

void render(Object error) {
  if (error is NotFoundException) {
    showError();
  }
  if (error is TodoNotFoundException) {
    showError();
  }
}

void showError() {}
''',
            },
            definingFile: 'lib/features/todo/presentation/pages/todo_page.dart',
          );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath: 'lib/features/todo/presentation/pages/todo_page.dart',
          codeName: 'presentation_no_data_exceptions',
          problemMessage:
              'Presentation should NOT handle Data exception "NotFoundException". Use Domain exception instead.',
          correctionMessage:
              'Replace with Domain exception "TodoNotFoundException". UseCase should convert Data exceptions.',
        ),
      ]);
    });

    test('reports nested feature path suggestions', () async {
      final result =
          await V2RuleHarness(rule: PresentationNoDataExceptionsRule()).analyze(
            files: {
              'lib/features/auth/presentation/widgets/login_button.dart': '''
class NetworkException implements Exception {}

void render(Object error) {
  if (error is NetworkException) {}
}
''',
            },
            definingFile:
                'lib/features/auth/presentation/widgets/login_button.dart',
          );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath:
              'lib/features/auth/presentation/widgets/login_button.dart',
          codeName: 'presentation_no_data_exceptions',
          problemMessage:
              'Presentation should NOT handle Data exception "NetworkException". Use Domain exception instead.',
          correctionMessage:
              'Replace with Domain exception "AuthNetworkException". UseCase should convert Data exceptions.',
        ),
      ]);
    });

    test('ignores non-presentation files', () async {
      final result =
          await V2RuleHarness(rule: PresentationNoDataExceptionsRule()).analyze(
            files: {
              'lib/features/todo/data/repositories/todo_repository_impl.dart':
                  '''
class NotFoundException implements Exception {}
void map(Object error) {
  if (error is NotFoundException) {}
}
''',
            },
            definingFile:
                'lib/features/todo/data/repositories/todo_repository_impl.dart',
          );

      result.expectNoDiagnostics();
    });

    test('skips generated files', () async {
      final result =
          await V2RuleHarness(rule: PresentationNoDataExceptionsRule()).analyze(
            files: {
              'lib/features/todo/presentation/pages/todo_page.g.dart': '''
class NotFoundException implements Exception {}
void render(Object error) {
  if (error is NotFoundException) {}
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
