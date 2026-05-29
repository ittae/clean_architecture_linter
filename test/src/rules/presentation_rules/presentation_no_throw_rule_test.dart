import 'package:clean_architecture_linter/src/rules/presentation_rules/presentation_no_throw_rule.dart';
import 'package:test/test.dart';

import '../../../v2_harness/analysis_rule_harness.dart';

void main() {
  group('PresentationNoThrowRule', () {
    test('reports throw expressions in presentation lib files', () async {
      final result = await V2RuleHarness(
        rule: PresentationNoThrowRule(),
      ).analyze(
        files: {
          'lib/features/todo/presentation/bad_notifier.dart': '''
class BadNotifier {
  Future<void> build() async {
    throw StateError('Do not throw directly from presentation code.');
  }
}
''',
        },
        definingFile: 'lib/features/todo/presentation/bad_notifier.dart',
      );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath: 'lib/features/todo/presentation/bad_notifier.dart',
          codeName: 'presentation_no_throw',
        ),
      ]);
    });

    test('ignores throw expressions owned by AsyncValue.guard', () async {
      final result = await V2RuleHarness(
        rule: PresentationNoThrowRule(),
      ).analyze(
        files: {
          'lib/features/todo/presentation/good_notifier.dart': '''
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
        definingFile: 'lib/features/todo/presentation/good_notifier.dart',
      );

      result.expectNoDiagnostics();
    });

    test('requires presentation segment under lib', () async {
      final result = await V2RuleHarness(
        rule: PresentationNoThrowRule(),
      ).analyze(
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
      final result = await V2RuleHarness(
        rule: PresentationNoThrowRule(),
      ).analyze(
        files: {
          'lib/features/todo/todo.dart': '''
part 'presentation/todo_notifier.dart';
''',
          'lib/features/todo/presentation/todo_notifier.dart': '''
part of '../todo.dart';

class TodoNotifier {
  void build() {
    throw StateError('Part file path should be checked.');
  }
}
''',
        },
        definingFile: 'lib/features/todo/todo.dart',
      );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath: 'lib/features/todo/presentation/todo_notifier.dart',
          codeName: 'presentation_no_throw',
        ),
      ]);
    });
  });
}
