import 'package:clean_architecture_linter/src/rules/presentation_rules/riverpod_extension_scoped_dependency_rule.dart';
import 'package:test/test.dart';

import '../../../v2_harness/analysis_rule_harness.dart';

/// Fake Riverpod annotations shared by the fixtures. The harness resolves the
/// library, but the rule itself is parsed-only (reads identifier lexemes), so
/// these just need to make the annotations/identifiers nameable.
const _fakes = '''
class Riverpod {
  const Riverpod({this.keepAlive = false, this.dependencies});
  final bool keepAlive;
  final List<Object>? dependencies;
}

class Dependencies {
  const Dependencies(this.dependencies);
  final List<Object> dependencies;
}

const Object executeRoutine = 0;
const Object manageReminder = 0;
const Object toggleTodo = 0;
''';

void main() {
  group('RiverpodExtensionScopedDependencyRule v2', () {
    test(
      'reports when a part extension @Dependencies is not in the notifier scope',
      () async {
        final result =
            await V2RuleHarness(
              rule: RiverpodExtensionScopedDependencyRule(),
            ).analyze(
              files: {
                'lib/features/todo/presentation/providers/pomodoro_notifier.dart':
                    '''
$_fakes

part 'pomodoro_notifier_helpers.dart';

@Riverpod(dependencies: [toggleTodo])
class PomodoroNotifier {}
''',
                'lib/features/todo/presentation/providers/pomodoro_notifier_helpers.dart':
                    '''
part of 'pomodoro_notifier.dart';

@Dependencies([executeRoutine, manageReminder])
extension PomodoroNotifierHelpers on PomodoroNotifier {}
''',
              },
              definingFile:
                  'lib/features/todo/presentation/providers/pomodoro_notifier.dart',
            );

        result.expectDiagnostics([
          const ExpectedV2Diagnostic(
            relativePath:
                'lib/features/todo/presentation/providers/pomodoro_notifier_helpers.dart',
            codeName: 'riverpod_extension_scoped_dependency',
            problemMessage:
                'Extension @Dependencies declares scoped provider(s) '
                '[executeRoutine, manageReminder] that are not in '
                "PomodoroNotifier's @Riverpod(dependencies:). @Dependencies on "
                'an extension is lint-only metadata and does not widen the '
                "notifier's runtime scope, so ref.read/watch of these providers "
                'throws at runtime.',
            correctionMessage:
                'Add [executeRoutine, manageReminder] to PomodoroNotifier\'s '
                '@Riverpod(dependencies: [...]) (its runtime scope), or remove '
                "them from the extension's @Dependencies if the notifier never "
                'reads them.',
          ),
        ]);
      },
    );

    test('does not report when the extension deps are a subset', () async {
      final result =
          await V2RuleHarness(
            rule: RiverpodExtensionScopedDependencyRule(),
          ).analyze(
            files: {
              'lib/features/todo/presentation/providers/pomodoro_notifier.dart':
                  '''
$_fakes

part 'pomodoro_notifier_helpers.dart';

@Riverpod(dependencies: [executeRoutine, manageReminder, toggleTodo])
class PomodoroNotifier {}
''',
              'lib/features/todo/presentation/providers/pomodoro_notifier_helpers.dart':
                  '''
part of 'pomodoro_notifier.dart';

@Dependencies([executeRoutine, manageReminder])
extension PomodoroNotifierHelpers on PomodoroNotifier {}
''',
            },
            definingFile:
                'lib/features/todo/presentation/providers/pomodoro_notifier.dart',
          );

      result.expectNoDiagnostics();
    });

    test('does not report when the notifier has no dependencies argument '
        '(not scoped)', () async {
      final result =
          await V2RuleHarness(
            rule: RiverpodExtensionScopedDependencyRule(),
          ).analyze(
            files: {
              'lib/features/todo/presentation/providers/pomodoro_notifier.dart':
                  '''
$_fakes

part 'pomodoro_notifier_helpers.dart';

@Riverpod()
class PomodoroNotifier {}
''',
              'lib/features/todo/presentation/providers/pomodoro_notifier_helpers.dart':
                  '''
part of 'pomodoro_notifier.dart';

@Dependencies([executeRoutine])
extension PomodoroNotifierHelpers on PomodoroNotifier {}
''',
            },
            definingFile:
                'lib/features/todo/presentation/providers/pomodoro_notifier.dart',
          );

      result.expectNoDiagnostics();
    });

    test('does not report when the notifier only specifies keepAlive '
        '(no dependencies argument)', () async {
      final result =
          await V2RuleHarness(
            rule: RiverpodExtensionScopedDependencyRule(),
          ).analyze(
            files: {
              'lib/features/todo/presentation/providers/pomodoro_notifier.dart':
                  '''
$_fakes

part 'pomodoro_notifier_helpers.dart';

@Riverpod(keepAlive: true)
class PomodoroNotifier {}
''',
              'lib/features/todo/presentation/providers/pomodoro_notifier_helpers.dart':
                  '''
part of 'pomodoro_notifier.dart';

@Dependencies([executeRoutine])
extension PomodoroNotifierHelpers on PomodoroNotifier {}
''',
            },
            definingFile:
                'lib/features/todo/presentation/providers/pomodoro_notifier.dart',
          );

      result.expectNoDiagnostics();
    });

    test(
      'reports a same-file extension (cross-unit lookup covers same unit)',
      () async {
        final result =
            await V2RuleHarness(
              rule: RiverpodExtensionScopedDependencyRule(),
            ).analyze(
              files: {
                'lib/features/todo/presentation/providers/pomodoro_notifier.dart':
                    '''
$_fakes

@Riverpod(dependencies: [toggleTodo])
class PomodoroNotifier {}

@Dependencies([executeRoutine])
extension PomodoroNotifierHelpers on PomodoroNotifier {}
''',
              },
              definingFile:
                  'lib/features/todo/presentation/providers/pomodoro_notifier.dart',
            );

        result.expectDiagnostics([
          const ExpectedV2Diagnostic(
            relativePath:
                'lib/features/todo/presentation/providers/pomodoro_notifier.dart',
            codeName: 'riverpod_extension_scoped_dependency',
          ),
        ]);
      },
    );

    test('reports against an empty but present dependencies list '
        '(empty scope is still scoped)', () async {
      final result =
          await V2RuleHarness(
            rule: RiverpodExtensionScopedDependencyRule(),
          ).analyze(
            files: {
              'lib/features/todo/presentation/providers/pomodoro_notifier.dart':
                  '''
$_fakes

@Riverpod(dependencies: [])
class PomodoroNotifier {}

@Dependencies([executeRoutine])
extension PomodoroNotifierHelpers on PomodoroNotifier {}
''',
            },
            definingFile:
                'lib/features/todo/presentation/providers/pomodoro_notifier.dart',
          );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath:
              'lib/features/todo/presentation/providers/pomodoro_notifier.dart',
          codeName: 'riverpod_extension_scoped_dependency',
        ),
      ]);
    });

    test(
      'does not report when the extended class has no @Riverpod annotation',
      () async {
        final result =
            await V2RuleHarness(
              rule: RiverpodExtensionScopedDependencyRule(),
            ).analyze(
              files: {
                'lib/features/todo/presentation/providers/pomodoro_notifier_helpers.dart':
                    '''
$_fakes

@Dependencies([executeRoutine])
extension PomodoroNotifierHelpers on PomodoroNotifier {}

class PomodoroNotifier {}
''',
              },
              definingFile:
                  'lib/features/todo/presentation/providers/pomodoro_notifier_helpers.dart',
            );

        // PomodoroNotifier has no @Riverpod annotation at all -> not scoped, so
        // there is no runtime scope list to compare against.
        result.expectNoDiagnostics();
      },
    );
  });
}
