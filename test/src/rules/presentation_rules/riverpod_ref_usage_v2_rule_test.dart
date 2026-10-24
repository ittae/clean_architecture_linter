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

String _source(String declarations) =>
    'class riverpod {\n  const riverpod();\n}\n\n$declarations\n';

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

    group('private helpers of build()', () {
      // (name, class members, whether ref.watch in a helper is reported)
      const cases = <(String, String, bool)>[
        (
          'allows ref.watch in a private sync helper called from build()',
          'Object build() => _compute();\n'
              'Object _compute() => ref.watch(currentUserProvider);',
          false,
        ),
        (
          'allows ref.watch in a helper reached transitively from build()',
          'Object build() => this._first();\n'
              'Object _first() => _second();\n'
              'Object _second() => ref.watch(currentUserProvider);',
          false,
        ),
        (
          'flags ref.watch in a helper that build() does not call',
          'Object build() => const Object();\n'
              'Object _other() => ref.watch(currentUserProvider);',
          true,
        ),
        (
          'flags ref.watch in an async helper called from a sync build()',
          'Object build() {\n'
              '  _load();\n'
              '  return const Object();\n'
              '}\n'
              'Future<Object> _load() async {\n'
              '  await Future<void>.delayed(Duration.zero);\n'
              '  return ref.watch(currentUserProvider);\n'
              '}',
          true,
        ),
        (
          'flags ref.watch in a public method called from build()',
          'Object build() => refresh();\n'
              'Object refresh() => ref.watch(currentUserProvider);',
          true,
        ),
        (
          'flags ref.watch in a helper only called from a ref.listen callback',
          'Object build() {\n'
              '  ref.listen(currentUserProvider, (_, __) => _onChange());\n'
              '  return const Object();\n'
              '}\n'
              'void _onChange() => ref.watch(todoProvider);',
          true,
        ),
        (
          'flags ref.watch in a helper only called from a Timer callback',
          'Object build() {\n'
              '  Timer.periodic(const Duration(seconds: 1), (_) => _tick());\n'
              '  return const Object();\n'
              '}\n'
              'void _tick() => ref.watch(todoProvider);',
          true,
        ),
        (
          'flags ref.watch in a helper called from a Stream.map callback',
          'Stream<int> build() => _source.map((e) => _convert(e));\n'
              'int _convert(int e) => ref.watch(xProvider) + e;',
          true,
        ),
        (
          'flags ref.watch in a helper passed as a ref.listen tear-off',
          'Object build() {\n'
              '  ref.listen(otherProvider, _onChange);\n'
              '  return _onChange(null, null);\n'
              '}\n'
              'Object _onChange(Object? a, Object? b) => ref.watch(userProvider);',
          true,
        ),
        (
          'flags ref.watch in a generator helper called from build()',
          'Object build() => _items().toList();\n'
              'Iterable<Object> _items() sync* {\n'
              '  yield ref.watch(userProvider);\n'
              '}',
          true,
        ),
        (
          'flags ref.watch in a helper of an async build() (conservative)',
          'Future<Object> build() async {\n'
              '  final v = _compute();\n'
              '  await Future<void>.delayed(Duration.zero);\n'
              '  return v;\n'
              '}\n'
              'Object _compute() => ref.watch(userProvider);',
          true,
        ),
        (
          'flags ref.watch in a helper called after an await in build()',
          'Future<Object> build() async {\n'
              '  await Future<void>.delayed(Duration.zero);\n'
              '  return _compute();\n'
              '}\n'
              'Object _compute() => ref.watch(userProvider);',
          true,
        ),
        (
          'flags only the closure ref.watch inside a build-only helper',
          'Object build() => _compute();\n'
              'Object _compute() {\n'
              '  Timer.run(() => ref.watch(todoProvider));\n'
              '  return ref.watch(userProvider);\n'
              '}',
          true,
        ),
        (
          'flags ref.watch in a helper that build() also calls from a closure',
          'Object build() {\n'
              '  ref.listen(otherProvider, (_, __) => _compute());\n'
              '  return _compute();\n'
              '}\n'
              'Object _compute() => ref.watch(userProvider);',
          true,
        ),
        (
          'flags ref.watch in a helper that a field initializer also calls',
          'late final _cached = _compute();\n'
              'Object build() => _compute();\n'
              'Object _compute() => ref.watch(userProvider);',
          true,
        ),
        (
          'allows ref.watch in a build-only helper whose name a cascade repeats',
          'Object build() => _compute();\n'
              'void other(List<int> xs) => xs.._compute();\n'
              'Object _compute() => ref.watch(userProvider);',
          false,
        ),
        (
          'flags ref.watch in a helper that a public method also calls',
          'Object build() => _compute();\n'
              'void increment() => _compute();\n'
              'Object _compute() => ref.watch(currentUserProvider);',
          true,
        ),
        (
          'flags a shared helper reached via a helper that a public method calls',
          'Object build() => _compute();\n'
              'void increment() => _viaHelper();\n'
              'void _viaHelper() => _compute();\n'
              'Object _compute() => ref.watch(currentUserProvider);',
          true,
        ),
      ];

      for (final (name, members, flagged) in cases) {
        test(name, () async {
          final result = await V2RuleHarness(rule: RiverpodRefUsageRule())
              .analyze(
                files: {
                  _path: _source(
                    '@riverpod\nclass TodoNotifier {\n$members\n}',
                  ),
                },
                definingFile: _path,
              );

          flagged
              ? result.expectDiagnostics([_watchInMethodDiagnostic()])
              : result.expectNoDiagnostics();
        });
      }
    });

    test(
      'flags ref.watch in a helper that a same-file extension also calls',
      () async {
        final result = await V2RuleHarness(rule: RiverpodRefUsageRule())
            .analyze(
              files: {
                _path: _source(
                  '@riverpod\nclass TodoNotifier {\n'
                  'Object build() => _compute();\n'
                  'Object _compute() => ref.watch(userProvider);\n'
                  '}\n'
                  'extension TodoActions on TodoNotifier {\n'
                  '  void refresh() => _compute();\n'
                  '}',
                ),
              },
              definingFile: _path,
            );

        result.expectDiagnostics([_watchInMethodDiagnostic()]);
      },
    );

    group('top-level @riverpod functional providers', () {
      // (name, declaration, whether ref.read of a state provider is reported)
      const cases = <(String, String, bool)>[
        (
          'reports ref.read of a state provider',
          '@riverpod\nbool canSubmit(Object ref) => ref.read(userProvider) != null;',
          true,
        ),
        (
          'allows ref.watch, usecase/repository reads and notifier reads',
          '@riverpod\nbool canSubmit(Object ref) {\n'
              '  ref.read(todoProvider.notifier);\n'
              '  ref.read(todoRepositoryProvider);\n'
              '  ref.read(getTodosUseCaseProvider);\n'
              '  return ref.watch(userProvider) != null;\n'
              '}',
          false,
        ),
        (
          'allows a state provider ref.read inside a returned callback',
          '@riverpod\nObject Function() reader(Object ref) =>\n'
              '    () => ref.read(userProvider);',
          false,
        ),
        (
          'allows a state provider ref.read inside a ref.listen callback',
          '@riverpod\nFuture<int> counter(Object ref) async {\n'
              '  ref.listen(otherProvider, (_, __) => ref.read(userProvider));\n'
              '  return 0;\n'
              '}',
          false,
        ),
        (
          'ignores functions without @riverpod',
          'bool canSubmit(Object ref) => ref.read(userProvider) != null;',
          false,
        ),
      ];

      for (final (name, declaration, flagged) in cases) {
        test(name, () async {
          final result = await V2RuleHarness(
            rule: RiverpodRefUsageRule(),
          ).analyze(files: {_path: _source(declaration)}, definingFile: _path);

          flagged
              ? result.expectDiagnostics([
                  const ExpectedV2Diagnostic(
                    relativePath: _path,
                    codeName: 'riverpod_ref_usage',
                    problemMessage:
                        'Use ref.watch() instead of ref.read() for State providers in build().',
                    correctionMessage:
                        'Change ref.read() to ref.watch() for reactive State provider dependencies.',
                  ),
                ])
              : result.expectNoDiagnostics();
        });
      }
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
