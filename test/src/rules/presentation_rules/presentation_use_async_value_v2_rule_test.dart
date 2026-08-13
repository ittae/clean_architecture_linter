import 'package:clean_architecture_linter/src/rules/presentation_rules/presentation_use_async_value_rule.dart';
import 'package:test/test.dart';

import '../../../v2_harness/analysis_rule_harness.dart';

void main() {
  group('PresentationUseAsyncValueRule v2', () {
    test('reports error and loading fields in Freezed state', () async {
      final result = await V2RuleHarness(rule: PresentationUseAsyncValueRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/states/todo_state.dart': '''
class freezed {
  const freezed();
}

@freezed
class TodoState {
  final String? errorMessage;
  final bool isLoading;
}
''',
            },
            definingFile:
                'lib/features/todo/presentation/states/todo_state.dart',
          );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath: 'lib/features/todo/presentation/states/todo_state.dart',
          codeName: 'presentation_use_async_value',
          problemMessage:
              'State should NOT have error field "errorMessage". Use AsyncValue instead.',
          correctionMessage:
              'Remove error field. Use AsyncNotifier with AsyncValue.when() pattern. AsyncValue automatically manages error states.',
        ),
        const ExpectedV2Diagnostic(
          relativePath: 'lib/features/todo/presentation/states/todo_state.dart',
          codeName: 'presentation_use_async_value',
          problemMessage:
              'State should NOT have loading field "isLoading". Use AsyncValue instead.',
          correctionMessage:
              'Remove loading field. Use AsyncNotifier with AsyncValue.when() pattern. AsyncValue automatically manages loading states.',
        ),
      ]);
    });

    test('reports constructor error and loading parameters', () async {
      final result = await V2RuleHarness(rule: PresentationUseAsyncValueRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/states/todo_state.dart': '''
class freezed {
  const freezed();
}

@freezed
class TodoState {
  TodoState({String? failureMessage, bool loading = false});
}
''',
            },
            definingFile:
                'lib/features/todo/presentation/states/todo_state.dart',
          );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath: 'lib/features/todo/presentation/states/todo_state.dart',
          codeName: 'presentation_use_async_value',
          problemMessage:
              'State should NOT have error parameter "failureMessage". Use AsyncValue instead.',
          correctionMessage:
              'Remove error parameter. Use AsyncNotifier with AsyncValue.when() pattern. AsyncValue automatically manages error states.',
        ),
        const ExpectedV2Diagnostic(
          relativePath: 'lib/features/todo/presentation/states/todo_state.dart',
          codeName: 'presentation_use_async_value',
          problemMessage:
              'State should NOT have loading parameter "loading". Use AsyncValue instead.',
          correctionMessage:
              'Remove loading parameter. Use AsyncNotifier with AsyncValue.when() pattern. AsyncValue automatically manages loading states.',
        ),
      ]);
    });

    test('reports notifier catch blocks that swallow exceptions', () async {
      final result = await V2RuleHarness(rule: PresentationUseAsyncValueRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/providers/todo_notifier.dart': '''
class TodoNotifier {
  Future<void> load() async {
    try {
      await fetch();
    } catch (error) {
      print(error);
    }
  }

  Future<void> fetch() async {}
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
          codeName: 'presentation_use_async_value',
          problemMessage:
              'Notifier/Provider catch did not map exception to UI state.',
          correctionMessage:
              'Use AsyncValue.guard(), state = AsyncValue.error(...), '
              'state = AsyncData(...uiEffect...), or UI handling via when(error: ...).',
        ),
      ]);
    });

    test('allows catch blocks that map to AsyncValue', () async {
      final result = await V2RuleHarness(rule: PresentationUseAsyncValueRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/providers/todo_notifier.dart': '''
class TodoNotifier {
  Object? state;

  Future<void> load() async {
    try {
      await fetch();
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> fetch() async {}
}
''',
            },
            definingFile:
                'lib/features/todo/presentation/providers/todo_notifier.dart',
          );

      result.expectNoDiagnostics();
    });

    test(
      'allows catch blocks that map partial failure via AsyncData + uiEffect',
      () async {
        final result =
            await V2RuleHarness(rule: PresentationUseAsyncValueRule()).analyze(
              files: {
                'lib/features/todo/presentation/providers/todo_notifier.dart':
                    '''
class TodoNotifier {
  Object? state;

  Future<void> deleteItem(String id) async {
    final latest = state as dynamic;
    try {
      await delete(id);
    } catch (error) {
      // Keep list data; surface failure as a toast effect (not AsyncError).
      state = AsyncData(
        latest.copyWith(uiEffect: _toast(error)),
      );
    }
  }

  Object _toast(Object error) => error;
  Future<void> delete(String id) async {}
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
      'allows catch blocks that set uiEffect without referencing catch param',
      () async {
        final result =
            await V2RuleHarness(rule: PresentationUseAsyncValueRule()).analyze(
              files: {
                'lib/features/todo/presentation/providers/todo_notifier.dart':
                    '''
class TodoNotifier {
  Object? state;

  Future<void> deleteItem(String id) async {
    final latest = state as dynamic;
    try {
      await delete(id);
    } catch (error) {
      Log.error('delete failed: \$error');
      state = AsyncData(
        latest.copyWith(uiEffect: _toast('failed')),
      );
    }
  }

  Object _toast(String message) => message;
  Future<void> delete(String id) async {}
}

class Log {
  static void error(String message) {}
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
      'allows catch blocks that map via AsyncValue.guard with uiEffect',
      () async {
        final result =
            await V2RuleHarness(rule: PresentationUseAsyncValueRule()).analyze(
              files: {
                'lib/features/todo/presentation/providers/todo_notifier.dart':
                    '''
class TodoNotifier {
  Object? state;

  Future<void> deleteItem(String id) async {
    final latest = state as dynamic;
    try {
      await delete(id);
    } catch (error) {
      state = await AsyncValue.guard(
        () async => latest.copyWith(uiEffect: _toast('failed')),
      );
    }
  }

  Object _toast(String message) => message;
  Future<void> delete(String id) async {}
}
''',
              },
              definingFile:
                  'lib/features/todo/presentation/providers/todo_notifier.dart',
            );

        result.expectNoDiagnostics();
      },
    );

    test('reports catch blocks that only log without updating state', () async {
      final result = await V2RuleHarness(rule: PresentationUseAsyncValueRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/providers/todo_notifier.dart': '''
class TodoNotifier {
  Future<void> load() async {
    try {
      await fetch();
    } catch (error) {
      Log.error('load failed: \$error');
    }
  }

  Future<void> fetch() async {}
}

class Log {
  static void error(String message) {}
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
          codeName: 'presentation_use_async_value',
          problemMessage:
              'Notifier/Provider catch did not map exception to UI state.',
          correctionMessage:
              'Use AsyncValue.guard(), state = AsyncValue.error(...), '
              'state = AsyncData(...uiEffect...), or UI handling via when(error: ...).',
        ),
      ]);
    });

    test('reports catch blocks that only set AsyncValue loading', () async {
      final result = await V2RuleHarness(rule: PresentationUseAsyncValueRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/providers/todo_notifier.dart': '''
class TodoNotifier {
  Object? state;

  Future<void> load() async {
    try {
      await fetch();
    } catch (error) {
      state = const AsyncValue.loading();
    }
  }

  Future<void> fetch() async {}
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
          codeName: 'presentation_use_async_value',
          problemMessage:
              'Notifier/Provider catch did not map exception to UI state.',
          correctionMessage:
              'Use AsyncValue.guard(), state = AsyncValue.error(...), '
              'state = AsyncData(...uiEffect...), or UI handling via when(error: ...).',
        ),
      ]);
    });

    test('skips generated files', () async {
      final result = await V2RuleHarness(rule: PresentationUseAsyncValueRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/states/todo_state.freezed.dart':
                  '''
class freezed {
  const freezed();
}

@freezed
class TodoState {
  final String? errorMessage;
}
''',
            },
            definingFile:
                'lib/features/todo/presentation/states/todo_state.freezed.dart',
          );

      result.expectNoDiagnostics();
    });

    test(
      'reports catch blocks that swallow exceptions in an extension on a Notifier',
      () async {
        final result =
            await V2RuleHarness(rule: PresentationUseAsyncValueRule()).analyze(
              files: {
                'lib/features/todo/presentation/providers/todo_notifier.dart':
                    '''
class TodoNotifier {}

extension TodoNotifierHelpers on TodoNotifier {
  Future<void> load() async {
    try {
      await fetch();
    } catch (error) {
      print(error);
    }
  }

  Future<void> fetch() async {}
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
            codeName: 'presentation_use_async_value',
            line: 7,
            problemMessage:
                'Notifier/Provider catch did not map exception to UI state.',
            correctionMessage:
                'Use AsyncValue.guard(), state = AsyncValue.error(...), '
                'state = AsyncData(...uiEffect...), or UI handling via when(error: ...).',
          ),
        ]);
      },
    );

    test(
      'reports catch blocks that swallow exceptions in a Notifier extension part',
      () async {
        final result =
            await V2RuleHarness(rule: PresentationUseAsyncValueRule()).analyze(
              files: {
                'lib/features/todo/presentation/providers/todo_notifier.dart':
                    '''
part 'todo_notifier_helpers.dart';

class TodoNotifier {}
''',
                'lib/features/todo/presentation/providers/todo_notifier_helpers.dart':
                    '''
part of 'todo_notifier.dart';

extension TodoNotifierHelpers on TodoNotifier {
  Future<void> load() async {
    try {
      await fetch();
    } catch (error) {
      print(error);
    }
  }

  Future<void> fetch() async {}
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
            codeName: 'presentation_use_async_value',
            line: 7,
            problemMessage:
                'Notifier/Provider catch did not map exception to UI state.',
            correctionMessage:
                'Use AsyncValue.guard(), state = AsyncValue.error(...), '
                'state = AsyncData(...uiEffect...), or UI handling via when(error: ...).',
          ),
        ]);
      },
    );

    test(
      'does not report catch blocks in an extension on ChangeNotifier',
      () async {
        final result =
            await V2RuleHarness(rule: PresentationUseAsyncValueRule()).analyze(
              files: {
                'lib/features/todo/presentation/providers/todo_notifier.dart':
                    '''
extension ChangeNotifierHelpers on ChangeNotifier {
  Future<void> load() async {
    try {
      await fetch();
    } catch (error) {
      print(error);
    }
  }

  Future<void> fetch() async {}
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
      'does not report catch blocks in an extension on CounterChangeNotifier',
      () async {
        final result =
            await V2RuleHarness(rule: PresentationUseAsyncValueRule()).analyze(
              files: {
                'lib/features/todo/presentation/providers/todo_notifier.dart':
                    '''
extension CounterChangeNotifierHelpers on CounterChangeNotifier {
  Future<void> load() async {
    try {
      await fetch();
    } catch (error) {
      print(error);
    }
  }

  Future<void> fetch() async {}
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
