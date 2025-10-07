// ✅ CORRECT: Model uses composition pattern with Freezed
// Following CLEAN_ARCHITECTURE_GUIDE.md

import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../domain/entities/todo.dart';

part 'todo_model_good.freezed.dart';
part 'todo_model_good.g.dart';

/// Data Model contains Entity + metadata only
@freezed
sealed class TodoModel with _$TodoModel {
  const factory TodoModel({
    required Todo entity, // ✅ Domain Entity composition
    String? etag, // ✅ Metadata only (not in Entity)
    DateTime? cachedAt, // ✅ Metadata only (not in Entity)
  }) = _TodoModel;

  factory TodoModel.fromJson(Map<String, dynamic> json) => _$TodoModelFromJson(json);
}

/// Conversion extensions in same file
extension TodoModelX on TodoModel {
  /// Convert Model to Entity
  Todo toEntity() => entity;

  /// Create Model from Entity
  static TodoModel fromEntity(Todo entity, {String? etag}) {
    return TodoModel(
      entity: entity,
      etag: etag,
      cachedAt: DateTime.now(),
    );
  }
}
