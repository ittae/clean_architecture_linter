import 'package:clean_architecture_linter/src/rules/domain_rules/domain_purity_rule.dart';
import 'package:test/test.dart';

import '../../../v2_harness/analysis_rule_harness.dart';

void main() {
  group('DomainPurityRule v2', () {
    test('reports dynamic import violation message', () async {
      final result = await V2RuleHarness(rule: DomainPurityRule()).analyze(
        files: {
          'lib/features/todo/domain/entities/todo.dart': '''
import 'package:flutter/widgets.dart';

class Todo extends Widget {}
''',
        },
        definingFile: 'lib/features/todo/domain/entities/todo.dart',
      );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath: 'lib/features/todo/domain/entities/todo.dart',
          codeName: 'domain_purity',
          problemMessage:
              'Domain layer violation: UI Framework dependency detected',
          correctionMessage:
              'Domain layer should not depend on UI frameworks. Use abstractions or move this logic to presentation layer.',
        ),
        const ExpectedV2Diagnostic(
          relativePath: 'lib/features/todo/domain/entities/todo.dart',
          codeName: 'domain_purity',
          problemMessage:
              'Domain layer violation: Domain entities should not extend external framework classes (Widget)',
          correctionMessage:
              'Use composition instead of inheritance from external frameworks.',
        ),
      ]);
    });

    test('allows dart io type references in domain signatures', () async {
      final result = await V2RuleHarness(rule: DomainPurityRule()).analyze(
        files: {
          'lib/features/todo/domain/entities/todo_file.dart': '''
import 'dart:io';

class TodoFile {
  final File file;
  const TodoFile(this.file);
}
''',
        },
        definingFile: 'lib/features/todo/domain/entities/todo_file.dart',
      );

      result.expectNoDiagnostics();
    });

    test('reports category-specific import corrections', () async {
      final result = await V2RuleHarness(rule: DomainPurityRule()).analyze(
        files: {
          'lib/features/todo/domain/entities/todo.dart': '''
import 'package:dio/dio.dart';
import 'package:sqflite/sqflite.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:riverpod/riverpod.dart';

class Todo {}
''',
        },
        definingFile: 'lib/features/todo/domain/entities/todo.dart',
      );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath: 'lib/features/todo/domain/entities/todo.dart',
          codeName: 'domain_purity',
          problemMessage:
              'Domain layer violation: Networking dependency detected',
          correctionMessage:
              'Use repository abstractions instead of direct HTTP clients in domain layer.',
        ),
        const ExpectedV2Diagnostic(
          relativePath: 'lib/features/todo/domain/entities/todo.dart',
          codeName: 'domain_purity',
          problemMessage: 'Domain layer violation: Storage dependency detected',
          correctionMessage:
              'Use repository abstractions instead of direct storage dependencies in domain layer.',
        ),
        const ExpectedV2Diagnostic(
          relativePath: 'lib/features/todo/domain/entities/todo.dart',
          codeName: 'domain_purity',
          problemMessage:
              'Domain layer violation: Platform-specific dependency detected',
          correctionMessage:
              'Use service abstractions instead of direct platform dependencies in domain layer.',
        ),
        const ExpectedV2Diagnostic(
          relativePath: 'lib/features/todo/domain/entities/todo.dart',
          codeName: 'domain_purity',
          problemMessage:
              'Domain layer violation: State management dependency detected',
          correctionMessage:
              'State management should be handled in presentation layer, not domain layer.',
        ),
      ]);
    });

    test('reports implements external framework correction', () async {
      final result = await V2RuleHarness(rule: DomainPurityRule()).analyze(
        files: {
          'lib/features/todo/domain/entities/todo.dart': '''
class ChangeNotifier {}

class Todo implements ChangeNotifier {}
''',
        },
        definingFile: 'lib/features/todo/domain/entities/todo.dart',
      );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath: 'lib/features/todo/domain/entities/todo.dart',
          codeName: 'domain_purity',
          problemMessage:
              'Domain layer violation: Domain classes should not implement external framework interfaces (ChangeNotifier)',
          correctionMessage:
              'Create domain-specific abstractions instead of implementing external interfaces.',
        ),
      ]);
    });

    test('skips non-domain files', () async {
      final result = await V2RuleHarness(rule: DomainPurityRule()).analyze(
        files: {
          'lib/features/todo/presentation/todo_widget.dart': '''
import 'package:flutter/widgets.dart';

class TodoWidget extends Widget {}
''',
        },
        definingFile: 'lib/features/todo/presentation/todo_widget.dart',
      );

      result.expectNoDiagnostics();
    });

    test('skips generated files', () async {
      final result = await V2RuleHarness(rule: DomainPurityRule()).analyze(
        files: {
          'lib/features/todo/domain/entities/todo.g.dart': '''
import 'package:flutter/widgets.dart';

class Todo extends Widget {}
''',
        },
        definingFile: 'lib/features/todo/domain/entities/todo.g.dart',
      );

      result.expectNoDiagnostics();
    });
  });
}
