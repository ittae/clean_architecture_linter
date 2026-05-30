import 'package:clean_architecture_linter/src/rules/data_rules/model_structure_rule.dart';
import 'package:test/test.dart';

import '../../../v2_harness/analysis_rule_harness.dart';

void main() {
  group('ModelStructureRule v2', () {
    test('reports missing Freezed annotation with dynamic context', () async {
      final result = await V2RuleHarness(rule: ModelStructureRule()).analyze(
        files: {
          'lib/features/todo/data/models/todo_model.dart': '''
class Todo {}

class TodoModel {
  const TodoModel({required this.entity});

  final Todo entity;
}
''',
        },
        definingFile: 'lib/features/todo/data/models/todo_model.dart',
      );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath: 'lib/features/todo/data/models/todo_model.dart',
          codeName: 'model_structure',
          line: 3,
          problemMessage:
              'Data model "TodoModel" should use @freezed annotation',
          correctionMessage:
              'Add @freezed annotation above the class declaration.',
        ),
      ]);
    });

    test('reports non-sealed Freezed model', () async {
      final result = await V2RuleHarness(rule: ModelStructureRule()).analyze(
        files: {
          'lib/features/todo/data/models/todo_model.dart': '''
const freezed = Object();

class Todo {}

@freezed
class TodoModel {
  const factory TodoModel({required Todo entity}) = TodoModelImpl;
}

class TodoModelImpl implements TodoModel {
  const TodoModelImpl({required this.entity});

  final Todo entity;
}
''',
        },
        definingFile: 'lib/features/todo/data/models/todo_model.dart',
      );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath: 'lib/features/todo/data/models/todo_model.dart',
          codeName: 'model_structure',
          line: 5,
          problemMessage: 'Data model "TodoModel" should be a sealed class',
          correctionMessage:
              'Add "sealed" modifier before "class" keyword (e.g., "sealed class TodoModel").',
        ),
      ]);
    });

    test('reports missing Entity field in factory constructor', () async {
      final result = await V2RuleHarness(rule: ModelStructureRule()).analyze(
        files: {
          'lib/features/todo/data/models/todo_model.dart': '''
const freezed = Object();

@freezed
sealed class TodoModel {
  const factory TodoModel({required String title}) = TodoModelImpl;
}

class TodoModelImpl implements TodoModel {
  const TodoModelImpl({required this.title});

  final String title;
}
''',
        },
        definingFile: 'lib/features/todo/data/models/todo_model.dart',
      );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath: 'lib/features/todo/data/models/todo_model.dart',
          codeName: 'model_structure',
          line: 3,
          problemMessage: 'Data model "TodoModel" should contain Entity field',
          correctionMessage:
              'Add "required EntityName entity" field to contain the Domain Entity.',
        ),
      ]);
    });

    test('accepts valid Freezed sealed model with Entity field', () async {
      final result = await V2RuleHarness(rule: ModelStructureRule()).analyze(
        files: {
          'lib/features/todo/data/models/todo_model.dart': '''
const freezed = Object();

class Todo {}

@freezed
sealed class TodoModel {
  const factory TodoModel({
    required Todo entity,
    String? etag,
  }) = TodoModelImpl;
}

class TodoModelImpl implements TodoModel {
  const TodoModelImpl({required this.entity, this.etag});

  final Todo entity;
  final String? etag;
}
''',
        },
        definingFile: 'lib/features/todo/data/models/todo_model.dart',
      );

      result.expectNoDiagnostics();
    });

    test('skips database annotated model classes', () async {
      final result = await V2RuleHarness(rule: ModelStructureRule()).analyze(
        files: {
          'lib/features/todo/data/models/todo_model.dart': '''
const Entity = Object();

@Entity
class TodoModel {
  TodoModel(this.id);

  final int id;
}
''',
        },
        definingFile: 'lib/features/todo/data/models/todo_model.dart',
      );

      result.expectNoDiagnostics();
    });

    test('ignores generated files', () async {
      final result = await V2RuleHarness(rule: ModelStructureRule()).analyze(
        files: {
          'lib/features/todo/data/models/todo_model.g.dart': '''
class TodoModel {
  const TodoModel();
}
''',
        },
        definingFile: 'lib/features/todo/data/models/todo_model.g.dart',
      );

      result.expectNoDiagnostics();
    });

    test('ignores non-data-model paths and non-Model classes', () async {
      final result = await V2RuleHarness(rule: ModelStructureRule()).analyze(
        files: {
          'lib/features/todo/domain/entities/todo.dart': '''
class TodoModel {}
''',
          'lib/features/todo/data/models/todo_dto.dart': '''
class TodoDto {}
''',
        },
        definingFile: 'lib/features/todo/domain/entities/todo.dart',
        additionalDefiningFiles: [
          'lib/features/todo/data/models/todo_dto.dart',
        ],
      );

      result.expectNoDiagnostics();
    });
  });
}
