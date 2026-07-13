import '../entities/todo.dart';
import '../repositories/todo_repository.dart';

/// UseCase pass-through: no try/catch, no Result unwrapping.
/// Errors thrown by the Repository propagate to the caller unchanged.
class GetTodoUseCase {
  const GetTodoUseCase(this._repository);

  final TodoRepository _repository;

  Future<Todo> call(String id) => _repository.getTodo(id);
}
