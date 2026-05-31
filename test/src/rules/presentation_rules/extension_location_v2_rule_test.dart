import 'package:clean_architecture_linter/src/rules/presentation_rules/extension_location_rule.dart';
import 'package:test/test.dart';

import '../../../v2_harness/analysis_rule_harness.dart';

void main() {
  group('ExtensionLocationRule v2', () {
    test(
      'reports forbidden extension directories with dynamic messages',
      () async {
        final result = await V2RuleHarness(rule: ExtensionLocationRule())
            .analyze(
              files: {
                'lib/features/todo/domain/extensions/todo_extensions.dart': '''
class Todo {}
extension TodoX on Todo {}
''',
              },
              definingFile:
                  'lib/features/todo/domain/extensions/todo_extensions.dart',
            );

        result.expectDiagnostics([
          const ExpectedV2Diagnostic(
            relativePath:
                'lib/features/todo/domain/extensions/todo_extensions.dart',
            codeName: 'extension_location',
            problemMessage:
                'Extension directory is not allowed: /domain/extensions/',
            correctionMessage:
                'Move extensions to the entity file (e.g., ranking.dart with extension RankingX) file. Extensions should be in the same file as the class they extend.',
          ),
        ]);
      },
    );

    test('reports entity UI extensions in widget files', () async {
      final result = await V2RuleHarness(rule: ExtensionLocationRule()).analyze(
        files: {
          'lib/features/todo/presentation/widgets/todo_card.dart': '''
class Todo {}
extension TodoUIX on Todo {
  String get label => 'todo';
}
''',
        },
        definingFile: 'lib/features/todo/presentation/widgets/todo_card.dart',
      );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath: 'lib/features/todo/presentation/widgets/todo_card.dart',
          codeName: 'extension_location',
          problemMessage:
              'Entity UI extensions are not allowed in widget/page/screen files',
          correctionMessage:
              'Move entity UI extensions to the State file (e.g., todo_state.dart). Only State files should contain entity UI extensions. Widget files should use the State and its extensions, not define their own.',
        ),
      ]);
    });

    test('allows presentation state files', () async {
      final result = await V2RuleHarness(rule: ExtensionLocationRule()).analyze(
        files: {
          'lib/features/todo/presentation/states/todo_state.dart': '''
class Todo {}
extension TodoUIX on Todo {
  String get label => 'todo';
}
''',
        },
        definingFile: 'lib/features/todo/presentation/states/todo_state.dart',
      );

      result.expectNoDiagnostics();
    });

    test('skips generated files', () async {
      final result = await V2RuleHarness(rule: ExtensionLocationRule()).analyze(
        files: {
          'lib/features/todo/presentation/widgets/todo_card.g.dart': '''
class Todo {}
extension TodoUIX on Todo {}
''',
        },
        definingFile: 'lib/features/todo/presentation/widgets/todo_card.g.dart',
      );

      result.expectNoDiagnostics();
    });
  });
}
