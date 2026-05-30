import 'package:clean_architecture_linter/src/rules/data_rules/model_field_duplication_rule.dart';
import 'package:test/test.dart';

import '../../../v2_harness/analysis_rule_harness.dart';

void main() {
  group('ModelFieldDuplicationRule v2', () {
    test('reports duplicate domain fields with dynamic context', () async {
      final result = await V2RuleHarness(rule: ModelFieldDuplicationRule())
          .analyze(
            files: {
              'lib/features/todo/data/models/todo_model.dart': '''
const freezed = Object();

class Todo {}

@freezed
sealed class TodoModel {
  const factory TodoModel({
    required Todo entity,
    required String title,
    required bool isCompleted,
    String? etag,
  }) = TodoModelImpl;
}

class TodoModelImpl implements TodoModel {
  const TodoModelImpl({
    required this.entity,
    required this.title,
    required this.isCompleted,
    this.etag,
  });

  final Todo entity;
  final String title;
  final bool isCompleted;
  final String? etag;
}
''',
            },
            definingFile: 'lib/features/todo/data/models/todo_model.dart',
          );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath: 'lib/features/todo/data/models/todo_model.dart',
          codeName: 'model_field_duplication',
          line: 9,
          problemMessage:
              'Field "title" duplicates Entity field. Model should only contain Entity + metadata.',
          correctionMessage:
              'Remove "title" field. Access it via entity.title instead.',
        ),
        const ExpectedV2Diagnostic(
          relativePath: 'lib/features/todo/data/models/todo_model.dart',
          codeName: 'model_field_duplication',
          line: 10,
          problemMessage:
              'Field "isCompleted" duplicates Entity field. Model should only contain Entity + metadata.',
          correctionMessage:
              'Remove "isCompleted" field. Access it via entity.isCompleted instead.',
        ),
      ]);
    });

    test('allows metadata fields alongside Entity', () async {
      final result = await V2RuleHarness(rule: ModelFieldDuplicationRule())
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
    int? version,
    DateTime? cachedAt,
    bool isLocal,
  }) = TodoModelImpl;
}

class TodoModelImpl implements TodoModel {
  const TodoModelImpl({
    required this.entity,
    this.etag,
    this.version,
    this.cachedAt,
    required this.isLocal,
  });

  final Todo entity;
  final String? etag;
  final int? version;
  final DateTime? cachedAt;
  final bool isLocal;
}
''',
            },
            definingFile: 'lib/features/todo/data/models/todo_model.dart',
          );

      result.expectNoDiagnostics();
    });

    test('skips model without Freezed annotation', () async {
      final result = await V2RuleHarness(rule: ModelFieldDuplicationRule())
          .analyze(
            files: {
              'lib/features/todo/data/models/todo_model.dart': '''
class Todo {}

class TodoModel {
  const TodoModel({
    required this.entity,
    required this.title,
  });

  final Todo entity;
  final String title;
}
''',
            },
            definingFile: 'lib/features/todo/data/models/todo_model.dart',
          );

      result.expectNoDiagnostics();
    });

    test('skips model without Entity field', () async {
      final result = await V2RuleHarness(rule: ModelFieldDuplicationRule())
          .analyze(
            files: {
              'lib/features/todo/data/models/todo_model.dart': '''
const freezed = Object();

@freezed
sealed class TodoModel {
  const factory TodoModel({
    required String title,
  }) = TodoModelImpl;
}

class TodoModelImpl implements TodoModel {
  const TodoModelImpl({required this.title});

  final String title;
}
''',
            },
            definingFile: 'lib/features/todo/data/models/todo_model.dart',
          );

      result.expectNoDiagnostics();
    });

    test('ignores generated files', () async {
      final result = await V2RuleHarness(rule: ModelFieldDuplicationRule())
          .analyze(
            files: {
              'lib/features/todo/data/models/todo_model.g.dart': '''
const freezed = Object();

class Todo {}

@freezed
sealed class TodoModel {
  const factory TodoModel({
    required Todo entity,
    required String title,
  }) = TodoModelImpl;
}
''',
            },
            definingFile: 'lib/features/todo/data/models/todo_model.g.dart',
          );

      result.expectNoDiagnostics();
    });

    test('ignores non-data-model paths and non-Model classes', () async {
      final result = await V2RuleHarness(rule: ModelFieldDuplicationRule())
          .analyze(
            files: {
              'lib/features/todo/domain/entities/todo.dart': '''
const freezed = Object();

@freezed
class TodoModel {
  const factory TodoModel({
    required Todo entity,
    required String title,
  }) = TodoModelImpl;
}

class Todo {}
class TodoModelImpl implements TodoModel {}
''',
              'lib/features/todo/data/models/todo_dto.dart': '''
const freezed = Object();

@freezed
class TodoDto {
  const factory TodoDto({
    required Todo entity,
    required String title,
  }) = TodoDtoImpl;
}

class Todo {}
class TodoDtoImpl implements TodoDto {}
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
