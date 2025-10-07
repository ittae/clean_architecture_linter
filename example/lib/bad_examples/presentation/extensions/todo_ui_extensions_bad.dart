// ❌ WRONG: Separate extensions/ directory for UI extensions
// This violates Clean Architecture extension patterns

import '../../domain/entities/todo.dart';

/// ❌ Violation: presentation/extensions/ directory
///
/// This file is in a separate extensions/ directory, which is not allowed.
/// UI extensions should be defined in the State file where they're used.
///
/// For shared UI extensions across multiple widgets, define them in the
/// State file. For widget-specific extensions, define them as private
/// extensions in the widget file itself.

/// ❌ Wrong: Separate extension file
extension TodoUIExtensions on Todo {
  String get formattedDueDate {
    // UI formatting logic
    return 'Formatted date';
  }

  String get priorityLabel {
    return isCompleted ? 'Done' : 'Pending';
  }

  String get displayTitle {
    return title.toUpperCase();
  }
}

/// ❌ Wrong: Another extension in separate file
extension TodoColorExtension on Todo {
  int get priorityColor {
    return isCompleted ? 0xFF00FF00 : 0xFFFF0000;
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
///     @Default(false) bool isLoading,
///   }) = _TodoState;
/// }
///
/// // ✅ Shared UI extensions in State file
/// extension TodoUIX on Todo {
///   String get formattedDueDate => 'Formatted date';
///   String get priorityLabel => isCompleted ? 'Done' : 'Pending';
///   String get displayTitle => title.toUpperCase();
///   int get priorityColor => isCompleted ? 0xFF00FF00 : 0xFFFF0000;
/// }
/// ```
///
/// Or for widget-specific logic:
///
/// ```dart
/// // presentation/widgets/todo_card.dart
/// class TodoCard extends StatelessWidget {
///   // Widget implementation
/// }
///
/// // ✅ Private widget-specific extension
/// extension _TodoCardExtensions on Todo {
///   EdgeInsets get cardPadding => isCompleted
///     ? EdgeInsets.all(8.0)
///     : EdgeInsets.all(16.0);
/// }
/// ```
