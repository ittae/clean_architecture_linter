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
              'Capture provider/usecase dependencies before await, or restructure the async flow so ref is not used after await.',
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
              'Capture provider/usecase dependencies before await, or restructure the async flow so ref is not used after await.',
        ),
      ]);
    });

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
              'Capture provider/usecase dependencies before await, or restructure the async flow so ref is not used after await.',
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
              'Capture provider/usecase dependencies before await, or restructure the async flow so ref is not used after await.',
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
                'Capture provider/usecase dependencies before await, or restructure the async flow so ref is not used after await.',
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

    test('reports ref after await within the same switch case', () async {
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
              'Capture provider/usecase dependencies before await, or restructure the async flow so ref is not used after await.',
        ),
      ]);
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
              'Capture provider/usecase dependencies before await, or restructure the async flow so ref is not used after await.',
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
              'Capture provider/usecase dependencies before await, or restructure the async flow so ref is not used after await.',
        ),
      ]);
    });

    test('reports ref in finally when await is in a catch clause', () async {
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
      saveTodo();
    } catch (e) {
      await recoverTodo();
    } finally {
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
              'Capture provider/usecase dependencies before await, or restructure the async flow so ref is not used after await.',
        ),
      ]);
    });

    test('reports ref after earlier await in the same argument list', () async {
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
    combine(await loadTodo(), ref.read(todoProvider));
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
              'Capture provider/usecase dependencies before await, or restructure the async flow so ref is not used after await.',
        ),
      ]);
    });

    test('reports ref after await in the control-flow condition', () async {
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
    if (await shouldReadTodo()) {
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
              'Capture provider/usecase dependencies before await, or restructure the async flow so ref is not used after await.',
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
  });
}
