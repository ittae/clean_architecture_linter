class Widget {}

class TodoWidget extends Widget {}

class Todo {}

class Failure {}

class Result<T, E> {}

class TodoRepositoryImpl {}

class GetTodoUseCase {
  final TodoRepositoryImpl repository;

  GetTodoUseCase(this.repository);

  Result<Todo, Failure> call() => Result<Todo, Failure>();
}

class TodoRepository {
  Future<UserModel> getTodo() async => UserModel();
}

class UserModel {}

class DataException implements Exception {}
