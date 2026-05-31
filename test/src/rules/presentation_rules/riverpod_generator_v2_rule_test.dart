import 'package:clean_architecture_linter/src/rules/presentation_rules/riverpod_generator_rule.dart';
import 'package:test/test.dart';

import '../../../v2_harness/analysis_rule_harness.dart';

void main() {
  group('RiverpodGeneratorRule v2', () {
    test('reports manual providers in presentation providers', () async {
      final result = await V2RuleHarness(rule: RiverpodGeneratorRule()).analyze(
        files: {
          'lib/features/todo/presentation/providers/todo_provider.dart': '''
Object StateNotifierProvider(Object create) => create;
final todoProvider = StateNotifierProvider((ref) => Object());
''',
        },
        definingFile:
            'lib/features/todo/presentation/providers/todo_provider.dart',
      );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath:
              'lib/features/todo/presentation/providers/todo_provider.dart',
          codeName: 'riverpod_generator',
          problemMessage:
              'Manual provider "StateNotifierProvider" detected. Use @riverpod annotation instead.',
          correctionMessage:
              'Use riverpod_generator: Create a class with @riverpod annotation instead of manual provider declaration.',
        ),
      ]);
    });

    test('ignores non-provider presentation files', () async {
      final result = await V2RuleHarness(rule: RiverpodGeneratorRule()).analyze(
        files: {
          'lib/features/todo/presentation/pages/todo_page.dart': '''
Object StateProvider(Object create) => create;
final todoProvider = StateProvider((ref) => Object());
''',
        },
        definingFile: 'lib/features/todo/presentation/pages/todo_page.dart',
      );

      result.expectNoDiagnostics();
    });

    test('skips generated files', () async {
      final result = await V2RuleHarness(rule: RiverpodGeneratorRule()).analyze(
        files: {
          'lib/features/todo/presentation/providers/todo_provider.g.dart': '''
Object FutureProvider(Object create) => create;
final todoProvider = FutureProvider((ref) => Object());
''',
        },
        definingFile:
            'lib/features/todo/presentation/providers/todo_provider.g.dart',
      );

      result.expectNoDiagnostics();
    });
  });
}
