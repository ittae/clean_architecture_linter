import 'package:clean_architecture_linter/src/rules/presentation_rules/freezed_usage_rule.dart';
import 'package:test/test.dart';

import '../../../v2_harness/analysis_rule_harness.dart';

void main() {
  group('FreezedUsageRule v2', () {
    test('reports equatable import and extends usage', () async {
      final result = await V2RuleHarness(rule: FreezedUsageRule()).analyze(
        files: {
          'lib/features/todo/presentation/states/todo_state.dart': '''
import 'package:equatable/equatable.dart';

class TodoState extends Equatable {
  @override
  List<Object?> get props => [];
}
''',
        },
        definingFile: 'lib/features/todo/presentation/states/todo_state.dart',
      );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath: 'lib/features/todo/presentation/states/todo_state.dart',
          codeName: 'freezed_usage',
          problemMessage: 'Equatable import detected. Use Freezed instead.',
          correctionMessage:
              'Remove equatable import and add freezed_annotation. Use @freezed for data classes.',
        ),
        const ExpectedV2Diagnostic(
          relativePath: 'lib/features/todo/presentation/states/todo_state.dart',
          codeName: 'freezed_usage',
          problemMessage:
              'Class "TodoState" uses Equatable. Use @freezed instead.',
          correctionMessage:
              'Replace "extends Equatable" with @freezed annotation. Remove props getter and use Freezed factory constructor.',
        ),
      ]);
    });

    test('reports implements usage with dynamic class name', () async {
      final result = await V2RuleHarness(rule: FreezedUsageRule()).analyze(
        files: {
          'lib/features/todo/domain/entities/todo.dart': '''
class Equatable {}
class Todo implements Equatable {}
''',
        },
        definingFile: 'lib/features/todo/domain/entities/todo.dart',
      );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath: 'lib/features/todo/domain/entities/todo.dart',
          codeName: 'freezed_usage',
          problemMessage:
              'Class "Todo" implements Equatable. Use @freezed instead.',
          correctionMessage:
              'Use @freezed annotation for immutable data classes.',
        ),
      ]);
    });

    test('ignores non-architecture files', () async {
      final result = await V2RuleHarness(rule: FreezedUsageRule()).analyze(
        files: {
          'lib/shared/todo.dart': '''
class Equatable {}
class Todo extends Equatable {}
''',
        },
        definingFile: 'lib/shared/todo.dart',
      );

      result.expectNoDiagnostics();
    });

    test('skips generated files', () async {
      final result = await V2RuleHarness(rule: FreezedUsageRule()).analyze(
        files: {
          'lib/features/todo/presentation/states/todo_state.freezed.dart': '''
import 'package:equatable/equatable.dart';
class TodoState extends Equatable {}
''',
        },
        definingFile:
            'lib/features/todo/presentation/states/todo_state.freezed.dart',
      );

      result.expectNoDiagnostics();
    });
  });
}
