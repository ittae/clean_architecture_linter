// ❌ WRONG: Multiple violations of Model-Entity pattern
// This file demonstrates what NOT to do

import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../domain/entities/todo.dart';

part 'todo_model_bad.freezed.dart';

/// ❌ Violation 1: Missing @freezed annotation
class TodoModelNoFreezed {
  final Todo entity;
  final String? etag;

  TodoModelNoFreezed({required this.entity, this.etag});
}

/// ❌ Violation 2: Missing sealed modifier
@freezed
class TodoModelNoSealed {
  const factory TodoModelNoSealed({
    required Todo entity,
    String? etag,
  }) = _TodoModelNoSealed;
}

/// ❌ Violation 3: No Entity field (duplicates all fields)
@freezed
sealed class TodoModelNoEntity {
  const factory TodoModelNoEntity({
    required String id, // ❌ Duplicate from Todo entity
    required String title, // ❌ Duplicate from Todo entity
    required bool isCompleted, // ❌ Duplicate from Todo entity
    String? etag,
  }) = _TodoModelNoEntity;
}

/// ❌ Violation 4: Duplicate fields (has entity but also duplicates fields)
@freezed
sealed class TodoModelDuplicateFields {
  const factory TodoModelDuplicateFields({
    required Todo entity, // ✅ Has entity
    required String title, // ❌ Duplicate from entity.title
    required bool isCompleted, // ❌ Duplicate from entity.isCompleted
    String? etag,
  }) = _TodoModelDuplicateFields;
}

/// ❌ Violation 5: Uses inheritance instead of composition
class TodoModelInheritance extends Todo {
  final String? etag;

  TodoModelInheritance({
    required super.id,
    required super.title,
    required super.isCompleted,
    this.etag,
  });
}

/// ❌ Violation 6: Missing conversion methods
@freezed
sealed class TodoModelNoConversion with _$TodoModelNoConversion {
  const factory TodoModelNoConversion({
    required Todo entity,
    String? etag,
  }) = _TodoModelNoConversion;
}
// ❌ No toEntity() or fromEntity() extensions

/// ❌ Violation 7: Conversion methods in separate file
/// (Violates same-file extension rule)
/// See: bad_examples/data/models/extensions/todo_model_extensions.dart
