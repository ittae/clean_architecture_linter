// Domain Entity - Pure business logic
import 'package:freezed_annotation/freezed_annotation.dart';

part 'todo.freezed.dart';

/// Todo entity with business logic
@freezed
sealed class Todo with _$Todo {
  const factory Todo({
    required String id,
    required String title,
    required bool isCompleted,
    DateTime? dueDate,
  }) = _Todo;

  const Todo._();

  /// Business logic: Check if todo is overdue
  bool get isOverdue {
    if (dueDate == null) return false;
    return !isCompleted && dueDate!.isBefore(DateTime.now());
  }

  /// Business logic: Toggle completion status
  Todo toggleCompletion() => copyWith(isCompleted: !isCompleted);
}
