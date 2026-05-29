import 'package:clean_architecture_linter/src/rules/presentation_rules/presentation_no_throw_rule.dart';
import 'package:test/test.dart';

import '../../../v2_harness/analysis_rule_harness.dart';

void main() {
  group('PresentationNoThrowRule', () {
    test(
      'reports throw expressions in presentation state/provider files',
      () async {
        final result = await V2RuleHarness(rule: PresentationNoThrowRule())
            .analyze(
              files: {
                'lib/features/todo/presentation/providers/bad_notifier.dart':
                    '''
class TodoException implements Exception {}

class BadNotifier {
  Future<void> build() async {
    throw TodoException();
  }
}
''',
              },
              definingFile:
                  'lib/features/todo/presentation/providers/bad_notifier.dart',
            );

        result.expectDiagnostics([
          const ExpectedV2Diagnostic(
            relativePath:
                'lib/features/todo/presentation/providers/bad_notifier.dart',
            codeName: 'presentation_no_throw',
            line: 5,
          ),
        ]);
      },
    );

    test('ignores throw expressions owned by AsyncValue.guard', () async {
      final result = await V2RuleHarness(rule: PresentationNoThrowRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/providers/good_notifier.dart': '''
class AsyncValue<T> {
  const AsyncValue.data(this.value);

  final T value;

  static Future<AsyncValue<T>> guard<T>(Future<T> Function() body) async {
    return AsyncValue.data(await body());
  }
}

class GoodNotifier {
  Future<AsyncValue<String>> build() {
    return AsyncValue.guard(() async {
      throw StateError('AsyncValue.guard owns the error channel.');
    });
  }
}
''',
            },
            definingFile:
                'lib/features/todo/presentation/providers/good_notifier.dart',
          );

      result.expectNoDiagnostics();
    });

    test(
      'ignores throw expressions owned by prefixed AsyncValue.guard',
      () async {
        final result = await V2RuleHarness(rule: PresentationNoThrowRule())
            .analyze(
              files: {
                'lib/riverpod.dart': '''
class AsyncValue<T> {
  const AsyncValue.data(this.value);

  final T value;

  static Future<AsyncValue<T>> guard<T>(Future<T> Function() body) async {
    return AsyncValue.data(await body());
  }
}
''',
                'lib/features/todo/presentation/providers/good_notifier.dart':
                    '''
import 'package:cal_v2_harness_app/riverpod.dart' as rp;

class GoodNotifier {
  Future<rp.AsyncValue<String>> build() {
    return rp.AsyncValue.guard(() async {
      throw StateError('Prefixed AsyncValue.guard owns the error channel.');
    });
  }
}
''',
              },
              definingFile:
                  'lib/features/todo/presentation/providers/good_notifier.dart',
            );

        result.expectNoDiagnostics();
      },
    );

    test('reports business exception branching in widgets', () async {
      final result = await V2RuleHarness(rule: PresentationNoThrowRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/todo_page.dart': '''
class TodoFailure implements Exception {}

class TodoPage {
  void build() {
    try {
      risky();
    } on TodoFailure catch (_) {
      showError();
    }
  }

  void risky() {}
  void showError() {}
}
''',
            },
            definingFile: 'lib/features/todo/presentation/todo_page.dart',
          );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath: 'lib/features/todo/presentation/todo_page.dart',
          codeName: 'presentation_no_throw',
          line: 7,
        ),
      ]);
    });

    test(
      'ignores programming errors, private helpers, and constructors',
      () async {
        final result = await V2RuleHarness(rule: PresentationNoThrowRule())
            .analyze(
              files: {
                'lib/features/todo/presentation/providers/todo_notifier.dart':
                    '''
class TodoException implements Exception {}

class TodoNotifier {
  TodoNotifier() {
    throw TodoException();
  }

  void _helper() {
    throw TodoException();
  }

  void validate() {
    throw StateError('Programming errors are allowed.');
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

    test('ignores throws outside state/provider presentation paths', () async {
      final result = await V2RuleHarness(rule: PresentationNoThrowRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/pages/todo_page.dart': '''
class TodoException implements Exception {}

class TodoPage {
  void build() {
    throw TodoException();
  }
}
''',
            },
            definingFile: 'lib/features/todo/presentation/pages/todo_page.dart',
          );

      result.expectNoDiagnostics();
    });

    test('ignores throws outside state or notifier classes', () async {
      final result = await V2RuleHarness(rule: PresentationNoThrowRule())
          .analyze(
            files: {
              'lib/features/todo/presentation/providers/todo_helper.dart': '''
class TodoException implements Exception {}

class TodoHelper {
  void build() {
    throw TodoException();
  }
}
''',
            },
            definingFile:
                'lib/features/todo/presentation/providers/todo_helper.dart',
          );

      result.expectNoDiagnostics();
    });

    test('requires presentation segment under lib', () async {
      final result = await V2RuleHarness(rule: PresentationNoThrowRule())
          .analyze(
            files: {
              'lib/features/todo/domain/notifier.dart': '''
class DomainNotifier {
  void build() {
    throw StateError('The workspace path may contain presentation elsewhere.');
  }
}
''',
            },
            definingFile: 'lib/features/todo/domain/notifier.dart',
          );

      result.expectNoDiagnostics();
      expect(
        isPresentationLibPath('/Users/me/presentation/app/lib/domain/foo.dart'),
        isFalse,
      );
    });

    test('uses current part file path instead of defining unit path', () async {
      final result = await V2RuleHarness(rule: PresentationNoThrowRule())
          .analyze(
            files: {
              'lib/features/todo/todo.dart': '''
part 'presentation/providers/todo_notifier.dart';
''',
              'lib/features/todo/presentation/providers/todo_notifier.dart': '''
part of '../../todo.dart';

class TodoException implements Exception {}

class TodoNotifier {
  void build() {
    throw TodoException();
  }
}
''',
            },
            definingFile: 'lib/features/todo/todo.dart',
          );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath:
              'lib/features/todo/presentation/providers/todo_notifier.dart',
          codeName: 'presentation_no_throw',
          line: 7,
        ),
      ]);
    });

    test('requires state/provider presentation path under lib', () {
      expect(
        isPresentationStateManagementPath(
          '/project/lib/features/todo/presentation/providers/todo_provider.dart',
        ),
        isTrue,
      );
      expect(
        isPresentationStateManagementPath(
          '/project/lib/features/todo/presentation/states/todo_state.dart',
        ),
        isTrue,
      );
      expect(
        isPresentationStateManagementPath(
          '/project/lib/features/todo/presentation/pages/todo_page.dart',
        ),
        isFalse,
      );
      expect(
        isPresentationStateManagementPath(
          '/project/lib/features/todo/providers/todo_provider.dart',
        ),
        isTrue,
      );
      expect(
        isPresentationStateManagementPath(
          '/project/lib/features/todo/states/todo_state.dart',
        ),
        isTrue,
      );
      expect(
        isPresentationStateManagementPath(
          '/project/lib/features/todo/domain/providers/foo.dart',
        ),
        isFalse,
      );
    });
  });
}
