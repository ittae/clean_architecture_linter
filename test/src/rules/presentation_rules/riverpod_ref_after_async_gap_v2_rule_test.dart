import 'package:clean_architecture_linter/src/rules/presentation_rules/riverpod_ref_after_async_gap_rule.dart';
import 'package:test/test.dart';

import '../../../v2_harness/analysis_rule_harness.dart';

void main() {
  group('RiverpodRefAfterAsyncGapRule v2', () {
    test('reports ref.read after await in public async method', () async {
      final result = await V2RuleHarness(rule: RiverpodRefAfterAsyncGapRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/providers/todo_notifier.dart': '''
class riverpod {
  const riverpod();
}

@riverpod
class TodoNotifier {
  Future<void> createTodo() async {
    await saveTodo();
    final todo = ref.read(todoProvider);
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
          codeName: 'riverpod_ref_after_async_gap',
          problemMessage:
              'Avoid ref.read() after an async gap in Riverpod providers.',
          correctionMessage:
              'Capture provider/usecase dependencies before the async gap, or guard the post-gap access with "if (!ref.mounted) return;".',
        ),
      ]);
    });

    test('reports ref access after await in async callbacks', () async {
      final result = await V2RuleHarness(rule: RiverpodRefAfterAsyncGapRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/providers/todo_notifier.dart': '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  void createTodo() {
    runAsync(() async {
      await saveTodo();
      ref.invalidate(todoProvider);
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
          codeName: 'riverpod_ref_after_async_gap',
          problemMessage:
              'Avoid ref.invalidate() after an async gap in Riverpod providers.',
          correctionMessage:
              'Capture provider/usecase dependencies before the async gap, or guard the post-gap access with "if (!ref.mounted) return;".',
        ),
      ]);
    });

    test('reports ref access inside Future continuation callbacks', () async {
      final result = await V2RuleHarness(rule: RiverpodRefAfterAsyncGapRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/providers/todo_notifier.dart': '''
class riverpod {
  const riverpod();
}

@riverpod
class TodoNotifier {
  void createTodo() {
    fetchTodo().then((_) {
      ref.read(todoProvider);
    });

    fetchTodo().catchError((error) {
      ref.invalidate(todoProvider);
    });

    fetchTodo().whenComplete(() {
      ref.refresh(todoProvider);
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
          codeName: 'riverpod_ref_after_async_gap',
          problemMessage:
              'Avoid ref.read() after an async gap in Riverpod providers.',
          correctionMessage:
              'Capture provider/usecase dependencies before the async gap, or guard the post-gap access with "if (!ref.mounted) return;".',
        ),
        const ExpectedV2Diagnostic(
          relativePath:
              'lib/features/todo/presentation/providers/todo_notifier.dart',
          codeName: 'riverpod_ref_after_async_gap',
          problemMessage:
              'Avoid ref.invalidate() after an async gap in Riverpod providers.',
          correctionMessage:
              'Capture provider/usecase dependencies before the async gap, or guard the post-gap access with "if (!ref.mounted) return;".',
        ),
        const ExpectedV2Diagnostic(
          relativePath:
              'lib/features/todo/presentation/providers/todo_notifier.dart',
          codeName: 'riverpod_ref_after_async_gap',
          problemMessage:
              'Avoid ref.refresh() after an async gap in Riverpod providers.',
          correctionMessage:
              'Capture provider/usecase dependencies before the async gap, or guard the post-gap access with "if (!ref.mounted) return;".',
        ),
      ]);
    });

    test(
      'reports ref access inside an expression-body Future continuation callback',
      () async {
        final result = await V2RuleHarness(rule: RiverpodRefAfterAsyncGapRule())
            .analyze(
              files: {
                'lib/features/todo/presentation/providers/todo_notifier.dart':
                    '''
class riverpod {
  const riverpod();
}

@riverpod
class TodoNotifier {
  void createTodo() {
    fetchTodo().then((_) => ref.read(todoProvider));
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
            codeName: 'riverpod_ref_after_async_gap',
            problemMessage:
                'Avoid ref.read() after an async gap in Riverpod providers.',
            correctionMessage:
                'Capture provider/usecase dependencies before the async gap, or guard the post-gap access with "if (!ref.mounted) return;".',
          ),
        ]);
      },
    );

    test('reports ref access inside a then() onError: named callback', () async {
      final result = await V2RuleHarness(rule: RiverpodRefAfterAsyncGapRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/providers/todo_notifier.dart': '''
class riverpod {
  const riverpod();
}

@riverpod
class TodoNotifier {
  void createTodo() {
    fetchTodo().then((_) {}, onError: (error) {
      ref.read(todoProvider);
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
          codeName: 'riverpod_ref_after_async_gap',
          problemMessage:
              'Avoid ref.read() after an async gap in Riverpod providers.',
          correctionMessage:
              'Capture provider/usecase dependencies before the async gap, or guard the post-gap access with "if (!ref.mounted) return;".',
        ),
      ]);
    });

    test(
      'reports ref access inside a tear-off Future continuation callback',
      () async {
        final result = await V2RuleHarness(rule: RiverpodRefAfterAsyncGapRule())
            .analyze(
              files: {
                'lib/features/todo/presentation/providers/todo_notifier.dart':
                    '''
class riverpod {
  const riverpod();
}

@riverpod
class TodoNotifier {
  void createTodo() {
    void onDone(_) {
      ref.read(todoProvider);
    }

    fetchTodo().then(onDone);
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
            codeName: 'riverpod_ref_after_async_gap',
            problemMessage:
                'Avoid ref.read() after an async gap in Riverpod providers.',
            correctionMessage:
                'Capture provider/usecase dependencies before the async gap, or guard the post-gap access with "if (!ref.mounted) return;".',
          ),
        ]);
      },
    );

    test(
      'does not duplicate Future continuation callback diagnostics in async methods',
      () async {
        final result = await V2RuleHarness(rule: RiverpodRefAfterAsyncGapRule())
            .analyze(
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

    fetchTodo().then((_) {
      ref.read(todoProvider);
    });

    fetchTodo().catchError((error) {
      ref.invalidate(todoProvider);
    });

    fetchTodo().whenComplete(() {
      ref.refresh(todoProvider);
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
            codeName: 'riverpod_ref_after_async_gap',
            problemMessage:
                'Avoid ref.read() after an async gap in Riverpod providers.',
            correctionMessage:
                'Capture provider/usecase dependencies before the async gap, or guard the post-gap access with "if (!ref.mounted) return;".',
          ),
          const ExpectedV2Diagnostic(
            relativePath:
                'lib/features/todo/presentation/providers/todo_notifier.dart',
            codeName: 'riverpod_ref_after_async_gap',
            problemMessage:
                'Avoid ref.invalidate() after an async gap in Riverpod providers.',
            correctionMessage:
                'Capture provider/usecase dependencies before the async gap, or guard the post-gap access with "if (!ref.mounted) return;".',
          ),
          const ExpectedV2Diagnostic(
            relativePath:
                'lib/features/todo/presentation/providers/todo_notifier.dart',
            codeName: 'riverpod_ref_after_async_gap',
            problemMessage:
                'Avoid ref.refresh() after an async gap in Riverpod providers.',
            correctionMessage:
                'Capture provider/usecase dependencies before the async gap, or guard the post-gap access with "if (!ref.mounted) return;".',
          ),
        ]);
      },
    );

    test('reports ref.read after await inside synchronous callbacks', () async {
      final result = await V2RuleHarness(rule: RiverpodRefAfterAsyncGapRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/providers/todo_notifier.dart': '''
class riverpod {
  const riverpod();
}

@riverpod
class TodoNotifier {
  Future<void> createTodo() async {
    await saveTodo();
    [1, 2, 3].forEach((_) {
      ref.read(todoProvider);
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
          codeName: 'riverpod_ref_after_async_gap',
          problemMessage:
              'Avoid ref.read() after an async gap in Riverpod providers.',
          correctionMessage:
              'Capture provider/usecase dependencies before the async gap, or guard the post-gap access with "if (!ref.mounted) return;".',
        ),
      ]);
    });

    test('reports this.ref.read after await', () async {
      final result = await V2RuleHarness(rule: RiverpodRefAfterAsyncGapRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/providers/todo_notifier.dart': '''
class riverpod {
  const riverpod();
}

@riverpod
class TodoNotifier {
  Future<void> createTodo() async {
    await saveTodo();
    this.ref.read(todoProvider);
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
          codeName: 'riverpod_ref_after_async_gap',
          problemMessage:
              'Avoid ref.read() after an async gap in Riverpod providers.',
          correctionMessage:
              'Capture provider/usecase dependencies before the async gap, or guard the post-gap access with "if (!ref.mounted) return;".',
        ),
      ]);
    });

    test(
      'reports ref.invalidate after await inside invoked synchronous local helper',
      () async {
        final result = await V2RuleHarness(rule: RiverpodRefAfterAsyncGapRule())
            .analyze(
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

    void invalidateTodo() {
      ref.invalidate(todoProvider);
    }

    invalidateTodo();
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
            codeName: 'riverpod_ref_after_async_gap',
            problemMessage:
                'Avoid ref.invalidate() after an async gap in Riverpod providers.',
            correctionMessage:
                'Capture provider/usecase dependencies before the async gap, or guard the post-gap access with "if (!ref.mounted) return;".',
          ),
        ]);
      },
    );

    test(
      'does not inherit outer async gap inside async local functions',
      () async {
        final result = await V2RuleHarness(rule: RiverpodRefAfterAsyncGapRule())
            .analyze(
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

    Future<void> invalidateTodo() async {
      ref.invalidate(todoProvider);
    }

    await invalidateTodo();
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

    test('allows provider and usecase capture before await', () async {
      final result = await V2RuleHarness(rule: RiverpodRefAfterAsyncGapRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/providers/todo_notifier.dart': '''
class riverpod {
  const riverpod();
}

@riverpod
class TodoNotifier {
  Future<void> createTodo() async {
    final save = ref.read(saveTodoUseCaseProvider);
    await save();
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
      'does not treat ref reads inside awaited expression as after gap',
      () async {
        final result = await V2RuleHarness(rule: RiverpodRefAfterAsyncGapRule())
            .analyze(
              files: {
                'lib/features/todo/presentation/providers/todo_notifier.dart':
                    '''
class riverpod {
  const riverpod();
}

@riverpod
class TodoNotifier {
  Future<void> createTodo() async {
    await ref.read(saveTodoUseCaseProvider)();
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

    test('ignores private async helper methods', () async {
      final result = await V2RuleHarness(rule: RiverpodRefAfterAsyncGapRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/providers/todo_notifier.dart': '''
class riverpod {
  const riverpod();
}

@riverpod
class TodoNotifier {
  Future<void> _refreshTodo() async {
    await saveTodo();
    ref.refresh(todoProvider);
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
      'does not report ref in else branch when await is only in if branch',
      () async {
        final result = await V2RuleHarness(rule: RiverpodRefAfterAsyncGapRule())
            .analyze(
              files: {
                'lib/features/todo/presentation/providers/todo_notifier.dart':
                    '''
class riverpod {
  const riverpod();
}

@riverpod
class TodoNotifier {
  Future<void> createTodo(bool flag) async {
    if (flag) {
      await saveTodo();
    } else {
      ref.read(todoProvider);
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

    test('does not report ref in a sibling switch case', () async {
      final result = await V2RuleHarness(rule: RiverpodRefAfterAsyncGapRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/providers/todo_notifier.dart': '''
class riverpod {
  const riverpod();
}

@riverpod
class TodoNotifier {
  Future<void> handle(int type) async {
    switch (type) {
      case 0:
        await saveTodo();
      case 1:
        ref.read(todoProvider);
    }
  }
}
''',
            },
            definingFile:
                'lib/features/todo/presentation/providers/todo_notifier.dart',
          );

      result.expectNoDiagnostics();
    });

    test('reports ref after await within the same branch', () async {
      final result = await V2RuleHarness(rule: RiverpodRefAfterAsyncGapRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/providers/todo_notifier.dart': '''
class riverpod {
  const riverpod();
}

@riverpod
class TodoNotifier {
  Future<void> createTodo(bool flag) async {
    if (flag) {
      await saveTodo();
      ref.read(todoProvider);
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
          codeName: 'riverpod_ref_after_async_gap',
          problemMessage:
              'Avoid ref.read() after an async gap in Riverpod providers.',
          correctionMessage:
              'Capture provider/usecase dependencies before the async gap, or guard the post-gap access with "if (!ref.mounted) return;".',
        ),
      ]);
    });

    test('reports ref in catch when await is in the try body', () async {
      final result = await V2RuleHarness(rule: RiverpodRefAfterAsyncGapRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/providers/todo_notifier.dart': '''
class riverpod {
  const riverpod();
}

@riverpod
class TodoNotifier {
  Future<void> createTodo() async {
    try {
      await saveTodo();
    } catch (e) {
      ref.read(todoProvider);
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
          codeName: 'riverpod_ref_after_async_gap',
          problemMessage:
              'Avoid ref.read() after an async gap in Riverpod providers.',
          correctionMessage:
              'Capture provider/usecase dependencies before the async gap, or guard the post-gap access with "if (!ref.mounted) return;".',
        ),
      ]);
    });

    test('skips non-provider, generated, and test files', () async {
      final result = await V2RuleHarness(rule: RiverpodRefAfterAsyncGapRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/notifiers/todo_notifier.dart': '''
class riverpod {
  const riverpod();
}

@riverpod
class TodoNotifier {
  Future<void> createTodo() async {
    await saveTodo();
    ref.watch(todoProvider);
  }
}
''',
              'lib/features/todo/presentation/providers/todo_notifier.g.dart':
                  '''
class riverpod {
  const riverpod();
}

@riverpod
class TodoNotifier {
  Future<void> createTodo() async {
    await saveTodo();
    ref.listen(todoProvider, (_, __) {});
  }
}
''',
              'test/features/todo/presentation/providers/todo_notifier_test.dart':
                  '''
class riverpod {
  const riverpod();
}

@riverpod
class TodoNotifier {
  Future<void> createTodo() async {
    await saveTodo();
    ref.read(todoProvider);
  }
}
''',
            },
            definingFile:
                'lib/features/todo/presentation/notifiers/todo_notifier.dart',
            additionalDefiningFiles: const [
              'lib/features/todo/presentation/providers/todo_notifier.g.dart',
              'test/features/todo/presentation/providers/todo_notifier_test.dart',
            ],
          );

      result.expectNoDiagnostics();
    });

    test('does not report ref usage guarded by ref.mounted', () async {
      final result = await V2RuleHarness(rule: RiverpodRefAfterAsyncGapRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/providers/todo_notifier.dart': '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<bool> save() async {
    await persist();
    if (!ref.mounted) return false;
    ref.invalidate(todoProvider);
    return true;
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
      'does not report ref usage inside an if (ref.mounted) block',
      () async {
        final result = await V2RuleHarness(rule: RiverpodRefAfterAsyncGapRule())
            .analyze(
              files: {
                'lib/features/todo/presentation/providers/todo_notifier.dart':
                    '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> save() async {
    await persist();
    if (ref.mounted) {
      ref.invalidate(todoProvider);
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
      'does not report a guarded ref usage inside a Future continuation',
      () async {
        final result = await V2RuleHarness(rule: RiverpodRefAfterAsyncGapRule())
            .analyze(
              files: {
                'lib/features/todo/presentation/providers/todo_notifier.dart':
                    '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  void save() {
    persist().then((_) {
      if (!ref.mounted) return;
      ref.invalidate(todoProvider);
    });
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
      'does not report ref usage in the else branch of a mounted guard',
      () async {
        final result = await V2RuleHarness(rule: RiverpodRefAfterAsyncGapRule())
            .analyze(
              files: {
                'lib/features/todo/presentation/providers/todo_notifier.dart':
                    '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> save() async {
    await persist();
    if (!ref.mounted) {
      return;
    } else {
      ref.invalidate(todoProvider);
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

    test('still reports in catch when the try body awaits after a guard', () async {
      final result = await V2RuleHarness(rule: RiverpodRefAfterAsyncGapRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/providers/todo_notifier.dart': '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> save() async {
    await persist();
    if (!ref.mounted) return;
    try {
      await persistAgain();
    } catch (_) {
      ref.invalidate(todoProvider);
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
          codeName: 'riverpod_ref_after_async_gap',
          problemMessage:
              'Avoid ref.invalidate() after an async gap in Riverpod providers.',
          correctionMessage:
              'Capture provider/usecase dependencies before the async gap, or guard the post-gap access with "if (!ref.mounted) return;".',
        ),
      ]);
    });

    test('still reports in a loop body that awaits after an outer guard', () async {
      final result = await V2RuleHarness(rule: RiverpodRefAfterAsyncGapRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/providers/todo_notifier.dart': '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> save() async {
    await persist();
    if (!ref.mounted) return;
    while (hasMore()) {
      ref.invalidate(todoProvider);
      await tick();
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
          codeName: 'riverpod_ref_after_async_gap',
          problemMessage:
              'Avoid ref.invalidate() after an async gap in Riverpod providers.',
          correctionMessage:
              'Capture provider/usecase dependencies before the async gap, or guard the post-gap access with "if (!ref.mounted) return;".',
        ),
      ]);
    });

    test('does not report when the guard sits inside the loop body', () async {
      final result = await V2RuleHarness(rule: RiverpodRefAfterAsyncGapRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/providers/todo_notifier.dart': '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> save() async {
    while (hasMore()) {
      await tick();
      if (!ref.mounted) return;
      ref.invalidate(todoProvider);
    }
  }
}
''',
            },
            definingFile:
                'lib/features/todo/presentation/providers/todo_notifier.dart',
          );

      result.expectNoDiagnostics();
    });

    test('still reports post-await ref usage without a guard', () async {
      final result = await V2RuleHarness(rule: RiverpodRefAfterAsyncGapRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/providers/todo_notifier.dart': '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> save() async {
    await persist();
    ref.invalidate(todoProvider);
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
          codeName: 'riverpod_ref_after_async_gap',
          problemMessage:
              'Avoid ref.invalidate() after an async gap in Riverpod providers.',
          correctionMessage:
              'Capture provider/usecase dependencies before the async gap, or guard the post-gap access with "if (!ref.mounted) return;".',
        ),
      ]);
    });

    test('still reports when a later await invalidates an earlier guard', () async {
      final result = await V2RuleHarness(rule: RiverpodRefAfterAsyncGapRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/providers/todo_notifier.dart': '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> save() async {
    await persist();
    if (!ref.mounted) return;
    await persistAgain();
    ref.invalidate(todoProvider);
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
          codeName: 'riverpod_ref_after_async_gap',
          problemMessage:
              'Avoid ref.invalidate() after an async gap in Riverpod providers.',
          correctionMessage:
              'Capture provider/usecase dependencies before the async gap, or guard the post-gap access with "if (!ref.mounted) return;".',
        ),
      ]);
    });

    test('reports ref after await in a non-codegen AsyncNotifier', () async {
      final result = await V2RuleHarness(rule: RiverpodRefAfterAsyncGapRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/providers/todo_notifier.dart': '''
class TodoNotifier extends AsyncNotifier<Object> {
  @override
  Future<Object> build() async => Object();

  Future<void> createTodo() async {
    await saveTodo();
    final todo = ref.read(todoProvider);
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
          codeName: 'riverpod_ref_after_async_gap',
          problemMessage:
              'Avoid ref.read() after an async gap in Riverpod providers.',
          correctionMessage:
              'Capture provider/usecase dependencies before the async gap, or guard the post-gap access with "if (!ref.mounted) return;".',
        ),
      ]);
    });

    test('does not check ref-after-async-gap in top-level @riverpod functional '
        'providers (documents a known coverage gap)', () async {
      final result = await V2RuleHarness(rule: RiverpodRefAfterAsyncGapRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/providers/todo_notifier.dart': '''
class riverpod {
  const riverpod();
}

@riverpod
Future<Object> todoDetail(Object ref) async {
  await Future<void>.delayed(Duration.zero);
  return ref.read(todoProvider);
}
''',
            },
            definingFile:
                'lib/features/todo/presentation/providers/todo_notifier.dart',
          );

      // This rule registers ClassDeclaration and ExtensionDeclaration nodes,
      // so a top-level @riverpod async function (this repo's own Tier-3
      // "computed logic provider" convention) that reads ref after an await
      // gap is still never scanned. This test documents that gap explicitly
      // so it cannot regress silently into "already covered".
      result.expectNoDiagnostics();
    });

    test('reports ref after await in an extension on a Notifier', () async {
      final result = await V2RuleHarness(rule: RiverpodRefAfterAsyncGapRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/providers/todo_notifier.dart': '''
class riverpod {
  const riverpod();
}

@riverpod
class TodoNotifier {}

extension TodoNotifierHelpers on TodoNotifier {
  Future<void> createTodo() async {
    await saveTodo();
    final todo = ref.read(todoProvider);
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
          codeName: 'riverpod_ref_after_async_gap',
          line: 11,
          problemMessage:
              'Avoid ref.read() after an async gap in Riverpod providers.',
          correctionMessage:
              'Capture provider/usecase dependencies before the async gap, or guard the post-gap access with "if (!ref.mounted) return;".',
        ),
      ]);
    });

    test('reports ref after await in an extension on a Notifier in a part file', () async {
      final result = await V2RuleHarness(rule: RiverpodRefAfterAsyncGapRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/providers/todo_notifier.dart': '''
part 'todo_notifier_helpers.dart';

class riverpod {
  const riverpod();
}

@riverpod
class TodoNotifier {}
''',
              'lib/features/todo/presentation/providers/todo_notifier_helpers.dart':
                  '''
part of 'todo_notifier.dart';

extension TodoNotifierHelpers on TodoNotifier {
  Future<void> createTodo() async {
    await saveTodo();
    final todo = ref.read(todoProvider);
  }

  Future<void> refreshTodo() async {
    await fetchTodo();
    ref.invalidate(todoProvider);
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
              'lib/features/todo/presentation/providers/todo_notifier_helpers.dart',
          codeName: 'riverpod_ref_after_async_gap',
          line: 6,
          problemMessage:
              'Avoid ref.read() after an async gap in Riverpod providers.',
          correctionMessage:
              'Capture provider/usecase dependencies before the async gap, or guard the post-gap access with "if (!ref.mounted) return;".',
        ),
        const ExpectedV2Diagnostic(
          relativePath:
              'lib/features/todo/presentation/providers/todo_notifier_helpers.dart',
          codeName: 'riverpod_ref_after_async_gap',
          line: 11,
          problemMessage:
              'Avoid ref.invalidate() after an async gap in Riverpod providers.',
          correctionMessage:
              'Capture provider/usecase dependencies before the async gap, or guard the post-gap access with "if (!ref.mounted) return;".',
        ),
      ]);
    });

    test(
      'does not report extension members when disposal-guarded after await',
      () async {
        final result = await V2RuleHarness(rule: RiverpodRefAfterAsyncGapRule())
            .analyze(
              files: {
                'lib/features/todo/presentation/providers/todo_notifier.dart':
                    '''
class riverpod {
  const riverpod();
}

@riverpod
class TodoNotifier {}

extension TodoNotifierHelpers on TodoNotifier {
  Future<void> createTodo() async {
    await saveTodo();
    if (!ref.mounted) return;
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
      'does not report ref after await in a part-file extension on CounterChangeNotifier',
      () async {
        final result = await V2RuleHarness(rule: RiverpodRefAfterAsyncGapRule())
            .analyze(
              files: {
                'lib/features/todo/presentation/providers/counter_notifier.dart':
                    '''
part 'counter_notifier_helpers.dart';

class CounterChangeNotifier {}
''',
                'lib/features/todo/presentation/providers/counter_notifier_helpers.dart':
                    '''
part of 'counter_notifier.dart';

extension CounterChangeNotifierHelpers on CounterChangeNotifier {
  Future<void> createTodo() async {
    await saveTodo();
    final todo = ref.read(todoProvider);
  }
}
''',
              },
              definingFile:
                  'lib/features/todo/presentation/providers/counter_notifier.dart',
            );

        result.expectNoDiagnostics();
      },
    );

    test(
      'does not report state assignment after await (opt-in rule)',
      () async {
        // `state = …` after a gap belongs to riverpod_state_after_async_gap.
        final result = await V2RuleHarness(rule: RiverpodRefAfterAsyncGapRule())
            .analyze(
              files: {
                'lib/features/todo/presentation/providers/todo_notifier.dart':
                    '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> load() async {
    await fetchTodo();
    state = 1;
  }

  Future<void> loadRhs() async {
    state = await fetchTodo();
  }

  Future<void> read() async {
    await fetchTodo();
    use(state.session);
  }

  Future<void> branch() async {
    if (await fetchTodo()) use(state.session);
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
