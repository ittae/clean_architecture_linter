// ❌ WRONG: Separate extensions/ directory for model conversion extensions
// This violates Clean Architecture extension patterns

import '../../domain/entities/todo.dart';
import '../models/todo_model_bad.dart';

/// ❌ Violation: data/extensions/ directory
///
/// This file is in a separate extensions/ directory, which is not allowed.
/// Model conversion extensions should be defined in the same file as the model.

/// ❌ Wrong: Separate extension file for conversion methods
extension TodoModelConversionExtensions on TodoModelComplete {
  Todo toEntity() {
    return entity;
  }
}

/// ❌ Wrong: Separate static extension
extension TodoModelStaticExtensions on TodoModelComplete {
  static TodoModelComplete fromEntity(Todo entity, {String? etag}) {
    return TodoModelComplete(
      entity: entity,
      etag: etag,
    );
  }
}

/// ✅ CORRECT: Define extensions in Model file
///
/// Location: data/models/todo_model.dart
///
/// ```dart
/// @freezed
/// sealed class TodoModel with _$TodoModel {
///   const factory TodoModel({
///     required Todo entity,
///     String? etag,
///   }) = _TodoModel;
/// }
///
/// // ✅ Conversion extensions in same file as Model
/// extension TodoModelX on TodoModel {
///   Todo toEntity() => entity;
/// }
///
/// extension TodoModelStaticX on TodoModel {
///   static TodoModel fromEntity(Todo entity, {String? etag}) {
///     return TodoModel(entity: entity, etag: etag);
///   }
/// }
/// ```
