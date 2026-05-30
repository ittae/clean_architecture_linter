import 'package:clean_architecture_linter/src/rules/data_rules/model_conversion_methods_rule.dart';
import 'package:test/test.dart';

import '../../../v2_harness/analysis_rule_harness.dart';

void main() {
  group('ModelConversionMethodsRule v2', () {
    test('reports missing toEntity extension with dynamic context', () async {
      final result = await V2RuleHarness(rule: ModelConversionMethodsRule())
          .analyze(
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

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath: 'lib/features/todo/data/models/todo_model.dart',
          codeName: 'model_conversion_methods',
          line: 5,
          problemMessage:
              'Data model "TodoModel" should have toEntity() method in extension',
          correctionMessage:
              'Add extension with toEntity() method (e.g., extension TodoModelX on TodoModel { Entity toEntity() => entity; }).',
        ),
      ]);
    });

    test('accepts same-file instance toEntity extension', () async {
      final result = await V2RuleHarness(rule: ModelConversionMethodsRule())
          .analyze(
            files: {
              'lib/features/todo/data/models/todo_model.dart': '''
const freezed = Object();

class Todo {}

@freezed
sealed class TodoModel {
  const factory TodoModel({
    required Todo entity,
  }) = TodoModelImpl;
}

class TodoModelImpl implements TodoModel {
  const TodoModelImpl({required this.entity});

  final Todo entity;
}

extension TodoModelX on TodoModel {
  Todo toEntity() => entity;
}
''',
            },
            definingFile: 'lib/features/todo/data/models/todo_model.dart',
          );

      result.expectNoDiagnostics();
    });

    test('rejects static toEntity extension method', () async {
      final result = await V2RuleHarness(rule: ModelConversionMethodsRule())
          .analyze(
            files: {
              'lib/features/todo/data/models/todo_model.dart': '''
const freezed = Object();

class Todo {}

@freezed
sealed class TodoModel {
  const factory TodoModel({
    required Todo entity,
  }) = TodoModelImpl;
}

class TodoModelImpl implements TodoModel {
  const TodoModelImpl({required this.entity});

  final Todo entity;
}

extension TodoModelX on TodoModel {
  static Todo toEntity(TodoModel model) => model.entity;
}
''',
            },
            definingFile: 'lib/features/todo/data/models/todo_model.dart',
          );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath: 'lib/features/todo/data/models/todo_model.dart',
          codeName: 'model_conversion_methods',
          problemMessage:
              'Data model "TodoModel" should have toEntity() method in extension',
          correctionMessage:
              'Add extension with toEntity() method (e.g., extension TodoModelX on TodoModel { Entity toEntity() => entity; }).',
        ),
      ]);
    });

    test('skips non-Freezed model and model without Entity field', () async {
      final result = await V2RuleHarness(rule: ModelConversionMethodsRule())
          .analyze(
            files: {
              'lib/features/todo/data/models/plain_model.dart': '''
class Todo {}

class PlainModel {
  const PlainModel({required this.entity});

  final Todo entity;
}
''',
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
            definingFile: 'lib/features/todo/data/models/plain_model.dart',
            additionalDefiningFiles: [
              'lib/features/todo/data/models/todo_model.dart',
            ],
          );

      result.expectNoDiagnostics();
    });

    test('ignores generated files', () async {
      final result = await V2RuleHarness(rule: ModelConversionMethodsRule())
          .analyze(
            files: {
              'lib/features/todo/data/models/todo_model.g.dart': '''
const freezed = Object();

class Todo {}

@freezed
sealed class TodoModel {
  const factory TodoModel({
    required Todo entity,
  }) = TodoModelImpl;
}
''',
            },
            definingFile: 'lib/features/todo/data/models/todo_model.g.dart',
          );

      result.expectNoDiagnostics();
    });
  });
}
