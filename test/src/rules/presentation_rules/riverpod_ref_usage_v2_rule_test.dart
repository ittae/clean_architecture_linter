import 'package:clean_architecture_linter/src/rules/presentation_rules/riverpod_ref_usage_rule.dart';
import 'package:test/test.dart';

import '../../../v2_harness/analysis_rule_harness.dart';

void main() {
  group('RiverpodRefUsageRule v2', () {
    test('reports ref.read state provider usage in build', () async {
      final result = await V2RuleHarness(rule: RiverpodRefUsageRule()).analyze(
        files: {
          'lib/features/todo/presentation/providers/todo_notifier.dart': '''
class riverpod {
  const riverpod();
}

@riverpod
class TodoNotifier {
  Object build() {
    return ref.read(currentUserProvider);
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
          codeName: 'riverpod_ref_usage',
          problemMessage:
              'Use ref.watch() instead of ref.read() for State providers in build().',
          correctionMessage:
              'Change ref.read() to ref.watch() for reactive State provider dependencies.',
        ),
      ]);
    });

    test('allows usecase provider reads and notifier reads in build', () async {
      final result = await V2RuleHarness(rule: RiverpodRefUsageRule()).analyze(
        files: {
          'lib/features/todo/presentation/providers/todo_notifier.dart': '''
class riverpod {
  const riverpod();
}

@riverpod
class TodoNotifier {
  Future<Object> build() async {
    await ref.read(getTodosUseCaseProvider)();
    return ref.read(todoProvider.notifier);
  }
}
''',
        },
        definingFile:
            'lib/features/todo/presentation/providers/todo_notifier.dart',
      );

      result.expectNoDiagnostics();
    });

    test('reports ref.watch usage outside build', () async {
      final result = await V2RuleHarness(rule: RiverpodRefUsageRule()).analyze(
        files: {
          'lib/features/todo/presentation/providers/todo_notifier.dart': '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  void createTodo() {
    final user = ref.watch(currentUserProvider);
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
          codeName: 'riverpod_ref_usage',
          problemMessage:
              'Use ref.read() instead of ref.watch() in methods for one-time reads.',
          correctionMessage:
              'Change ref.watch() to ref.read() for one-time provider access in methods.',
        ),
      ]);
    });

    test('skips generated files', () async {
      final result = await V2RuleHarness(rule: RiverpodRefUsageRule()).analyze(
        files: {
          'lib/features/todo/presentation/providers/todo_notifier.g.dart': '''
class riverpod {
  const riverpod();
}
@riverpod
class TodoNotifier {
  Object build() => ref.read(currentUserProvider);
}
''',
        },
        definingFile:
            'lib/features/todo/presentation/providers/todo_notifier.g.dart',
      );

      result.expectNoDiagnostics();
    });

    test('reports ref.read in build of a non-codegen AsyncNotifier', () async {
      final result = await V2RuleHarness(rule: RiverpodRefUsageRule()).analyze(
        files: {
          'lib/features/todo/presentation/providers/todo_notifier.dart': '''
class TodoNotifier extends AsyncNotifier<Object> {
  @override
  Object build() {
    return ref.read(currentUserProvider);
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
          codeName: 'riverpod_ref_usage',
          problemMessage:
              'Use ref.watch() instead of ref.read() for State providers in build().',
          correctionMessage:
              'Change ref.read() to ref.watch() for reactive State provider dependencies.',
        ),
      ]);
    });

    test('reports ref.watch outside build of a non-codegen Notifier', () async {
      final result = await V2RuleHarness(rule: RiverpodRefUsageRule()).analyze(
        files: {
          'lib/features/todo/presentation/providers/todo_notifier.dart': '''
class TodoNotifier extends Notifier<Object> {
  @override
  Object build() => Object();

  void createTodo() {
    final user = ref.watch(currentUserProvider);
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
          codeName: 'riverpod_ref_usage',
          problemMessage:
              'Use ref.read() instead of ref.watch() in methods for one-time reads.',
          correctionMessage:
              'Change ref.watch() to ref.read() for one-time provider access in methods.',
        ),
      ]);
    });

    test(
      'flags ref.watch in a private helper synchronously delegated from build() '
      '(documents a known over-flagging gap, not endorsed behavior)',
      () async {
        final result = await V2RuleHarness(rule: RiverpodRefUsageRule())
            .analyze(
              files: {
                'lib/features/todo/presentation/providers/todo_notifier.dart':
                    '''
class riverpod {
  const riverpod();
}

@riverpod
class TodoNotifier {
  Object build() {
    return _computeInitial();
  }

  Object _computeInitial() {
    return ref.watch(currentUserProvider);
  }
}
''',
              },
              definingFile:
                  'lib/features/todo/presentation/providers/todo_notifier.dart',
            );

        // A private helper invoked synchronously from build() is idiomatic
        // Riverpod (ref.watch just needs to run during the sync build call
        // graph), but this rule only recognises a method literally named
        // `build`, so today it reports the helper as a "read outside build"
        // violation. This test pins today's behavior as a regression guard;
        // it is not an endorsement of the false positive.
        result.expectDiagnostics([
          const ExpectedV2Diagnostic(
            relativePath:
                'lib/features/todo/presentation/providers/todo_notifier.dart',
            codeName: 'riverpod_ref_usage',
            problemMessage:
                'Use ref.read() instead of ref.watch() in methods for one-time reads.',
            correctionMessage:
                'Change ref.watch() to ref.read() for one-time provider access in methods.',
          ),
        ]);
      },
    );

    test('does not check ref usage in top-level @riverpod functional providers '
        '(documents a known coverage gap)', () async {
      final result = await V2RuleHarness(rule: RiverpodRefUsageRule()).analyze(
        files: {
          'lib/features/todo/presentation/providers/todo_notifier.dart': '''
class riverpod {
  const riverpod();
}

@riverpod
bool canSubmitTodo(Object ref) {
  return ref.read(currentUserProvider) != null;
}
''',
        },
        definingFile:
            'lib/features/todo/presentation/providers/todo_notifier.dart',
      );

      // This rule only registers ClassDeclaration nodes, so top-level
      // @riverpod functions -- this repo's own Tier-3 "computed logic
      // provider" convention (see CLAUDE.md) -- get no ref.watch/ref.read
      // discipline check at all. This test documents that gap explicitly
      // so it cannot regress silently into "already covered".
      result.expectNoDiagnostics();
    });
  });
}
