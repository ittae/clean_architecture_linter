import 'package:clean_architecture_linter/src/rules/presentation_rules/ref_mounted_usage_rule.dart';
import 'package:test/test.dart';

import '../../../v2_harness/analysis_rule_harness.dart';

void main() {
  group('RefMountedUsageRule v2', () {
    test('reports ref.mounted in presentation provider files', () async {
      final result = await V2RuleHarness(rule: RefMountedUsageRule()).analyze(
        files: {
          'lib/features/todo/presentation/providers/todo_provider.dart': '''
class Ref {
  bool get mounted => true;
}

void update(Ref ref) {
  if (ref.mounted) {
    return;
  }
}
''',
        },
        definingFile:
            'lib/features/todo/presentation/providers/todo_provider.dart',
      );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath:
              'lib/features/todo/presentation/providers/todo_provider.dart',
          codeName: 'ref_mounted_usage',
          problemMessage:
              'Avoid using "ref.mounted" to guard async operations in the UI layer. This masks design problems.',
          correctionMessage:
              "Instead: (1) Complete async work before navigation, or (2) Call UseCase directly then navigate - new screen's provider will load state. Inside a Notifier, \"if (!ref.mounted) return;\" is the recommended disposal guard and is not reported.",
        ),
      ]);
    });

    test('reports negated ref.mounted pattern', () async {
      final result = await V2RuleHarness(rule: RefMountedUsageRule()).analyze(
        files: {
          'lib/features/todo/providers/todo_provider.dart': '''
class Ref {
  bool get mounted => true;
}

void update(Ref ref) {
  if (!ref.mounted) {
    return;
  }
}
''',
        },
        definingFile: 'lib/features/todo/providers/todo_provider.dart',
      );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath: 'lib/features/todo/providers/todo_provider.dart',
          codeName: 'ref_mounted_usage',
          problemMessage:
              'Avoid using "ref.mounted" to guard async operations in the UI layer. This masks design problems.',
          correctionMessage:
              "Instead: (1) Complete async work before navigation, or (2) Call UseCase directly then navigate - new screen's provider will load state. Inside a Notifier, \"if (!ref.mounted) return;\" is the recommended disposal guard and is not reported.",
        ),
      ]);
    });

    test('ignores non-presentation non-provider files', () async {
      final result = await V2RuleHarness(rule: RefMountedUsageRule()).analyze(
        files: {
          'lib/features/todo/domain/usecases/update_todo_usecase.dart': '''
class Ref {
  bool get mounted => true;
}

void update(Ref ref) {
  if (ref.mounted) {}
}
''',
        },
        definingFile:
            'lib/features/todo/domain/usecases/update_todo_usecase.dart',
      );

      result.expectNoDiagnostics();
    });

    test('does not report the disposal guard inside a Notifier', () async {
      final result = await V2RuleHarness(rule: RefMountedUsageRule()).analyze(
        files: {
          'lib/features/todo/presentation/providers/todo_notifier.dart': '''
abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {
  Future<void> save() async {
    await persist();
    if (!ref.mounted) return;
    state = 1;
  }
}
''',
        },
        definingFile:
            'lib/features/todo/presentation/providers/todo_notifier.dart',
      );

      result.expectNoDiagnostics();
    });

    test('does not report ref.mounted inside an annotated Notifier', () async {
      final result = await V2RuleHarness(rule: RefMountedUsageRule()).analyze(
        files: {
          'lib/features/todo/presentation/providers/todo_notifier.dart': '''
class riverpod {
  const riverpod();
}

@riverpod
class TodoNotifier {
  Future<void> save() async {
    await persist();
    if (ref.mounted) {
      state = 1;
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

    test(
      'does not report ref.mounted in a functional @riverpod provider',
      () async {
        final result = await V2RuleHarness(rule: RefMountedUsageRule()).analyze(
          files: {
            'lib/features/todo/presentation/providers/save_todo_provider.dart':
                '''
class riverpod {
  const riverpod();
}

@riverpod
Future<void> saveTodo(Object ref) async {
  await persist();
  if (!ref.mounted) return;
  ref.invalidate(todoProvider);
}
''',
          },
          definingFile:
              'lib/features/todo/presentation/providers/save_todo_provider.dart',
        );

        result.expectNoDiagnostics();
      },
    );

    test(
      'does not report in an extension on a Notifier in a part file',
      () async {
        final result = await V2RuleHarness(rule: RefMountedUsageRule()).analyze(
          files: {
            'lib/features/todo/presentation/providers/todo_notifier.dart': '''
part 'todo_notifier_helpers.dart';

abstract class _\$TodoNotifier {}

class TodoNotifier extends _\$TodoNotifier {}
''',
            'lib/features/todo/presentation/providers/todo_notifier_helpers.dart':
                '''
part of 'todo_notifier.dart';

extension _TodoNotifierHelpers on TodoNotifier {
  Future<void> save() async {
    await persist();
    if (!ref.mounted) return;
    state = 1;
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
      'still reports in an extension on a widget declared in the library body',
      () async {
        final result = await V2RuleHarness(rule: RefMountedUsageRule()).analyze(
          files: {
            'lib/features/todo/presentation/providers/todo_notifier.dart': '''
part 'todo_notifier_helpers.dart';

class ConsumerWidget {}

class TodoNotifier extends ConsumerWidget {}
''',
            'lib/features/todo/presentation/providers/todo_notifier_helpers.dart':
                '''
part of 'todo_notifier.dart';

extension Helpers on TodoNotifier {
  Future<void> onTap() async {
    await save();
    if (!ref.mounted) return;
    navigate();
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
            codeName: 'ref_mounted_usage',
            problemMessage:
                'Avoid using "ref.mounted" to guard async operations in the UI layer. This masks design problems.',
            correctionMessage:
                "Instead: (1) Complete async work before navigation, or (2) Call UseCase directly then navigate - new screen's provider will load state. Inside a Notifier, \"if (!ref.mounted) return;\" is the recommended disposal guard and is not reported.",
          ),
        ]);
      },
    );

    test('does not report in an extension on a generic Notifier', () async {
      final result = await V2RuleHarness(rule: RefMountedUsageRule()).analyze(
        files: {
          'lib/features/todo/presentation/providers/todo_notifier.dart': '''
abstract class _\$TodoNotifier<T> {}

class TodoNotifier<T> extends _\$TodoNotifier<T> {}

extension Helpers<T> on TodoNotifier<T> {
  Future<void> save() async {
    await persist();
    if (!ref.mounted) return;
    state = 1;
  }
}
''',
        },
        definingFile:
            'lib/features/todo/presentation/providers/todo_notifier.dart',
      );

      result.expectNoDiagnostics();
    });

    test('still reports in an extension on a widget typedef', () async {
      final result = await V2RuleHarness(rule: RefMountedUsageRule()).analyze(
        files: {
          'lib/features/todo/presentation/providers/todo_alias.dart': '''
class ConsumerWidget {}

class TodoPage extends ConsumerWidget {}

typedef TodoNotifier = TodoPage;

extension Helpers on TodoNotifier {
  Future<void> onTap() async {
    await save();
    if (!ref.mounted) return;
    navigate();
  }
}
''',
        },
        definingFile:
            'lib/features/todo/presentation/providers/todo_alias.dart',
      );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath:
              'lib/features/todo/presentation/providers/todo_alias.dart',
          codeName: 'ref_mounted_usage',
          problemMessage:
              'Avoid using "ref.mounted" to guard async operations in the UI layer. This masks design problems.',
          correctionMessage:
              "Instead: (1) Complete async work before navigation, or (2) Call UseCase directly then navigate - new screen's provider will load state. Inside a Notifier, \"if (!ref.mounted) return;\" is the recommended disposal guard and is not reported.",
        ),
      ]);
    });

    test('still reports in an extension on a widget', () async {
      final result = await V2RuleHarness(rule: RefMountedUsageRule()).analyze(
        files: {
          'lib/features/todo/presentation/pages/todo_page.dart': '''
class ConsumerWidget {}

class TodoPage extends ConsumerWidget {}

extension TodoPageHelpers on TodoPage {
  Future<void> onTap() async {
    await save();
    if (!ref.mounted) return;
    navigate();
  }
}
''',
        },
        definingFile: 'lib/features/todo/presentation/pages/todo_page.dart',
      );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath: 'lib/features/todo/presentation/pages/todo_page.dart',
          codeName: 'ref_mounted_usage',
          problemMessage:
              'Avoid using "ref.mounted" to guard async operations in the UI layer. This masks design problems.',
          correctionMessage:
              "Instead: (1) Complete async work before navigation, or (2) Call UseCase directly then navigate - new screen's provider will load state. Inside a Notifier, \"if (!ref.mounted) return;\" is the recommended disposal guard and is not reported.",
        ),
      ]);
    });

    test('still reports ref.mounted inside a ConsumerWidget', () async {
      final result = await V2RuleHarness(rule: RefMountedUsageRule()).analyze(
        files: {
          'lib/features/todo/presentation/pages/todo_page.dart': '''
class ConsumerWidget {}

class TodoPage extends ConsumerWidget {
  Future<void> onTap() async {
    await save();
    if (!ref.mounted) return;
    navigate();
  }
}
''',
        },
        definingFile: 'lib/features/todo/presentation/pages/todo_page.dart',
      );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath: 'lib/features/todo/presentation/pages/todo_page.dart',
          codeName: 'ref_mounted_usage',
          problemMessage:
              'Avoid using "ref.mounted" to guard async operations in the UI layer. This masks design problems.',
          correctionMessage:
              "Instead: (1) Complete async work before navigation, or (2) Call UseCase directly then navigate - new screen's provider will load state. Inside a Notifier, \"if (!ref.mounted) return;\" is the recommended disposal guard and is not reported.",
        ),
      ]);
    });

    test('still reports ref.mounted inside a ConsumerState', () async {
      final result = await V2RuleHarness(rule: RefMountedUsageRule()).analyze(
        files: {
          'lib/features/todo/presentation/providers/todo_view.dart': '''
class ConsumerState {}

class TodoViewState extends ConsumerState {
  Future<void> onTap() async {
    await save();
    if (ref.mounted) {
      navigate();
    }
  }
}
''',
        },
        definingFile: 'lib/features/todo/presentation/providers/todo_view.dart',
      );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath:
              'lib/features/todo/presentation/providers/todo_view.dart',
          codeName: 'ref_mounted_usage',
          problemMessage:
              'Avoid using "ref.mounted" to guard async operations in the UI layer. This masks design problems.',
          correctionMessage:
              "Instead: (1) Complete async work before navigation, or (2) Call UseCase directly then navigate - new screen's provider will load state. Inside a Notifier, \"if (!ref.mounted) return;\" is the recommended disposal guard and is not reported.",
        ),
      ]);
    });

    test('still reports in a ConsumerWidget named like a Notifier', () async {
      final result = await V2RuleHarness(rule: RefMountedUsageRule()).analyze(
        files: {
          'lib/features/todo/presentation/providers/todo_notifier.dart': '''
class ConsumerWidget {}

class TodoNotifier extends ConsumerWidget {
  Future<void> onTap() async {
    await save();
    if (!ref.mounted) return;
    navigate();
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
          codeName: 'ref_mounted_usage',
          problemMessage:
              'Avoid using "ref.mounted" to guard async operations in the UI layer. This masks design problems.',
          correctionMessage:
              "Instead: (1) Complete async work before navigation, or (2) Call UseCase directly then navigate - new screen's provider will load state. Inside a Notifier, \"if (!ref.mounted) return;\" is the recommended disposal guard and is not reported.",
        ),
      ]);
    });

    test('does not report in a Notifier named like a widget', () async {
      final result = await V2RuleHarness(rule: RefMountedUsageRule()).analyze(
        files: {
          'lib/features/todo/presentation/providers/todo_view.dart': '''
class riverpod {
  const riverpod();
}

abstract class _\$TodoView {}

@riverpod
class TodoView extends _\$TodoView {
  Future<void> save() async {
    await persist();
    if (!ref.mounted) return;
    state = 1;
  }
}
''',
        },
        definingFile: 'lib/features/todo/presentation/providers/todo_view.dart',
      );

      result.expectNoDiagnostics();
    });

    test('still reports in a ChangeNotifier subclass', () async {
      final result = await V2RuleHarness(rule: RefMountedUsageRule()).analyze(
        files: {
          'lib/features/todo/presentation/providers/todo_controller.dart': '''
class ChangeNotifier {}

class TodoController extends ChangeNotifier {
  Future<void> load() async {
    await fetch();
    if (!ref.mounted) return;
  }
}
''',
        },
        definingFile:
            'lib/features/todo/presentation/providers/todo_controller.dart',
      );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath:
              'lib/features/todo/presentation/providers/todo_controller.dart',
          codeName: 'ref_mounted_usage',
          problemMessage:
              'Avoid using "ref.mounted" to guard async operations in the UI layer. This masks design problems.',
          correctionMessage:
              "Instead: (1) Complete async work before navigation, or (2) Call UseCase directly then navigate - new screen's provider will load state. Inside a Notifier, \"if (!ref.mounted) return;\" is the recommended disposal guard and is not reported.",
        ),
      ]);
    });

    test('skips generated files', () async {
      final result = await V2RuleHarness(rule: RefMountedUsageRule()).analyze(
        files: {
          'lib/features/todo/presentation/providers/todo_provider.g.dart': '''
class Ref {
  bool get mounted => true;
}

void update(Ref ref) {
  if (ref.mounted) {}
}
''',
        },
        definingFile:
            'lib/features/todo/presentation/providers/todo_provider.g.dart',
      );

      result.expectNoDiagnostics();
    });
  });
}
