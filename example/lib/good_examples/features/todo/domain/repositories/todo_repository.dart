import '../entities/todo.dart';

/// Repository interface (Domain layer). Returns the entity directly —
/// no Result/Either wrapper, no Model type in the signature.
abstract class TodoRepository {
  Future<Todo> getTodo(String id);
}
