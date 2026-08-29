class Todo {}

class Failure {}

class Result<T, E> {}

abstract class TodoRepository {}

/// Triggers `repository_pass_through` (data slice contract).
class TodoRepositoryImpl implements TodoRepository {
  Future<Result<Todo, Failure>> getTodo() async => Result<Todo, Failure>();
}
