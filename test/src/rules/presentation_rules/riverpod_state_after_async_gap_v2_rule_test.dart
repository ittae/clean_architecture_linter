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
              'Guard right after the await ("await …; if (!ref.mounted) return;"), or await into a local first: "final next = await …; if (!ref.mounted) return; state = next;".',
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
              'Guard right after the await ("await …; if (!ref.mounted) return;"), or await into a local first: "final next = await …; if (!ref.mounted) return; state = next;".',
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
                'Guard right after the await ("await …; if (!ref.mounted) return;"), or await into a local first: "final next = await …; if (!ref.mounted) return; state = next;".',
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
              'Guard right after the await ("await …; if (!ref.mounted) return;"), or await into a local first: "final next = await …; if (!ref.mounted) return; state = next;".',
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
              'Guard right after the await ("await …; if (!ref.mounted) return;"), or await into a local first: "final next = await …; if (!ref.mounted) return; state = next;".',
        ),
      ]);
    });
    test('reports state read after await (getter throws when disposed)', () async {
      final result = await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/providers/todo_notifier.dart': '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load() async {
    await fetchTodo();
    final current = state.session;
    use(current);
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
              'Avoid reading state after an async gap in Riverpod providers (the state getter throws UnmountedRefException once the provider is disposed).',
          correctionMessage:
              'Guard right after the await ("await …; if (!ref.mounted) return;"), or capture the needed state values before the await.',
        ),
      ]);
    });

    test('reports this.state read after await', () async {
      final result = await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/providers/todo_notifier.dart': '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load() async {
    await fetchTodo();
    use(this.state.session);
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
              'Avoid reading state after an async gap in Riverpod providers (the state getter throws UnmountedRefException once the provider is disposed).',
          correctionMessage:
              'Guard right after the await ("await …; if (!ref.mounted) return;"), or capture the needed state values before the await.',
        ),
      ]);
    });

    test('does not report state read guarded right after the await', () async {
      final result = await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/providers/todo_notifier.dart': '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load() async {
    await fetchTodo();
    if (!ref.mounted) return;
    final current = state.session;
    state = state.copyWith(session: current);
  }
}
''',
            },
            definingFile:
                'lib/features/todo/presentation/providers/todo_notifier.dart',
          );

      result.expectNoDiagnostics();
    });

    test('reports the late guard once: read before guard, write after', () async {
      final result = await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/providers/todo_notifier.dart': '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load() async {
    await fetchTodo();
    final current = state.session;
    if (!ref.mounted) return;
    state = state.copyWith(session: current);
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
              'Avoid reading state after an async gap in Riverpod providers (the state getter throws UnmountedRefException once the provider is disposed).',
          correctionMessage:
              'Guard right after the await ("await …; if (!ref.mounted) return;"), or capture the needed state values before the await.',
        ),
      ]);
    });

    test(
      'reports state = state.copyWith after await as a single write finding',
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
    state = state.copyWith(loading: false);
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
                'Guard right after the await ("await …; if (!ref.mounted) return;"), or await into a local first: "final next = await …; if (!ref.mounted) return; state = next;".',
          ),
        ]);
      },
    );

    test('reports several reads in one statement once', () async {
      final result = await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/providers/todo_notifier.dart': '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load() async {
    await fetchTodo();
    use(state.a + state.b);
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
              'Avoid reading state after an async gap in Riverpod providers (the state getter throws UnmountedRefException once the provider is disposed).',
          correctionMessage:
              'Guard right after the await ("await …; if (!ref.mounted) return;"), or capture the needed state values before the await.',
        ),
      ]);
    });

    test('does not report state read before the await', () async {
      final result = await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/providers/todo_notifier.dart': '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load() async {
    final current = state.session;
    await save(current);
  }
}
''',
            },
            definingFile:
                'lib/features/todo/presentation/providers/todo_notifier.dart',
          );

      result.expectNoDiagnostics();
    });

    test('reports state read after await in the same statement', () async {
      final result = await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/providers/todo_notifier.dart': '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load() async {
    final current = await fetchTodo() ?? state.session;
    use(current);
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
              'Avoid reading state after an async gap in Riverpod providers (the state getter throws UnmountedRefException once the provider is disposed).',
          correctionMessage:
              'Guard right after the await ("await …; if (!ref.mounted) return;"), or capture the needed state values before the await.',
        ),
      ]);
    });

    test('reports state read in a later argument after await', () async {
      final result = await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/providers/todo_notifier.dart': '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load() async {
    use(await fetchTodo(), state.session);
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
              'Avoid reading state after an async gap in Riverpod providers (the state getter throws UnmountedRefException once the provider is disposed).',
          correctionMessage:
              'Guard right after the await ("await …; if (!ref.mounted) return;"), or capture the needed state values before the await.',
        ),
      ]);
    });

    test(
      'does not report state receiver evaluated before await argument',
      () async {
        final result =
            await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule()).analyze(
              files: {
                'lib/features/todo/presentation/providers/todo_notifier.dart':
                    '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load() async {
    state.apply(await fetchTodo());
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

    test('does not report state argument evaluated before the await', () async {
      final result = await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/providers/todo_notifier.dart': '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load() async {
    await save(state.session);
  }
}
''',
            },
            definingFile:
                'lib/features/todo/presentation/providers/todo_notifier.dart',
          );

      result.expectNoDiagnostics();
    });

    test('does not report lambda parameter named state after await', () async {
      final result = await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/providers/todo_notifier.dart': '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load() async {
    await fetchTodo();
    items.where((state) => state.active);
  }
}
''',
            },
            definingFile:
                'lib/features/todo/presentation/providers/todo_notifier.dart',
          );

      result.expectNoDiagnostics();
    });

    test(
      'reports this.state capture after await and ignores the local named state',
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
    final state = this.state;
    use(state);
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
                'Avoid reading state after an async gap in Riverpod providers (the state getter throws UnmountedRefException once the provider is disposed).',
            correctionMessage:
                'Guard right after the await ("await …; if (!ref.mounted) return;"), or capture the needed state values before the await.',
          ),
        ]);
      },
    );

    test(
      'does not report other objects state or named argument labels',
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
    use(other.state);
    build(state: 1);
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

    test('reports state read inside a Stream.listen callback after the gap', () async {
      final result = await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/providers/todo_notifier.dart': '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  void start(Stream<int> todos) {
    todos.listen((_) {
      use(state.session);
    });
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
              'Avoid reading state after an async gap in Riverpod providers (the state getter throws UnmountedRefException once the provider is disposed).',
          correctionMessage:
              'Guard right after the await ("await …; if (!ref.mounted) return;"), or capture the needed state values before the await.',
        ),
      ]);
    });

    test('reports state read inside then callback after the gap', () async {
      final result = await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/providers/todo_notifier.dart': '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  void load() {
    fetchTodo().then((_) {
      use(state.session);
    });
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
              'Avoid reading state after an async gap in Riverpod providers (the state getter throws UnmountedRefException once the provider is disposed).',
          correctionMessage:
              'Guard right after the await ("await …; if (!ref.mounted) return;"), or capture the needed state values before the await.',
        ),
      ]);
    });

    test(
      'does not duplicate state reads in an async Stream.listen callback',
      () async {
        final result =
            await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule()).analyze(
              files: {
                'lib/features/todo/presentation/providers/todo_notifier.dart':
                    '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  void start(Stream<int> todos) {
    todos.listen((_) async {
      await fetchTodo();
      use(state.session);
    });
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
                'Avoid reading state after an async gap in Riverpod providers (the state getter throws UnmountedRefException once the provider is disposed).',
            correctionMessage:
                'Guard right after the await ("await …; if (!ref.mounted) return;"), or capture the needed state values before the await.',
          ),
        ]);
      },
    );

    test(
      'does not report state read in an assignment target evaluated before the RHS await',
      () async {
        final result =
            await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule()).analyze(
              files: {
                'lib/features/todo/presentation/providers/todo_notifier.dart':
                    '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load() async {
    items[state.selectedIndex] = await computeValue();
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
      'reports state read on the RHS after an awaiting assignment target',
      () async {
        final result =
            await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule()).analyze(
              files: {
                'lib/features/todo/presentation/providers/todo_notifier.dart':
                    '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load() async {
    (await fetchContainer()).value = state;
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
                'Avoid reading state after an async gap in Riverpod providers (the state getter throws UnmountedRefException once the provider is disposed).',
            correctionMessage:
                'Guard right after the await ("await …; if (!ref.mounted) return;"), or capture the needed state values before the await.',
          ),
        ]);
      },
    );

    test(
      'does not report a local named state declared in an unbraced case body',
      () async {
        final result =
            await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule()).analyze(
              files: {
                'lib/features/todo/presentation/providers/todo_notifier.dart':
                    '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load(int kind) async {
    await fetchTodo();
    switch (kind) {
      case 1:
        final state = 3;
        use(state);
        break;
      default:
        break;
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
      'does not report a guarded read inside an if whose condition awaits',
      () async {
        final result =
            await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule()).analyze(
              files: {
                'lib/features/todo/presentation/providers/todo_notifier.dart':
                    '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load() async {
    if (await fetchTodo()) {
      if (!ref.mounted) return;
      use(state.session);
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

    test('reports an unguarded read inside an if whose condition awaits', () async {
      final result = await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/providers/todo_notifier.dart': '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load() async {
    if (await fetchTodo()) use(state.session);
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
              'Avoid reading state after an async gap in Riverpod providers (the state getter throws UnmountedRefException once the provider is disposed).',
          correctionMessage:
              'Guard right after the await ("await …; if (!ref.mounted) return;"), or capture the needed state values before the await.',
        ),
      ]);
    });

    test(
      'reports an unguarded read inside a while whose condition awaits',
      () async {
        final result =
            await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule()).analyze(
              files: {
                'lib/features/todo/presentation/providers/todo_notifier.dart':
                    '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load() async {
    while (await hasMore()) {
      use(state.session);
      break;
    }
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
                'Avoid reading state after an async gap in Riverpod providers (the state getter throws UnmountedRefException once the provider is disposed).',
            correctionMessage:
                'Guard right after the await ("await …; if (!ref.mounted) return;"), or capture the needed state values before the await.',
          ),
        ]);
      },
    );

    test(
      'reports an unguarded read inside a for-in over an awaited iterable',
      () async {
        final result =
            await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule()).analyze(
              files: {
                'lib/features/todo/presentation/providers/todo_notifier.dart':
                    '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load() async {
    for (final item in await fetchItems()) {
      use(state.session, item);
    }
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
                'Avoid reading state after an async gap in Riverpod providers (the state getter throws UnmountedRefException once the provider is disposed).',
            correctionMessage:
                'Guard right after the await ("await …; if (!ref.mounted) return;"), or capture the needed state values before the await.',
          ),
        ]);
      },
    );

    test(
      'does not report a guarded read inside a while whose condition awaits',
      () async {
        final result =
            await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule()).analyze(
              files: {
                'lib/features/todo/presentation/providers/todo_notifier.dart':
                    '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load() async {
    while (await hasMore()) {
      if (!ref.mounted) return;
      use(state.session);
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

    test('reports a read in a switch statement whose scrutinee awaits', () async {
      final result = await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/providers/todo_notifier.dart': '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load() async {
    switch (await fetchTodo()) {
      case true:
        use(state.session);
      default:
        break;
    }
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
              'Avoid reading state after an async gap in Riverpod providers (the state getter throws UnmountedRefException once the provider is disposed).',
          correctionMessage:
              'Guard right after the await ("await …; if (!ref.mounted) return;"), or capture the needed state values before the await.',
        ),
      ]);
    });

    test('reports a read in a switch expression whose scrutinee awaits', () async {
      final result = await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/providers/todo_notifier.dart': '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load() async {
    final next = switch (await fetchTodo()) { _ => state };
    use(next);
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
              'Avoid reading state after an async gap in Riverpod providers (the state getter throws UnmountedRefException once the provider is disposed).',
          correctionMessage:
              'Guard right after the await ("await …; if (!ref.mounted) return;"), or capture the needed state values before the await.',
        ),
      ]);
    });

    test('reports a read in a record literal after an awaited field', () async {
      final result = await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/providers/todo_notifier.dart': '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load() async {
    final pair = (await fetchTodo(), state);
    use(pair);
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
              'Avoid reading state after an async gap in Riverpod providers (the state getter throws UnmountedRefException once the provider is disposed).',
          correctionMessage:
              'Guard right after the await ("await …; if (!ref.mounted) return;"), or capture the needed state values before the await.',
        ),
      ]);
    });

    test(
      'reports a read in a collection if-element whose condition awaits',
      () async {
        final result =
            await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule()).analyze(
              files: {
                'lib/features/todo/presentation/providers/todo_notifier.dart':
                    '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load() async {
    final xs = [if (await ok()) state];
    use(xs);
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
                'Avoid reading state after an async gap in Riverpod providers (the state getter throws UnmountedRefException once the provider is disposed).',
            correctionMessage:
                'Guard right after the await ("await …; if (!ref.mounted) return;"), or capture the needed state values before the await.',
          ),
        ]);
      },
    );

    test(
      'does not report a pattern variable named state from if-case',
      () async {
        final result =
            await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule()).analyze(
              files: {
                'lib/features/todo/presentation/providers/todo_notifier.dart':
                    '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load(Object value) async {
    await fetchTodo();
    if (value case final state) use(state);
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
      'does not report a pattern variable named state from a switch pattern case',
      () async {
        final result =
            await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule()).analyze(
              files: {
                'lib/features/todo/presentation/providers/todo_notifier.dart':
                    '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load(Object value) async {
    await fetchTodo();
    switch (value) {
      case Foo(:final state):
        use(state);
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
      'does not report a pattern variable named state from a pattern declaration',
      () async {
        final result =
            await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule()).analyze(
              files: {
                'lib/features/todo/presentation/providers/todo_notifier.dart':
                    '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load(Object value) async {
    await fetchTodo();
    var Bar(:state) = value;
    use(state);
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
      'reports a read in a collection for-element whose initializer awaits',
      () async {
        final result =
            await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule()).analyze(
              files: {
                'lib/features/todo/presentation/providers/todo_notifier.dart':
                    '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load() async {
    final xs = [for (var i = await start(); i < 1; i++) state];
    use(xs);
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
                'Avoid reading state after an async gap in Riverpod providers (the state getter throws UnmountedRefException once the provider is disposed).',
            correctionMessage:
                'Guard right after the await ("await …; if (!ref.mounted) return;"), or capture the needed state values before the await.',
          ),
        ]);
      },
    );

    test('reports a read after an await in an unbraced case body', () async {
      final result = await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/providers/todo_notifier.dart': '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load(int kind) async {
    switch (kind) {
      case 1:
        await fetchTodo();
        use(state.session);
        break;
      default:
        break;
    }
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
              'Avoid reading state after an async gap in Riverpod providers (the state getter throws UnmountedRefException once the provider is disposed).',
          correctionMessage:
              'Guard right after the await ("await …; if (!ref.mounted) return;"), or capture the needed state values before the await.',
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
    test(
      'does not report a read guarded right after the await in an unbraced case body',
      () async {
        final result =
            await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule()).analyze(
              files: {
                'lib/features/todo/presentation/providers/todo_notifier.dart':
                    '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load(int kind) async {
    switch (kind) {
      case 1:
        await fetchTodo();
        if (!ref.mounted) return;
        use(state.session);
        state = next;
        break;
      default:
        break;
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
      'reports a read in the else branch of an if-case that binds state',
      () async {
        final result =
            await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule()).analyze(
              files: {
                'lib/features/todo/presentation/providers/todo_notifier.dart':
                    '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load(Object? value) async {
    await fetchTodo();
    if (value case final state when state != null) {
      use(state);
    } else {
      use(state.session);
    }
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
                'Avoid reading state after an async gap in Riverpod providers (the state getter throws UnmountedRefException once the provider is disposed).',
            correctionMessage:
                'Guard right after the await ("await …; if (!ref.mounted) return;"), or capture the needed state values before the await.',
          ),
        ]);
      },
    );

    test(
      'reports a read in the else element of an if-case that binds state',
      () async {
        final result =
            await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule()).analyze(
              files: {
                'lib/features/todo/presentation/providers/todo_notifier.dart':
                    '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load(Object? value) async {
    await fetchTodo();
    final xs = [if (value case final state) state else state.session];
    use(xs);
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
                'Avoid reading state after an async gap in Riverpod providers (the state getter throws UnmountedRefException once the provider is disposed).',
            correctionMessage:
                'Guard right after the await ("await …; if (!ref.mounted) return;"), or capture the needed state values before the await.',
          ),
        ]);
      },
    );

    test('reports a map value read after an awaited key', () async {
      final result = await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/providers/todo_notifier.dart': '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load() async {
    final map = {await fetchKey(): state.session};
    use(map);
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
              'Avoid reading state after an async gap in Riverpod providers (the state getter throws UnmountedRefException once the provider is disposed).',
          correctionMessage:
              'Guard right after the await ("await …; if (!ref.mounted) return;"), or capture the needed state values before the await.',
        ),
      ]);
    });

    test('does not report a map key read before an awaited value', () async {
      final result = await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/providers/todo_notifier.dart': '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load() async {
    final map = {state.session: await fetchValue()};
    use(map);
  }
}
''',
            },
            definingFile:
                'lib/features/todo/presentation/providers/todo_notifier.dart',
          );

      result.expectNoDiagnostics();
    });

    test(
      'does not report a local state bound by a for-loop pattern declaration',
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
    for (var (state, i) = (0, 0); i < 1; i++) {
      use(state);
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
      'reports a read in a for-loop body whose pattern initializer awaits',
      () async {
        final result =
            await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule()).analyze(
              files: {
                'lib/features/todo/presentation/providers/todo_notifier.dart':
                    '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load() async {
    for (var (a, i) = (await fetchTodo(), 0); i < 1; i++) {
      use(state.session);
    }
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
                'Avoid reading state after an async gap in Riverpod providers (the state getter throws UnmountedRefException once the provider is disposed).',
            correctionMessage:
                'Guard right after the await ("await …; if (!ref.mounted) return;"), or capture the needed state values before the await.',
          ),
        ]);
      },
    );
    test('reports a read inside an await-for body', () async {
      final result = await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/providers/todo_notifier.dart': '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load(Stream<int> stream) async {
    await for (final item in stream) {
      use(state.session);
    }
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
              'Avoid reading state after an async gap in Riverpod providers (the state getter throws UnmountedRefException once the provider is disposed).',
          correctionMessage:
              'Guard right after the await ("await …; if (!ref.mounted) return;"), or capture the needed state values before the await.',
        ),
      ]);
    });

    test('reports a read after a preceding await-for statement', () async {
      final result = await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/providers/todo_notifier.dart': '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load(Stream<int> stream) async {
    await for (final item in stream) {
      use(item);
    }
    use(state.session);
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
              'Avoid reading state after an async gap in Riverpod providers (the state getter throws UnmountedRefException once the provider is disposed).',
          correctionMessage:
              'Guard right after the await ("await …; if (!ref.mounted) return;"), or capture the needed state values before the await.',
        ),
      ]);
    });

    test(
      'reports a read in the then branch of an if-case whose when guard awaits',
      () async {
        final result =
            await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule()).analyze(
              files: {
                'lib/features/todo/presentation/providers/todo_notifier.dart':
                    '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load(Object? value) async {
    if (value case final x when await pred(x)) {
      use(state.session);
    }
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
                'Avoid reading state after an async gap in Riverpod providers (the state getter throws UnmountedRefException once the provider is disposed).',
            correctionMessage:
                'Guard right after the await ("await …; if (!ref.mounted) return;"), or capture the needed state values before the await.',
          ),
        ]);
      },
    );

    test('reports a read in a switch case whose when guard awaits', () async {
      final result = await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/providers/todo_notifier.dart': '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load(Object? value) async {
    switch (value) {
      case final x when await pred(x):
        use(state.session);
      default:
        break;
    }
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
              'Avoid reading state after an async gap in Riverpod providers (the state getter throws UnmountedRefException once the provider is disposed).',
          correctionMessage:
              'Guard right after the await ("await …; if (!ref.mounted) return;"), or capture the needed state values before the await.',
        ),
      ]);
    });

    test(
      'reports a read in a switch expression case whose when guard awaits',
      () async {
        final result =
            await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule()).analyze(
              files: {
                'lib/features/todo/presentation/providers/todo_notifier.dart':
                    '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load(Object? value) async {
    final s = switch (value) {
      final x when await pred(x) => state.session,
      _ => null,
    };
    use(s);
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
                'Avoid reading state after an async gap in Riverpod providers (the state getter throws UnmountedRefException once the provider is disposed).',
            correctionMessage:
                'Guard right after the await ("await …; if (!ref.mounted) return;"), or capture the needed state values before the await.',
          ),
        ]);
      },
    );

    test('reports an unguarded super.state read after await', () async {
      final result = await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/providers/todo_notifier.dart': '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load() async {
    await fetchTodo();
    use(super.state.session);
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
              'Avoid reading state after an async gap in Riverpod providers (the state getter throws UnmountedRefException once the provider is disposed).',
          correctionMessage:
              'Guard right after the await ("await …; if (!ref.mounted) return;"), or capture the needed state values before the await.',
        ),
      ]);
    });

    test(
      'reports an unguarded parenthesized this.state read after await',
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
    use((this).state.session);
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
                'Avoid reading state after an async gap in Riverpod providers (the state getter throws UnmountedRefException once the provider is disposed).',
            correctionMessage:
                'Guard right after the await ("await …; if (!ref.mounted) return;"), or capture the needed state values before the await.',
          ),
        ]);
      },
    );

    test(
      'does not report a read guarded right after an await-for loop',
      () async {
        final result =
            await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule()).analyze(
              files: {
                'lib/features/todo/presentation/providers/todo_notifier.dart':
                    '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load(Stream<int> stream) async {
    await for (final item in stream) {
      use(item);
    }
    if (!ref.mounted) return;
    use(state.session);
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
    test('reports a when-guard read after an awaited if-case scrutinee', () async {
      final result = await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/providers/todo_notifier.dart': '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load() async {
    if (await getValue() case final x when state.ready) {
      use(x);
    }
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
              'Avoid reading state after an async gap in Riverpod providers (the state getter throws UnmountedRefException once the provider is disposed).',
          correctionMessage:
              'Guard right after the await ("await …; if (!ref.mounted) return;"), or capture the needed state values before the await.',
        ),
      ]);
    });

    test(
      'reports a when-guard read after an awaited if-element scrutinee',
      () async {
        final result =
            await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule()).analyze(
              files: {
                'lib/features/todo/presentation/providers/todo_notifier.dart':
                    '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load() async {
    final xs = [if (await getValue() case final x when state.ready) x];
    use(xs);
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
                'Avoid reading state after an async gap in Riverpod providers (the state getter throws UnmountedRefException once the provider is disposed).',
            correctionMessage:
                'Guard right after the await ("await …; if (!ref.mounted) return;"), or capture the needed state values before the await.',
          ),
        ]);
      },
    );
    test(
      'reports a later switch expression case after an earlier case whose when guard awaits',
      () async {
        final result =
            await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule()).analyze(
              files: {
                'lib/features/todo/presentation/providers/todo_notifier.dart':
                    '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load(Object? value) async {
    final s = switch (value) {
      final x when await pred(x) => null,
      _ => state.session,
    };
    use(s);
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
                'Avoid reading state after an async gap in Riverpod providers (the state getter throws UnmountedRefException once the provider is disposed).',
            correctionMessage:
                'Guard right after the await ("await …; if (!ref.mounted) return;"), or capture the needed state values before the await.',
          ),
        ]);
      },
    );

    test(
      'reports a for-loop condition read after an awaited initializer',
      () async {
        final result =
            await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule()).analyze(
              files: {
                'lib/features/todo/presentation/providers/todo_notifier.dart':
                    '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load() async {
    for (var i = await start(); i < state.n; i++) {
      use(i);
    }
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
                'Avoid reading state after an async gap in Riverpod providers (the state getter throws UnmountedRefException once the provider is disposed).',
            correctionMessage:
                'Guard right after the await ("await …; if (!ref.mounted) return;"), or capture the needed state values before the await.',
          ),
        ]);
      },
    );

    test(
      'reports a for-element condition read after an awaited initializer',
      () async {
        final result =
            await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule()).analyze(
              files: {
                'lib/features/todo/presentation/providers/todo_notifier.dart':
                    '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load() async {
    final xs = [for (var i = await start(); i < state.n; i++) i];
    use(xs);
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
                'Avoid reading state after an async gap in Riverpod providers (the state getter throws UnmountedRefException once the provider is disposed).',
            correctionMessage:
                'Guard right after the await ("await …; if (!ref.mounted) return;"), or capture the needed state values before the await.',
          ),
        ]);
      },
    );

    test(
      'reports a for-loop initializer that reads the getter into a local named state',
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
    for (var state = state.session; state != null; state = null) {
      use(state);
    }
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
                'Avoid reading state after an async gap in Riverpod providers (the state getter throws UnmountedRefException once the provider is disposed).',
            correctionMessage:
                'Guard right after the await ("await …; if (!ref.mounted) return;"), or capture the needed state values before the await.',
          ),
        ]);
      },
    );

    test(
      'reports a for-in iterable that reads the getter into a local named state',
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
    for (final state in state.items) {
      use(state);
    }
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
                'Avoid reading state after an async gap in Riverpod providers (the state getter throws UnmountedRefException once the provider is disposed).',
            correctionMessage:
                'Guard right after the await ("await …; if (!ref.mounted) return;"), or capture the needed state values before the await.',
          ),
        ]);
      },
    );

    test(
      'does not report a for-loop body read of a local named state',
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
    for (var state = 0; state < 1; state++) {
      use(state);
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
    test('does not report an assignment to a local named state', () async {
      final result = await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/providers/todo_notifier.dart': '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load() async {
    var state = 0;
    await fetchTodo();
    state = 1;
    use(state);
  }
}
''',
            },
            definingFile:
                'lib/features/todo/presentation/providers/todo_notifier.dart',
          );

      result.expectNoDiagnostics();
    });
    test('reports unguarded super.state assignment after await', () async {
      final result = await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/providers/todo_notifier.dart': '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load() async {
    await fetchTodo();
    super.state = AsyncData(todo);
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
              'Guard right after the await ("await …; if (!ref.mounted) return;"), or await into a local first: "final next = await …; if (!ref.mounted) return; state = next;".',
        ),
      ]);
    });
    test(
      'reports unguarded parenthesized this.state assignment after await',
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
    (this).state = AsyncData(todo);
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
                'Guard right after the await ("await …; if (!ref.mounted) return;"), or await into a local first: "final next = await …; if (!ref.mounted) return; state = next;".',
          ),
        ]);
      },
    );

    test('reports a for-loop condition read after an awaited updater', () async {
      final result = await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/providers/todo_notifier.dart': '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load() async {
    for (var i = 0; i < state.n; i += await step()) {}
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
              'Avoid reading state after an async gap in Riverpod providers (the state getter throws UnmountedRefException once the provider is disposed).',
          correctionMessage:
              'Guard right after the await ("await …; if (!ref.mounted) return;"), or capture the needed state values before the await.',
        ),
      ]);
    });

    test('reports a do-while condition read after an awaited body', () async {
      final result = await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/providers/todo_notifier.dart': '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load() async {
    do {
      await f();
    } while (state.ready);
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
              'Avoid reading state after an async gap in Riverpod providers (the state getter throws UnmountedRefException once the provider is disposed).',
          correctionMessage:
              'Guard right after the await ("await …; if (!ref.mounted) return;"), or capture the needed state values before the await.',
        ),
      ]);
    });

    test(
      'does not report a do-while condition read when the body has no await',
      () async {
        final result =
            await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule()).analyze(
              files: {
                'lib/features/todo/presentation/providers/todo_notifier.dart':
                    '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load() async {
    do {
      use(1);
    } while (state.ready);
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
      'does not report a do-while condition read guarded by ref.mounted after the body await',
      () async {
        final result =
            await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule()).analyze(
              files: {
                'lib/features/todo/presentation/providers/todo_notifier.dart':
                    '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load() async {
    do {
      await f();
      if (!ref.mounted) return;
    } while (state.ready);
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
      'reports a do-while condition read when an await follows the body guard',
      () async {
        final result =
            await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule()).analyze(
              files: {
                'lib/features/todo/presentation/providers/todo_notifier.dart':
                    '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load() async {
    do {
      if (!ref.mounted) return;
      await g();
    } while (state.ready);
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
                'Avoid reading state after an async gap in Riverpod providers (the state getter throws UnmountedRefException once the provider is disposed).',
            correctionMessage:
                'Guard right after the await ("await …; if (!ref.mounted) return;"), or capture the needed state values before the await.',
          ),
        ]);
      },
    );

    test(
      'reports a do-while condition read for an unbraced awaiting body',
      () async {
        final result =
            await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule()).analyze(
              files: {
                'lib/features/todo/presentation/providers/todo_notifier.dart':
                    '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load() async {
    do await f(); while (state.ready);
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
                'Avoid reading state after an async gap in Riverpod providers (the state getter throws UnmountedRefException once the provider is disposed).',
            correctionMessage:
                'Guard right after the await ("await …; if (!ref.mounted) return;"), or capture the needed state values before the await.',
          ),
        ]);
      },
    );

    test(
      'reports an outer do-while condition read even when the nested do-while\'s own body ends in a guard (documented conservative limitation)',
      () async {
        // A nested do-while's tail guard is only recognized for that nested
        // loop's own condition, not for an outer loop's condition or a
        // sibling statement that follows it — see the README's
        // riverpod_state_after_async_gap section. This over-reports rather
        // than risk missing a real gap.
        final result =
            await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule()).analyze(
              files: {
                'lib/features/todo/presentation/providers/todo_notifier.dart':
                    '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load(bool innerCond) async {
    do {
      do {
        await f();
        if (!ref.mounted) return;
      } while (innerCond);
    } while (state.outer);
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
                'Avoid reading state after an async gap in Riverpod providers (the state getter throws UnmountedRefException once the provider is disposed).',
            correctionMessage:
                'Guard right after the await ("await …; if (!ref.mounted) return;"), or capture the needed state values before the await.',
          ),
        ]);
      },
    );

    test(
      'reports a do-while condition read when a continue can skip the body guard',
      () async {
        // `continue` in a do-while jumps straight to the condition check,
        // bypassing the guard placed after it on that path.
        final result =
            await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule()).analyze(
              files: {
                'lib/features/todo/presentation/providers/todo_notifier.dart':
                    '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load(bool x) async {
    do {
      await f();
      if (x) continue;
      if (!ref.mounted) return;
    } while (state.c);
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
                'Avoid reading state after an async gap in Riverpod providers (the state getter throws UnmountedRefException once the provider is disposed).',
            correctionMessage:
                'Guard right after the await ("await …; if (!ref.mounted) return;"), or capture the needed state values before the await.',
          ),
        ]);
      },
    );

    test(
      'does not report a do-while condition guarded after a body switch whose break only exits the switch',
      () async {
        // An unlabeled `break` inside a `switch` only terminates the switch;
        // it cannot reach the condition or skip past the loop, so it must
        // not stop the tail guard from being trusted.
        final result =
            await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule()).analyze(
              files: {
                'lib/features/todo/presentation/providers/todo_notifier.dart':
                    '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load(int k) async {
    do {
      await f();
      switch (k) {
        case 1:
          use(1);
          break;
        default:
          break;
      }
      if (!ref.mounted) return;
    } while (state.ready);
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
      'reports a do-while condition read when a labeled continue inside a switch can skip the guard',
      () async {
        // A labeled `continue` targeting the do-while is loop-scoped
        // regardless of the intervening `switch`, so it must still defeat
        // the tail guard.
        final result =
            await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule()).analyze(
              files: {
                'lib/features/todo/presentation/providers/todo_notifier.dart':
                    '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load(int k) async {
    loop:
    do {
      await f();
      switch (k) {
        case 1:
          continue loop;
        default:
          break;
      }
      if (!ref.mounted) return;
    } while (state.ready);
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
                'Avoid reading state after an async gap in Riverpod providers (the state getter throws UnmountedRefException once the provider is disposed).',
            correctionMessage:
                'Guard right after the await ("await …; if (!ref.mounted) return;"), or capture the needed state values before the await.',
          ),
        ]);
      },
    );

    test(
      'reports a do-while condition read when a body break bypasses the guard even with a stale outer guard present',
      () async {
        // A guard before the do-while does not protect its condition once
        // the body's own `await` runs on the jump-free path: a `break`
        // making the tail guard untrustworthy must not fall back to trusting
        // that stale, earlier guard either.
        final result =
            await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule()).analyze(
              files: {
                'lib/features/todo/presentation/providers/todo_notifier.dart':
                    '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load(bool x) async {
    await g();
    if (!ref.mounted) return;
    do {
      if (x) break;
      await f();
    } while (state.ready);
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
                'Avoid reading state after an async gap in Riverpod providers (the state getter throws UnmountedRefException once the provider is disposed).',
            correctionMessage:
                'Guard right after the await ("await …; if (!ref.mounted) return;"), or capture the needed state values before the await.',
          ),
        ]);
      },
    );

    test(
      'reports a do-while condition read when a body continue bypasses the guard even with a stale outer guard present',
      () async {
        final result =
            await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule()).analyze(
              files: {
                'lib/features/todo/presentation/providers/todo_notifier.dart':
                    '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load(bool x) async {
    await g();
    if (!ref.mounted) return;
    do {
      if (x) continue;
      await f();
    } while (state.ready);
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
                'Avoid reading state after an async gap in Riverpod providers (the state getter throws UnmountedRefException once the provider is disposed).',
            correctionMessage:
                'Guard right after the await ("await …; if (!ref.mounted) return;"), or capture the needed state values before the await.',
          ),
        ]);
      },
    );

    test(
      'does not report a do-while condition read when a jump bypasses a no-await body but an outer guard still holds',
      () async {
        // The body never suspends, so a jump inside it can't invalidate the
        // preceding guard: unlike the other jump-statement cases, this one
        // must fall through to `null` (inconclusive) rather than `false`, so
        // the walk keeps trusting the real guard right before the loop.
        final result =
            await V2RuleHarness(rule: RiverpodStateAfterAsyncGapRule()).analyze(
              files: {
                'lib/features/todo/presentation/providers/todo_notifier.dart':
                    '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load(bool x) async {
    await g();
    if (!ref.mounted) return;
    do {
      if (x) break;
      use(1);
    } while (state.ready);
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
