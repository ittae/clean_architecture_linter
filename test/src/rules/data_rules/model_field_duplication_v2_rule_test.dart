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

    test('detects custom entity types with primitive prefixes', () async {
      final result = await V2RuleHarness(rule: ModelFieldDuplicationRule())
          .analyze(
            files: {
              'lib/features/settings/data/models/settings_model.dart': '''
const freezed = Object();

class Settings {}

@freezed
sealed class SettingsModel {
  const factory SettingsModel({
    required Settings settings,
    required String title,
  }) = SettingsModelImpl;
}
''',
              'lib/features/interval/data/models/interval_model.dart': '''
const freezed = Object();

class Interval {}

@freezed
sealed class IntervalModel {
  const factory IntervalModel({
    required Interval interval,
    required int value,
  }) = IntervalModelImpl;
}
''',
              'lib/features/location/data/models/location_model.dart': '''
const freezed = Object();

class MapLocation {}

@freezed
sealed class LocationModel {
  const factory LocationModel({
    required MapLocation location,
    required String description,
  }) = LocationModelImpl;
}
''',
              'lib/features/boolean/data/models/boolean_model.dart': '''
const freezed = Object();

class Boolean {}

@freezed
sealed class BooleanModel {
  const factory BooleanModel({
    required Boolean boolean,
    required bool isActive,
  }) = BooleanModelImpl;
}
''',
            },
            definingFile:
                'lib/features/settings/data/models/settings_model.dart',
            additionalDefiningFiles: [
              'lib/features/interval/data/models/interval_model.dart',
              'lib/features/location/data/models/location_model.dart',
              'lib/features/boolean/data/models/boolean_model.dart',
            ],
          );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath: 'lib/features/settings/data/models/settings_model.dart',
          codeName: 'model_field_duplication',
          problemMessage:
              'Field "title" duplicates Entity field. Model should only contain Entity + metadata.',
          correctionMessage:
              'Remove "title" field. Access it via entity.title instead.',
        ),
        const ExpectedV2Diagnostic(
          relativePath: 'lib/features/interval/data/models/interval_model.dart',
          codeName: 'model_field_duplication',
          problemMessage:
              'Field "value" duplicates Entity field. Model should only contain Entity + metadata.',
          correctionMessage:
              'Remove "value" field. Access it via entity.value instead.',
        ),
        const ExpectedV2Diagnostic(
          relativePath: 'lib/features/location/data/models/location_model.dart',
          codeName: 'model_field_duplication',
          problemMessage:
              'Field "description" duplicates Entity field. Model should only contain Entity + metadata.',
          correctionMessage:
              'Remove "description" field. Access it via entity.description instead.',
        ),
        const ExpectedV2Diagnostic(
          relativePath: 'lib/features/boolean/data/models/boolean_model.dart',
          codeName: 'model_field_duplication',
          problemMessage:
              'Field "isActive" duplicates Entity field. Model should only contain Entity + metadata.',
          correctionMessage:
              'Remove "isActive" field. Access it via entity.isActive instead.',
        ),
      ]);
    });

    test(
      'does not treat SDK primitive and container types as entity fields',
      () async {
        final result = await V2RuleHarness(rule: ModelFieldDuplicationRule())
            .analyze(
              files: {
                'lib/features/metrics/data/models/metrics_model.dart': '''
import 'dart:async';

const freezed = Object();

@freezed
sealed class MetricsModel {
  const factory MetricsModel({
    required num amount,
    required Object value,
    required dynamic status,
    required (String, int) title,
    required ({String name, int count}) description,
    required Record startDate,
    required void Function() isCompleted,
    required String Function(int value) type,
    required FutureOr<String> content,
    required MapEntry<String, Object?> productId,
    required Symbol orderId,
    required Iterable<String> tags,
    required Map<String, Object?> metadata,
    required Set<String> flags,
    required List<String> names,
  }) = MetricsModelImpl;
}
''',
              },
              definingFile:
                  'lib/features/metrics/data/models/metrics_model.dart',
            );

        result.expectNoDiagnostics();
      },
    );

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
