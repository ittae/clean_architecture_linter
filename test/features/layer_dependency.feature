Feature: layer_dependency
  Presentation code reaches the data layer only through the domain layer.

  Scenario: a presentation page that imports a data repository is reported
    Given the file "lib/features/todo/data/repositories/todo_repository_impl.dart" contains:
      """
      class TodoRepositoryImpl {}
      """
    And the file "lib/features/todo/presentation/pages/todo_page.dart" contains:
      """
      import '../../data/repositories/todo_repository_impl.dart';

      class TodoPage {}
      """
    When the rule "layer_dependency" analyzes "lib/features/todo/presentation/pages/todo_page.dart"
    Then the only diagnostic is "layer_dependency" at line 1 of "lib/features/todo/presentation/pages/todo_page.dart"

  Scenario: a presentation page that imports a domain entity stays clean
    Given the file "lib/features/todo/domain/entities/todo.dart" contains:
      """
      class Todo {}
      """
    And the file "lib/features/todo/presentation/pages/todo_page.dart" contains:
      """
      import '../../domain/entities/todo.dart';

      class TodoPage {}
      """
    When the rule "layer_dependency" analyzes "lib/features/todo/presentation/pages/todo_page.dart"
    Then no diagnostic is reported
