import 'package:clean_architecture_linter/src/rules/presentation_rules/widget_ref_read_then_when_rule.dart';
import 'package:test/test.dart';

import '../../../v2_harness/analysis_rule_harness.dart';

void main() {
  group('WidgetRefReadThenWhenRule v2', () {
    test('reports direct ref.read().when in widget methods', () async {
      final result = await V2RuleHarness(rule: WidgetRefReadThenWhenRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/pages/todo_page.dart': '''
class TodoPage {
  void build(ref) {
    ref.read(todoProvider).when(data: (_) {}, loading: () {}, error: (_, __) {});
  }
}
''',
            },
            definingFile: 'lib/features/todo/presentation/pages/todo_page.dart',
          );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath: 'lib/features/todo/presentation/pages/todo_page.dart',
          codeName: 'widget_ref_read_then_when',
          problemMessage:
              'Anti-pattern: Using .when() after ref.read() in the same function',
          correctionMessage:
              'Use ref.watch() + .when() in build() for UI, ref.listen() for side effects, or try-catch for one-off operations.',
        ),
      ]);
    });

    test(
      'reports variable ref.read assignment followed by when in callbacks',
      () async {
        final result = await V2RuleHarness(rule: WidgetRefReadThenWhenRule())
            .analyze(
              files: {
                'lib/features/todo/presentation/widgets/todo_button.dart': '''
void build(ref) {
  final callback = () {
    final state = ref.read(todoProvider);
    state.when(data: (_) {}, loading: () {}, error: (_, __) {});
  };
}
''',
              },
              definingFile:
                  'lib/features/todo/presentation/widgets/todo_button.dart',
            );

        result.expectDiagnostics([
          const ExpectedV2Diagnostic(
            relativePath:
                'lib/features/todo/presentation/widgets/todo_button.dart',
            codeName: 'widget_ref_read_then_when',
            problemMessage:
                'Anti-pattern: Using .when() after ref.read() in the same function',
            correctionMessage:
                'Use ref.watch() + .when() in build() for UI, ref.listen() for side effects, or try-catch for one-off operations.',
          ),
        ]);
      },
    );

    test('allows ref.watch().when and non-widget files', () async {
      final result = await V2RuleHarness(rule: WidgetRefReadThenWhenRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/pages/todo_page.dart': '''
class TodoPage {
  void build(ref) {
    ref.watch(todoProvider).when(data: (_) {}, loading: () {}, error: (_, __) {});
  }
}
''',
              'lib/features/todo/presentation/providers/todo_provider.dart': '''
void build(ref) {
  final state = ref.read(todoProvider);
  state.when(data: (_) {}, loading: () {}, error: (_, __) {});
}
''',
            },
            definingFile: 'lib/features/todo/presentation/pages/todo_page.dart',
            additionalDefiningFiles: [
              'lib/features/todo/presentation/providers/todo_provider.dart',
            ],
          );

      result.expectNoDiagnostics();
    });

    test('skips generated files', () async {
      final result = await V2RuleHarness(rule: WidgetRefReadThenWhenRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/pages/todo_page.g.dart': '''
void build(ref) {
  ref.read(todoProvider).when(data: (_) {}, loading: () {}, error: (_, __) {});
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
