import 'package:clean_architecture_linter/src/rules/presentation_rules/riverpod_keep_alive_rule.dart';
import 'package:test/test.dart';

import '../../../v2_harness/analysis_rule_harness.dart';

void main() {
  group('RiverpodKeepAliveRule v2', () {
    test('reports feature-specific keepAlive usage', () async {
      final result = await V2RuleHarness(rule: RiverpodKeepAliveRule()).analyze(
        files: {
          'lib/features/todo/presentation/providers/todo_provider.dart': '''
class Riverpod {
  const Riverpod({required bool keepAlive});
}

@Riverpod(keepAlive: true)
class TodoListNotifier {}
''',
        },
        definingFile:
            'lib/features/todo/presentation/providers/todo_provider.dart',
      );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath:
              'lib/features/todo/presentation/providers/todo_provider.dart',
          codeName: 'riverpod_keep_alive',
          problemMessage:
              'Verify that "keepAlive: true" is necessary. Only use for app-wide persistent state.',
          correctionMessage:
              'Valid uses: auth state, app settings, global cache. Invalid: avoiding dispose errors (fix async flow instead).',
        ),
      ]);
    });

    test('allows valid auth and infrastructure keepAlive usage', () async {
      final result = await V2RuleHarness(rule: RiverpodKeepAliveRule()).analyze(
        files: {
          'lib/features/auth/presentation/providers/auth_provider.dart': '''
class Riverpod {
  const Riverpod({required bool keepAlive});
}

@Riverpod(keepAlive: true)
class AuthNotifier {}

@Riverpod(keepAlive: true)
class TodoRepositoryProvider {}
''',
        },
        definingFile:
            'lib/features/auth/presentation/providers/auth_provider.dart',
      );

      result.expectNoDiagnostics();
    });

    test('ignores non-keepAlive annotations and generated files', () async {
      final result = await V2RuleHarness(rule: RiverpodKeepAliveRule()).analyze(
        files: {
          'lib/features/todo/presentation/providers/todo_provider.g.dart': '''
class Riverpod {
  const Riverpod({required bool keepAlive});
}

@Riverpod(keepAlive: true)
class TodoListNotifier {}
''',
          'lib/features/todo/presentation/providers/other_provider.dart': '''
class Riverpod {
  const Riverpod({required bool keepAlive});
}

@Riverpod(keepAlive: false)
class TodoListNotifier {}
''',
        },
        definingFile:
            'lib/features/todo/presentation/providers/todo_provider.g.dart',
        additionalDefiningFiles: [
          'lib/features/todo/presentation/providers/other_provider.dart',
        ],
      );

      result.expectNoDiagnostics();
    });
  });
}
