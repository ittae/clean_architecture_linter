import 'package:clean_architecture_linter/src/rules/data_rules/model_naming_convention_rule.dart';
import 'package:test/test.dart';

import '../../../v2_harness/analysis_rule_harness.dart';

void main() {
  group('ModelNamingConventionRule v2', () {
    test('reports DataSource implementation keyword in Model name', () async {
      final result = await V2RuleHarness(rule: ModelNamingConventionRule())
          .analyze(
            files: {
              'lib/features/todo/data/models/todo_firestore_model.dart': '''
class TodoFirestoreModel {}
''',
            },
            definingFile:
                'lib/features/todo/data/models/todo_firestore_model.dart',
          );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath:
              'lib/features/todo/data/models/todo_firestore_model.dart',
          codeName: 'model_naming_convention',
          line: 1,
          problemMessage:
              'Model name "TodoFirestoreModel" should not include DataSource implementation "firestore". This violates implementation independence.',
          correctionMessage:
              'Rename to "TodoModel". Models should be independent of DataSource implementation.',
        ),
      ]);
    });

    test('reports only first forbidden keyword', () async {
      final result = await V2RuleHarness(rule: ModelNamingConventionRule())
          .analyze(
            files: {
              'lib/features/todo/data/models/todo_remote_api_model.dart': '''
class TodoRemoteApiModel {}
''',
            },
            definingFile:
                'lib/features/todo/data/models/todo_remote_api_model.dart',
          );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath:
              'lib/features/todo/data/models/todo_remote_api_model.dart',
          codeName: 'model_naming_convention',
          problemMessage:
              'Model name "TodoRemoteApiModel" should not include DataSource implementation "api". This violates implementation independence.',
          correctionMessage:
              'Rename to "TodoRemoteModel". Models should be independent of DataSource implementation.',
        ),
      ]);
    });

    test('accepts entity-based Model name', () async {
      final result = await V2RuleHarness(rule: ModelNamingConventionRule())
          .analyze(
            files: {
              'lib/features/todo/data/models/todo_model.dart': '''
class TodoModel {}
''',
            },
            definingFile: 'lib/features/todo/data/models/todo_model.dart',
          );

      result.expectNoDiagnostics();
    });

    test('ignores generated files', () async {
      final result = await V2RuleHarness(rule: ModelNamingConventionRule())
          .analyze(
            files: {
              'lib/features/todo/data/models/todo_firestore_model.g.dart': '''
class TodoFirestoreModel {}
''',
            },
            definingFile:
                'lib/features/todo/data/models/todo_firestore_model.g.dart',
          );

      result.expectNoDiagnostics();
    });

    test('ignores non-data-model paths and non-Model classes', () async {
      final result = await V2RuleHarness(rule: ModelNamingConventionRule())
          .analyze(
            files: {
              'lib/features/todo/domain/entities/todo_firestore_model.dart': '''
class TodoFirestoreModel {}
''',
              'lib/features/todo/data/models/todo_firestore_dto.dart': '''
class TodoFirestoreDto {}
''',
            },
            definingFile:
                'lib/features/todo/domain/entities/todo_firestore_model.dart',
            additionalDefiningFiles: [
              'lib/features/todo/data/models/todo_firestore_dto.dart',
            ],
          );

      result.expectNoDiagnostics();
    });
  });
}
