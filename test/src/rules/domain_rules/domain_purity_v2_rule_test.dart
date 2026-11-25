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

    test('reports exports, conditional imports, and barrel re-exports', () async {
      const entity = 'lib/features/todo/domain/entities/todo.dart';
      final result = await V2RuleHarness(rule: DomainPurityRule()).analyze(
        files: {
          entity: '''
export 'package:flutter/widgets.dart' show Widget;
import 'todo_id.dart'
    if (dart.library.html) 'package:flutter/widgets.dart';
import '../../todo_api.dart';

class Todo {}
''',
          'lib/features/todo/domain/entities/todo_id.dart': 'class TodoId {}',
          'lib/features/todo/todo_api.dart': '''
export 'package:dio/dio.dart';
''',
        },
        definingFile: entity,
      );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath: entity,
          codeName: 'domain_purity',
          problemMessage:
              'Domain layer violation: UI Framework dependency detected',
        ),
        const ExpectedV2Diagnostic(
          relativePath: entity,
          codeName: 'domain_purity',
          problemMessage:
              'Domain layer violation: UI Framework dependency detected',
        ),
        const ExpectedV2Diagnostic(
          relativePath: entity,
          codeName: 'domain_purity',
          problemMessage:
              'Domain layer violation: Networking dependency detected via package:dio/dio.dart',
        ),
      ]);
    });

    test('reports framework exports behind conditional barrels', () async {
      const entity = 'lib/features/todo/domain/entities/todo.dart';
      const viaDio = ExpectedV2Diagnostic(
        relativePath: entity,
        codeName: 'domain_purity',
        problemMessage:
            'Domain layer violation: Networking dependency detected via package:dio/dio.dart',
      );
      const shared = {
        'lib/features/todo/domain/entities/todo_id.dart': 'class TodoId {}',
        'lib/features/todo/todo_api.dart': "export 'package:dio/dio.dart';",
      };

      final domainPrimary = await V2RuleHarness(rule: DomainPurityRule())
          .analyze(
            files: {
              ...shared,
              entity: '''
import 'todo_id.dart' if (dart.library.io) '../../todo_api.dart';

class Todo {}
''',
            },
            definingFile: entity,
          );
      domainPrimary.expectDiagnostics([viaDio]);

      final unresolvedPrimary = await V2RuleHarness(rule: DomainPurityRule())
          .analyze(
            files: {
              ...shared,
              entity: '''
import 'package:meta/meta.dart' if (dart.library.io) '../../todo_api.dart';

class Todo {}
''',
            },
            definingFile: entity,
          );
      unresolvedPrimary.expectDiagnostics([viaDio]);

      final domainExport = await V2RuleHarness(rule: DomainPurityRule())
          .analyze(
            files: {
              ...shared,
              entity: '''
export 'todo_id.dart' if (dart.library.html) '../../todo_api.dart';

class Todo {}
''',
            },
            definingFile: entity,
          );
      domainExport.expectDiagnostics([viaDio]);
    });

    test('classifies part files by the parent library', () async {
      const library = 'lib/features/todo/domain/entities/todo.dart';
      const part = 'lib/features/todo/data/todo_part.dart';
      final violation = await V2RuleHarness(rule: DomainPurityRule()).analyze(
        files: {
          library: '''
import 'package:flutter/widgets.dart';

part '../../data/todo_part.dart';

class Todo {}
''',
          part: '''
part of '../domain/entities/todo.dart';

class TodoPart extends Widget {}
''',
        },
        definingFile: library,
      );

      violation.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath: library,
          codeName: 'domain_purity',
          problemMessage:
              'Domain layer violation: UI Framework dependency detected',
        ),
        const ExpectedV2Diagnostic(
          relativePath: part,
          codeName: 'domain_purity',
          problemMessage:
              'Domain layer violation: Domain entities should not extend external framework classes (Widget)',
        ),
      ]);

      const dataLibrary = 'lib/features/todo/data/models/todo_model.dart';
      const domainPart = 'lib/features/todo/domain/entities/model_part.dart';
      final allowed = await V2RuleHarness(rule: DomainPurityRule()).analyze(
        files: {
          dataLibrary: '''
part '../../domain/entities/model_part.dart';

class TodoModel {}
''',
          domainPart: '''
part of '../../data/models/todo_model.dart';

class ModelPart extends Widget {}
''',
        },
        definingFile: dataLibrary,
      );

      allowed.expectNoDiagnostics();
    });

    test('does not treat presentation entities as domain', () async {
      final result = await V2RuleHarness(rule: DomainPurityRule()).analyze(
        files: {
          'lib/features/todo/presentation/entities/todo_view.dart': '''
import 'package:flutter/widgets.dart';

class TodoView extends Widget {}
''',
          'lib/features/todo/data/exceptions/api_exception.dart': '''
import 'package:dio/dio.dart';

class ApiException implements Exception {}
''',
        },
        definingFile: 'lib/features/todo/presentation/entities/todo_view.dart',
        additionalDefiningFiles: const [
          'lib/features/todo/data/exceptions/api_exception.dart',
        ],
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
