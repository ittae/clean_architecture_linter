// ❌ WRONG: Domain layer importing Data layer Model
// This violates Clean Architecture dependency rules

import '../../data/models/todo_model_bad.dart'; // ❌ Domain → Data (WRONG!)
import '../../../domain/entities/todo.dart';

/// ❌ Violation: Domain layer should NEVER import from Data layer
///
/// This UseCase incorrectly imports TodoModel from data layer.
/// Domain layer must remain pure and only use Entities.
class GetTodoUseCaseBad {
  // ❌ Using Data layer Model in Domain
  Future<TodoModelNoConversion> execute(String id) async {
    // This is wrong - Domain should only work with Entities
    throw UnimplementedError();
  }
}

/// ✅ CORRECT: Use Domain Entity instead
class GetTodoUseCaseGood {
  // ✅ Using Domain Entity in UseCase
  Future<Todo> execute(String id) async {
    // Domain layer works only with Entities
    throw UnimplementedError();
  }
}
