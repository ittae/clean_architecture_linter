Feature: repository_pass_through
  A repository implementation returns Future<Entity> and lets errors pass through.

  Scenario: a repository method that returns a bare entity is reported
    Given the file "lib/features/todo/data/repositories/todo_repository_impl.dart" contains:
      """
      class Todo {}
      abstract class TodoRepository {}

      class TodoRepositoryImpl implements TodoRepository {
        Todo getTodo() => Todo();
      }
      """
    When the rule "repository_pass_through" analyzes "lib/features/todo/data/repositories/todo_repository_impl.dart"
    Then the only diagnostic is "repository_pass_through" at line 5 of "lib/features/todo/data/repositories/todo_repository_impl.dart"

  Scenario: a repository method that returns Future<Entity> stays clean
    Given the file "lib/features/todo/data/repositories/todo_repository_impl.dart" contains:
      """
      class Todo {}
      abstract class TodoRepository {}

      class TodoRepositoryImpl implements TodoRepository {
        Future<Todo> getTodo() async => Todo();
      }
      """
    When the rule "repository_pass_through" analyzes "lib/features/todo/data/repositories/todo_repository_impl.dart"
    Then no diagnostic is reported
