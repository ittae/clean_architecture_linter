Feature: domain_purity
  The domain layer stays free of UI framework dependencies.

  Scenario: a domain entity that imports a UI framework is reported
    Given the file "lib/features/todo/domain/entities/todo.dart" contains:
      """
      import 'package:flutter/widgets.dart';

      class Todo {}
      """
    When the rule "domain_purity" analyzes "lib/features/todo/domain/entities/todo.dart"
    Then the only diagnostic is "domain_purity" at line 1 of "lib/features/todo/domain/entities/todo.dart"

  Scenario: a domain entity that only uses dart:io types stays clean
    Given the file "lib/features/todo/domain/entities/todo_file.dart" contains:
      """
      import 'dart:io';

      class TodoFile {
        final File file;
        const TodoFile(this.file);
      }
      """
    When the rule "domain_purity" analyzes "lib/features/todo/domain/entities/todo_file.dart"
    Then no diagnostic is reported
