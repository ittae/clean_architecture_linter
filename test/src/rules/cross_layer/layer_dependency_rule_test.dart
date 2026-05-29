import 'package:clean_architecture_linter/src/rules/cross_layer/layer_dependency_rule.dart';
import 'package:test/test.dart';

import '../../../v2_harness/analysis_rule_harness.dart';

void main() {
  group('LayerDependencyRule', () {
    test('reports presentation imports from data layer', () async {
      final result = await V2RuleHarness(rule: LayerDependencyRule()).analyze(
        files: {
          'lib/features/todo/presentation/pages/todo_page.dart': '''
import '../../data/repositories/todo_repository_impl.dart';

class TodoPage {}
''',
          'lib/features/todo/data/repositories/todo_repository_impl.dart': '''
class TodoRepositoryImpl {}
''',
        },
        definingFile: 'lib/features/todo/presentation/pages/todo_page.dart',
      );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath: 'lib/features/todo/presentation/pages/todo_page.dart',
          codeName: 'layer_dependency',
          line: 1,
        ),
      ]);
    });

    test('allows DI imports except data models', () async {
      final result = await V2RuleHarness(rule: LayerDependencyRule()).analyze(
        files: {
          'lib/features/todo/presentation/providers/todo_providers.dart': '''
import '../../data/datasources/todo_remote_data_source.dart';
import '../../data/models/todo_model.dart';

final providers = <Object>[];
''',
          'lib/features/todo/data/datasources/todo_remote_data_source.dart': '''
class TodoRemoteDataSource {}
''',
          'lib/features/todo/data/models/todo_model.dart': '''
class TodoModel {}
''',
        },
        definingFile:
            'lib/features/todo/presentation/providers/todo_providers.dart',
      );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath:
              'lib/features/todo/presentation/providers/todo_providers.dart',
          codeName: 'layer_dependency',
          line: 2,
        ),
      ]);
    });

    test('ignores cross-cutting dart imports', () async {
      final result = await V2RuleHarness(rule: LayerDependencyRule()).analyze(
        files: {
          'lib/features/todo/domain/entities/todo.dart': '''
import 'dart:async';

class Todo {}
''',
        },
        definingFile: 'lib/features/todo/domain/entities/todo.dart',
      );

      result.expectNoDiagnostics();
    });
  });
}
