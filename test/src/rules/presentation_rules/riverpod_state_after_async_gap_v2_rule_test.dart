import 'package:clean_architecture_linter/src/rules/presentation_rules/riverpod_state_after_async_gap_rule.dart';
import 'package:test/test.dart';

import '../../../v2_harness/analysis_rule_harness.dart';

void main() {
  group('RiverpodStateAfterAsyncGapRule v2', () {
    test('reports unguarded state assignment after await', () async {
      final result = await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/providers/todo_notifier.dart': '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load() async {
    await fetchTodo();
    state = AsyncData(todo);
  }
}
''',
            },
            definingFile:
                'lib/features/todo/presentation/providers/todo_notifier.dart',
          );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath:
              'lib/features/todo/presentation/providers/todo_notifier.dart',
          codeName: 'riverpod_state_after_async_gap',
          problemMessage:
              'Avoid assigning to state after an async gap in Riverpod providers (Riverpod 3 throws UnmountedRefException once the provider is disposed).',
          correctionMessage:
              'Await into a local first, then guard: "final next = await …; if (!ref.mounted) return; state = next;".',
        ),
      ]);
    });

    test('reports unguarded this.state assignment after await', () async {
      final result = await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/providers/todo_notifier.dart': '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load() async {
    await fetchTodo();
    this.state = AsyncData(todo);
  }
}
''',
            },
            definingFile:
                'lib/features/todo/presentation/providers/todo_notifier.dart',
          );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath:
              'lib/features/todo/presentation/providers/todo_notifier.dart',
          codeName: 'riverpod_state_after_async_gap',
          problemMessage:
              'Avoid assigning to state after an async gap in Riverpod providers (Riverpod 3 throws UnmountedRefException once the provider is disposed).',
          correctionMessage:
              'Await into a local first, then guard: "final next = await …; if (!ref.mounted) return; state = next;".',
        ),
      ]);
    });

    test(
      'does not report state assignment guarded by ref.mounted after await',
      () async {
        final result =
            await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule()).analyze(
              files: {
                'lib/features/todo/presentation/providers/todo_notifier.dart':
                    '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load() async {
    await fetchTodo();
    if (!ref.mounted) return;
    state = AsyncData(todo);
  }
}
''',
              },
              definingFile:
                  'lib/features/todo/presentation/providers/todo_notifier.dart',
            );

        result.expectNoDiagnostics();
      },
    );

    test(
      'does not report state assignment inside if (ref.mounted) after await',
      () async {
        final result =
            await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule()).analyze(
              files: {
                'lib/features/todo/presentation/providers/todo_notifier.dart':
                    '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load() async {
    await fetchTodo();
    if (ref.mounted) {
      state = AsyncData(todo);
    }
  }
}
''',
              },
              definingFile:
                  'lib/features/todo/presentation/providers/todo_notifier.dart',
            );

        result.expectNoDiagnostics();
      },
    );

    test(
      'still reports state assignment when a later await invalidates an earlier guard',
      () async {
        final result =
            await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule()).analyze(
              files: {
                'lib/features/todo/presentation/providers/todo_notifier.dart':
                    '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load() async {
    await fetchTodo();
    if (!ref.mounted) return;
    await fetchMore();
    state = AsyncData(todo);
  }
}
''',
              },
              definingFile:
                  'lib/features/todo/presentation/providers/todo_notifier.dart',
            );

        result.expectDiagnostics([
          const ExpectedV2Diagnostic(
            relativePath:
                'lib/features/todo/presentation/providers/todo_notifier.dart',
            codeName: 'riverpod_state_after_async_gap',
            problemMessage:
                'Avoid assigning to state after an async gap in Riverpod providers (Riverpod 3 throws UnmountedRefException once the provider is disposed).',
            correctionMessage:
                'Await into a local first, then guard: "final next = await …; if (!ref.mounted) return; state = next;".',
          ),
        ]);
      },
    );

    test('does not report state assignment before await', () async {
      final result = await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/providers/todo_notifier.dart': '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load() async {
    state = const AsyncLoading();
    await fetchTodo();
  }
}
''',
            },
            definingFile:
                'lib/features/todo/presentation/providers/todo_notifier.dart',
          );

      result.expectNoDiagnostics();
    });

    test('reports state assignment whose RHS contains await', () async {
      final result = await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/providers/todo_notifier.dart': '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load() async {
    state = await fetchTodo();
  }
}
''',
            },
            definingFile:
                'lib/features/todo/presentation/providers/todo_notifier.dart',
          );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath:
              'lib/features/todo/presentation/providers/todo_notifier.dart',
          codeName: 'riverpod_state_after_async_gap',
          problemMessage:
              'Avoid assigning to state after an async gap in Riverpod providers (Riverpod 3 throws UnmountedRefException once the provider is disposed).',
          correctionMessage:
              'Await into a local first, then guard: "final next = await …; if (!ref.mounted) return; state = next;".',
        ),
      ]);
    });

    test('still reports state = await after a preceding mounted guard', () async {
      final result = await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/providers/todo_notifier.dart': '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load() async {
    if (!ref.mounted) return;
    state = await fetchTodo();
  }
}
''',
            },
            definingFile:
                'lib/features/todo/presentation/providers/todo_notifier.dart',
          );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath:
              'lib/features/todo/presentation/providers/todo_notifier.dart',
          codeName: 'riverpod_state_after_async_gap',
          problemMessage:
              'Avoid assigning to state after an async gap in Riverpod providers (Riverpod 3 throws UnmountedRefException once the provider is disposed).',
          correctionMessage:
              'Await into a local first, then guard: "final next = await …; if (!ref.mounted) return; state = next;".',
        ),
      ]);
    });
    test(
      'does not report ref calls after await (ref rule owns them)',
      () async {
        final result =
            await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule()).analyze(
              files: {
                'lib/features/todo/presentation/providers/todo_notifier.dart':
                    '''
class riverpod {
  const riverpod();
}

@riverpod
class TodoNotifier {
  Future<void> createTodo() async {
    await saveTodo();
    final todo = ref.read(todoProvider);
    ref.invalidate(todoProvider);
  }
}
''',
              },
              definingFile:
                  'lib/features/todo/presentation/providers/todo_notifier.dart',
            );

        result.expectNoDiagnostics();
      },
    );
  });
}
