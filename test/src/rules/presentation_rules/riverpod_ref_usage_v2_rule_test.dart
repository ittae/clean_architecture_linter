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
  });
}
