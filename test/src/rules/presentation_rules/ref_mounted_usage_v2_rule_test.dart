import 'package:clean_architecture_linter/src/rules/presentation_rules/ref_mounted_usage_rule.dart';
import 'package:test/test.dart';

import '../../../v2_harness/analysis_rule_harness.dart';

void main() {
  group('RefMountedUsageRule v2', () {
    const problem =
        'Avoid "ref.mounted" in widgets/pages. State-lifecycle checks belong in the Notifier, not the UI.';
    const correction =
        'Render state with ref.watch and delegate mutations to Notifier methods (ref.mounted is the correct post-await guard there). For widget-local async, use context.mounted.';

    test('reports ref.mounted in a page (UI layer)', () async {
      final result = await V2RuleHarness(rule: RefMountedUsageRule()).analyze(
        files: {
          'lib/features/todo/presentation/pages/todo_page.dart': '''
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
        definingFile: 'lib/features/todo/presentation/pages/todo_page.dart',
      );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath: 'lib/features/todo/presentation/pages/todo_page.dart',
          codeName: 'ref_mounted_usage',
          problemMessage: problem,
          correctionMessage: correction,
        ),
      ]);
    });

    test('reports negated ref.mounted in a widget (UI layer)', () async {
      final result = await V2RuleHarness(rule: RefMountedUsageRule()).analyze(
        files: {
          'lib/features/todo/presentation/widgets/todo_card.dart': '''
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
        definingFile: 'lib/features/todo/presentation/widgets/todo_card.dart',
      );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath: 'lib/features/todo/presentation/widgets/todo_card.dart',
          codeName: 'ref_mounted_usage',
          problemMessage: problem,
          correctionMessage: correction,
        ),
      ]);
    });

    test('allows ref.mounted in a Notifier/provider (state layer)', () async {
      final result = await V2RuleHarness(rule: RefMountedUsageRule()).analyze(
        files: {
          'lib/features/todo/presentation/providers/todo_provider.dart': '''
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
        definingFile:
            'lib/features/todo/presentation/providers/todo_provider.dart',
      );

      result.expectNoDiagnostics();
    });

    test('allows ref.mounted in core/providers', () async {
      final result = await V2RuleHarness(rule: RefMountedUsageRule()).analyze(
        files: {
          'lib/core/providers/auth_provider.dart': '''
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
        definingFile: 'lib/core/providers/auth_provider.dart',
      );

      result.expectNoDiagnostics();
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
