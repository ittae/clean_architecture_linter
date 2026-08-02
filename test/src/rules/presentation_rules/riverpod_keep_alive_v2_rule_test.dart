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

    test('reports functional provider keepAlive outside global state', () async {
      final result = await V2RuleHarness(rule: RiverpodKeepAliveRule()).analyze(
        files: {
          'lib/features/todo/presentation/providers/todo_provider.dart': '''
class Riverpod {
  const Riverpod({required bool keepAlive});
}

@Riverpod(keepAlive: true)
Future<Object> todoList(Object ref) async => Object();
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

    test('allows functional provider keepAlive for global state', () async {
      final result = await V2RuleHarness(rule: RiverpodKeepAliveRule()).analyze(
        files: {
          'lib/features/auth/presentation/providers/auth_provider.dart': '''
class Riverpod {
  const Riverpod({required bool keepAlive});
}

@Riverpod(keepAlive: true)
Future<Object> authSession(Object ref) async => Object();
''',
        },
        definingFile:
            'lib/features/auth/presentation/providers/auth_provider.dart',
      );

      result.expectNoDiagnostics();
    });

    test(
      'does not check programmatic ref.keepAlive() calls (documents a known '
      'scope gap vs the declarative @Riverpod(keepAlive: true) form)',
      () async {
        final result = await V2RuleHarness(
          rule: RiverpodKeepAliveRule(),
        ).analyze(
          files: {
            'lib/features/todo/presentation/providers/todo_provider.dart': '''
class riverpod {
  const riverpod();
}

@riverpod
Future<Object> todoList(Object ref) async {
  ref.keepAlive();
  return Object();
}
''',
          },
          definingFile:
              'lib/features/todo/presentation/providers/todo_provider.dart',
        );

        // This rule only visits Annotation nodes matching @Riverpod(keepAlive:
        // true), so Riverpod's programmatic ref.keepAlive() API -- the
        // officially recommended finer-grained alternative for e.g. "cache a
        // successful async result, retry on failure" -- is entirely outside
        // this rule's model. This test documents that scope gap explicitly.
        result.expectNoDiagnostics();
      },
    );
  });
}
