/// ❌ Triggers `repository_pass_through`.
///
/// Repository implementations must return `Future<Entity>` directly and let
/// errors pass through to `AsyncValue.guard()`. Returning a Result/Either
/// wrapper here duplicates the error channel.
///
/// Fix: see ../../../../../good_examples/features/todo/data/repositories/todo_repository_impl.dart
class TodoFailure {
  const TodoFailure(this.message);

  final String message;
}

class Result<T, E> {
  const Result();
}

class Todo {
  const Todo({required this.id});

  final String id;
}

class BadTodoRepositoryImplementation {
  Future<Result<Todo, TodoFailure>> getTodo(String id) async {
    return const Result<Todo, TodoFailure>();
  }
}
