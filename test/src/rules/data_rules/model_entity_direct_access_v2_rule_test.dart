import 'package:clean_architecture_linter/src/rules/data_rules/model_entity_direct_access_rule.dart';
import 'package:test/test.dart';

import '../../../v2_harness/analysis_rule_harness.dart';

void main() {
  group('ModelEntityDirectAccessRule v2', () {
    test('reports direct entity access in data repository', () async {
      final result = await V2RuleHarness(rule: ModelEntityDirectAccessRule())
          .analyze(
            files: {
              'lib/features/todo/data/repositories/todo_repository_impl.dart':
                  '''
class TodoModel {
  Todo get entity => Todo();
}

class Todo {}

class TodoRepositoryImpl {
  Todo convert(TodoModel model) {
    return model.entity;
  }
}
''',
            },
            definingFile:
                'lib/features/todo/data/repositories/todo_repository_impl.dart',
          );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath:
              'lib/features/todo/data/repositories/todo_repository_impl.dart',
          codeName: 'model_entity_direct_access',
          line: 9,
          problemMessage:
              'Direct access to "model.entity" is not allowed in Data layer. Use the toEntity() extension method instead.',
          correctionMessage:
              'Replace ".entity" with ".toEntity()" to maintain clear conversion boundaries. Example: model.toEntity() instead of model.entity',
        ),
      ]);
    });

    test('reports direct entity access in property chain', () async {
      final result = await V2RuleHarness(rule: ModelEntityDirectAccessRule())
          .analyze(
            files: {
              'lib/features/todo/data/datasources/todo_remote_datasource.dart':
                  '''
class Wrapper {
  TodoModel get model => TodoModel();
}

class TodoModel {
  Todo get entity => Todo();
}

class Todo {}

class TodoRemoteDataSource {
  Todo convert(Wrapper wrapper) {
    return wrapper.model.entity;
  }
}
''',
            },
            definingFile:
                'lib/features/todo/data/datasources/todo_remote_datasource.dart',
          );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath:
              'lib/features/todo/data/datasources/todo_remote_datasource.dart',
          codeName: 'model_entity_direct_access',
          problemMessage:
              'Direct access to "wrapper.model.entity" is not allowed in Data layer. Use the toEntity() extension method instead.',
          correctionMessage:
              'Replace ".entity" with ".toEntity()" to maintain clear conversion boundaries. Example: model.toEntity() instead of model.entity',
        ),
      ]);
    });

    test('allows entity access inside extension conversion methods', () async {
      final result = await V2RuleHarness(rule: ModelEntityDirectAccessRule())
          .analyze(
            files: {
              'lib/features/todo/data/models/todo_model.dart': '''
class TodoModel {
  Todo get entity => Todo();
}

class Todo {}

extension TodoModelX on TodoModel {
  Todo toEntity() => entity;
}
''',
            },
            definingFile: 'lib/features/todo/data/models/todo_model.dart',
          );

      result.expectNoDiagnostics();
    });

    test('allows toEntity method calls and non-entity properties', () async {
      final result = await V2RuleHarness(rule: ModelEntityDirectAccessRule())
          .analyze(
            files: {
              'lib/features/todo/data/repositories/todo_repository_impl.dart':
                  '''
class TodoModel {
  String get id => 'id';
  Todo toEntity() => Todo();
}

class Todo {}

class TodoRepositoryImpl {
  Object convert(TodoModel model) {
    return [model.toEntity(), model.id];
  }
}
''',
            },
            definingFile:
                'lib/features/todo/data/repositories/todo_repository_impl.dart',
          );

      result.expectNoDiagnostics();
    });

    test('ignores generated files', () async {
      final result = await V2RuleHarness(rule: ModelEntityDirectAccessRule())
          .analyze(
            files: {
              'lib/features/todo/data/models/todo_model.g.dart': '''
class TodoModel {
  Todo get entity => Todo();
}

class Todo {}

Todo convert(TodoModel model) => model.entity;
''',
            },
            definingFile: 'lib/features/todo/data/models/todo_model.g.dart',
          );

      result.expectNoDiagnostics();
    });

    test('ignores non-data layer files', () async {
      final result = await V2RuleHarness(rule: ModelEntityDirectAccessRule())
          .analyze(
            files: {
              'lib/features/todo/domain/usecases/get_todo_usecase.dart': '''
class TodoModel {
  Todo get entity => Todo();
}

class Todo {}

Todo convert(TodoModel model) => model.entity;
''',
            },
            definingFile:
                'lib/features/todo/domain/usecases/get_todo_usecase.dart',
          );

      result.expectNoDiagnostics();
    });
  });
}
