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
  });
}
