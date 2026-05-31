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
              'Avoid using "ref.mounted" to guard async operations. This masks design problems.',
          correctionMessage:
              "Instead: (1) Complete async work before navigation, or (2) Call UseCase directly then navigate - new screen's provider will load state.",
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
              'Avoid using "ref.mounted" to guard async operations. This masks design problems.',
          correctionMessage:
              "Instead: (1) Complete async work before navigation, or (2) Call UseCase directly then navigate - new screen's provider will load state.",
        ),
        const ExpectedV2Diagnostic(
          relativePath: 'lib/features/todo/providers/todo_provider.dart',
          codeName: 'ref_mounted_usage',
          problemMessage:
              'Avoid using "ref.mounted" to guard async operations. This masks design problems.',
          correctionMessage:
              "Instead: (1) Complete async work before navigation, or (2) Call UseCase directly then navigate - new screen's provider will load state.",
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
