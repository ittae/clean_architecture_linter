// ❌ WRONG: Entity extension in widget file
// This violates Clean Architecture extension patterns

import 'package:flutter/material.dart';
import '../../../domain/entities/todo.dart';

/// ❌ Violation: Extension on Domain Entity in Widget file
///
/// Entity UI extensions should ONLY be in State files, NOT in widget files.
/// Widget files should use State and its extensions, not define their own.

class TodoWidgetWithExtension extends StatelessWidget {
  final Todo todo;

  const TodoWidgetWithExtension({
    super.key,
    required this.todo,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(todo.title),
      subtitle: Text(todo.formattedDueDate), // ❌ Using widget-level extension
      trailing: Icon(
        todo.statusIcon, // ❌ Using widget-level extension
        color: todo.statusColor, // ❌ Using widget-level extension
      ),
    );
  }
}

/// ❌ Wrong: Extension on Domain Entity in Widget file
extension TodoWidgetExtensions on Todo {
  String get formattedDueDate {
    if (dueDate == null) return 'No due date';
    return 'Due: ${dueDate.toString()}';
  }

  IconData get statusIcon {
    return isCompleted ? Icons.check_circle : Icons.circle_outlined;
  }

  Color get statusColor {
    return isCompleted ? Colors.green : Colors.grey;
  }
}

/// ✅ CORRECT: Define extensions in State file
///
/// Location: presentation/states/todo_state.dart
///
/// ```dart
/// @freezed
/// class TodoState with _$TodoState {
///   const factory TodoState({
///     @Default([]) List<Todo> todos,
///   }) = _TodoState;
/// }
///
/// // ✅ Entity UI extensions in State file (shared across widgets)
/// extension TodoUIX on Todo {
///   String get formattedDueDate {
///     if (dueDate == null) return 'No due date';
///     return 'Due: ${dueDate.toString()}';
///   }
///
///   IconData get statusIcon {
///     return isCompleted ? Icons.check_circle : Icons.circle_outlined;
///   }
///
///   Color get statusColor {
///     return isCompleted ? Colors.green : Colors.grey;
///   }
/// }
/// ```
///
/// Then in widget:
/// ```dart
/// class TodoWidget extends StatelessWidget {
///   final Todo todo;
///
///   @override
///   Widget build(BuildContext context) {
///     return ListTile(
///       title: Text(todo.title),
///       subtitle: Text(todo.formattedDueDate), // ✅ Uses State file extension
///       trailing: Icon(
///         todo.statusIcon, // ✅ Uses State file extension
///         color: todo.statusColor, // ✅ Uses State file extension
///       ),
///     );
///   }
/// }
/// ```
