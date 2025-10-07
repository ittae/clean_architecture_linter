// ❌ WRONG: Presentation layer importing Data layer Model
// This violates Clean Architecture dependency rules

import 'package:flutter/material.dart';
import '../../data/models/todo_model_bad.dart'; // ❌ Presentation → Data (WRONG!)
import '../../../domain/entities/todo.dart';

/// ❌ Violation: Presentation layer should NEVER import from Data layer
///
/// This widget incorrectly imports TodoModel from data layer.
/// Presentation should only use Domain Entities.
class TodoWidgetBad extends StatelessWidget {
  // ❌ Using Data layer Model in Presentation
  final TodoModelNoConversion todoModel;

  const TodoWidgetBad({
    super.key,
    required this.todoModel,
  });

  @override
  Widget build(BuildContext context) {
    // ❌ Accessing Model directly instead of using Entity
    final entity = todoModel.entity;

    return ListTile(
      title: Text(entity.title),
      subtitle: Text(entity.id),
      trailing: entity.isCompleted
          ? const Icon(Icons.check_circle)
          : const Icon(Icons.circle_outlined),
    );
  }
}

/// ✅ CORRECT: Use Domain Entity instead
class TodoWidgetGood extends StatelessWidget {
  // ✅ Using Domain Entity in Presentation
  final Todo todo;

  const TodoWidgetGood({
    super.key,
    required this.todo,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(todo.title),
      subtitle: Text(todo.id),
      trailing: todo.isCompleted
          ? const Icon(Icons.check_circle)
          : const Icon(Icons.circle_outlined),
    );
  }
}
