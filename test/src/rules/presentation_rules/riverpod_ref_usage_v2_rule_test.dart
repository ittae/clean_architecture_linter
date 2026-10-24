import 'package:clean_architecture_linter/src/rules/presentation_rules/riverpod_ref_usage_rule.dart';
import 'package:test/test.dart';

import '../../../v2_harness/analysis_rule_harness.dart';

const _path = 'lib/features/todo/presentation/providers/todo_notifier.dart';

ExpectedV2Diagnostic _watchInMethodDiagnostic() => const ExpectedV2Diagnostic(
  relativePath: _path,
  codeName: 'riverpod_ref_usage',
  problemMessage:
      'Use ref.read() instead of ref.watch() in methods for one-time reads.',
  correctionMessage:
      'Change ref.watch() to ref.read() for one-time provider access in methods.',
);

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

    test(
      'allows stable DI dependency reads (repository/datasource/service/client/api/dao/logger/analytics/storage) in build',
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
    final repo = ref.read(todoRepositoryProvider);
    final dataSource = ref.read(todoDataSourceProvider);
    final service = ref.read(todoServiceProvider);
    final client = ref.read(todoClientProvider);
    final api = ref.read(todoApiProvider);
    final dao = ref.read(todoDaoProvider);
    final logger = ref.read(appLoggerProvider);
    final analytics = ref.read(analyticsProvider);
    final storage = ref.read(appStorageProvider);
    analytics.trackOpen();
    logger.log('open');
    service.ping();
    client.connect();
    dao.touch();
    dataSource.warmup();
    storage.readAll();
    return repo;
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
      'allows ref.watch in a private sync helper called from build()',
      () async {
        final result = await V2RuleHarness(rule: RiverpodRefUsageRule())
            .analyze(
              files: {
                _path: '''
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
              definingFile: _path,
            );

        result.expectNoDiagnostics();
      },
    );

    test(
      'allows ref.watch in a helper reached transitively from build()',
      () async {
        final result = await V2RuleHarness(rule: RiverpodRefUsageRule())
            .analyze(
              files: {
                _path: '''
class riverpod {
  const riverpod();
}

@riverpod
class TodoNotifier {
  Object build() {
    return this._first();
  }

  Object _first() => _second();

  Object _second() => ref.watch(currentUserProvider);
}
''',
              },
              definingFile: _path,
            );

        result.expectNoDiagnostics();
      },
    );

    test(
      'still flags ref.watch in a helper that build() does not call',
      () async {
        final result = await V2RuleHarness(rule: RiverpodRefUsageRule())
            .analyze(
              files: {
                _path: '''
class riverpod {
  const riverpod();
}

@riverpod
class TodoNotifier {
  Object build() {
    return const Object();
  }

  Object _onlyFromEvents() {
    return ref.watch(currentUserProvider);
  }
}
''',
              },
              definingFile: _path,
            );

        result.expectDiagnostics([_watchInMethodDiagnostic()]);
      },
    );

    test(
      'still flags ref.watch in an async helper called from build()',
      () async {
        final result = await V2RuleHarness(rule: RiverpodRefUsageRule())
            .analyze(
              files: {
                _path: '''
class riverpod {
  const riverpod();
}

@riverpod
class TodoNotifier {
  Future<Object> build() async {
    return _loadInitial();
  }

  Future<Object> _loadInitial() async {
    await Future<void>.delayed(Duration.zero);
    return ref.watch(currentUserProvider);
  }
}
''',
              },
              definingFile: _path,
            );

        result.expectDiagnostics([_watchInMethodDiagnostic()]);
      },
    );

    test(
      'still flags ref.watch in a public method called from build()',
      () async {
        final result = await V2RuleHarness(rule: RiverpodRefUsageRule())
            .analyze(
              files: {
                _path: '''
class riverpod {
  const riverpod();
}

@riverpod
class TodoNotifier {
  Object build() {
    return refresh();
  }

  Object refresh() {
    return ref.watch(currentUserProvider);
  }
}
''',
              },
              definingFile: _path,
            );

        result.expectDiagnostics([_watchInMethodDiagnostic()]);
      },
    );

    test(
      'still flags ref.watch in a helper only called from a ref.listen callback',
      () async {
        final result = await V2RuleHarness(rule: RiverpodRefUsageRule())
            .analyze(
              files: {
                _path: '''
class riverpod {
  const riverpod();
}

@riverpod
class TodoNotifier {
  Object build() {
    ref.listen(currentUserProvider, (_, __) => _onChange());
    return const Object();
  }

  void _onChange() {
    ref.watch(todoProvider);
  }
}
''',
              },
              definingFile: _path,
            );

        result.expectDiagnostics([_watchInMethodDiagnostic()]);
      },
    );

    test(
      'still flags ref.watch in a helper only called from a Timer callback',
      () async {
        final result = await V2RuleHarness(rule: RiverpodRefUsageRule())
            .analyze(
              files: {
                _path: '''
class riverpod {
  const riverpod();
}

@riverpod
class TodoNotifier {
  Object build() {
    Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    return const Object();
  }

  void _tick() {
    ref.watch(todoProvider);
  }
}
''',
              },
              definingFile: _path,
            );

        result.expectDiagnostics([_watchInMethodDiagnostic()]);
      },
    );

    test(
      'still flags ref.watch in a helper that a public method also calls',
      () async {
        final result = await V2RuleHarness(rule: RiverpodRefUsageRule())
            .analyze(
              files: {
                _path: '''
class riverpod {
  const riverpod();
}

@riverpod
class TodoNotifier {
  Object build() {
    return _compute();
  }

  void increment() {
    _compute();
  }

  Object _compute() {
    return ref.watch(currentUserProvider);
  }
}
''',
              },
              definingFile: _path,
            );

        result.expectDiagnostics([_watchInMethodDiagnostic()]);
      },
    );

    test(
      'still flags a shared helper reached via another helper that a public method calls',
      () async {
        final result = await V2RuleHarness(rule: RiverpodRefUsageRule())
            .analyze(
              files: {
                _path: '''
class riverpod {
  const riverpod();
}

@riverpod
class TodoNotifier {
  Object build() {
    return _compute();
  }

  void increment() {
    _viaHelper();
  }

  void _viaHelper() {
    _compute();
  }

  Object _compute() {
    return ref.watch(currentUserProvider);
  }
}
''',
              },
              definingFile: _path,
            );

        result.expectDiagnostics([_watchInMethodDiagnostic()]);
      },
    );

    test(
      'allows ref.watch in a helper called from a synchronous collection callback in build()',
      () async {
        final result = await V2RuleHarness(rule: RiverpodRefUsageRule())
            .analyze(
              files: {
                _path: '''
class riverpod {
  const riverpod();
}

@riverpod
class TodoNotifier {
  Object build() {
    return [1, 2].map((id) => _load(id)).toList();
  }

  Object _load(int id) {
    return ref.watch(todoProvider(id));
  }
}
''',
              },
              definingFile: _path,
            );

        result.expectNoDiagnostics();
      },
    );

    test('reports ref.read of a state provider in a @riverpod functional '
        'provider', () async {
      final result = await V2RuleHarness(rule: RiverpodRefUsageRule()).analyze(
        files: {
          _path: '''
class riverpod {
  const riverpod();
}

@riverpod
bool canSubmitTodo(Object ref) {
  return ref.read(currentUserProvider) != null;
}
''',
        },
        definingFile: _path,
      );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath: _path,
          codeName: 'riverpod_ref_usage',
          line: 7,
          problemMessage:
              'Use ref.watch() instead of ref.read() for State providers in build().',
          correctionMessage:
              'Change ref.read() to ref.watch() for reactive State provider dependencies.',
        ),
      ]);
    });

    test('allows ref.watch, usecase reads and notifier reads in a @riverpod '
        'functional provider', () async {
      final result = await V2RuleHarness(rule: RiverpodRefUsageRule()).analyze(
        files: {
          _path: '''
class riverpod {
  const riverpod();
}

@riverpod
bool canSubmitTodo(Object ref) {
  ref.read(todoProvider.notifier);
  ref.read(todoRepositoryProvider);
  return ref.watch(currentUserProvider) != null;
}
''',
        },
        definingFile: _path,
      );

      result.expectNoDiagnostics();
    });

    test('ignores top-level functions without @riverpod', () async {
      final result = await V2RuleHarness(rule: RiverpodRefUsageRule()).analyze(
        files: {
          _path: '''
bool canSubmitTodo(Object ref) {
  return ref.read(currentUserProvider) != null;
}
''',
        },
        definingFile: _path,
      );

      result.expectNoDiagnostics();
    });

    test('reports ref.watch in an extension method on a Notifier', () async {
      final result = await V2RuleHarness(rule: RiverpodRefUsageRule()).analyze(
        files: {
          'lib/features/todo/presentation/providers/todo_notifier.dart': '''
class riverpod {
  const riverpod();
}

@riverpod
class TodoNotifier {}

extension TodoNotifierHelpers on TodoNotifier {
  void save() {
    final todo = ref.watch(todoProvider);
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
          line: 10,
          problemMessage:
              'Use ref.read() instead of ref.watch() in methods for one-time reads.',
          correctionMessage:
              'Change ref.watch() to ref.read() for one-time provider access in methods.',
        ),
      ]);
    });

    test('reports ref.watch in a Notifier extension method in a part file', () async {
      final result = await V2RuleHarness(rule: RiverpodRefUsageRule()).analyze(
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
  void save() {
    final todo = ref.watch(todoProvider);
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
          codeName: 'riverpod_ref_usage',
          line: 5,
          problemMessage:
              'Use ref.read() instead of ref.watch() in methods for one-time reads.',
          correctionMessage:
              'Change ref.watch() to ref.read() for one-time provider access in methods.',
        ),
      ]);
    });

    test(
      'does not treat HookConsumerWidget or StatefulHookConsumerWidget as a Notifier',
      () async {
        final result = await V2RuleHarness(rule: RiverpodRefUsageRule()).analyze(
          files: {
            'lib/features/todo/presentation/providers/todo_counter_provider.dart':
                '''
class HookConsumerWidget {}
class StatefulHookConsumerWidget {}

class TodoHookNotifier extends HookConsumerWidget {
  int build() {
    return ref.read(counterProvider);
  }
}

class TodoStatefulHookNotifier extends StatefulHookConsumerWidget {
  int build() {
    return ref.read(counterProvider);
  }
}
''',
          },
          definingFile:
              'lib/features/todo/presentation/providers/todo_counter_provider.dart',
        );

        result.expectNoDiagnostics();
      },
    );
  });
}
