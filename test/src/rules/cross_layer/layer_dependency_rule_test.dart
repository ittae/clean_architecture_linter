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
          problemMessage:
              'Layer dependency violation: Presentation layer should not directly depend on Data layer. Found import: ../../data/repositories/todo_repository_impl.dart',
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
          problemMessage:
              'Layer dependency violation: Data Models should not be imported even in DI/Provider files. Found import: ../../data/models/todo_model.dart',
        ),
      ]);
    });

    test('skips generated files', () async {
      final result = await V2RuleHarness(rule: LayerDependencyRule()).analyze(
        files: {
          'lib/features/todo/domain/entities/todo.freezed.dart': '''
import '../../data/models/todo_model.dart';

class Todo {}
''',
          'lib/features/todo/data/models/todo_model.dart': '''
class TodoModel {}
''',
        },
        definingFile: 'lib/features/todo/domain/entities/todo.freezed.dart',
      );

      result.expectNoDiagnostics();
    });

    test(
      'reports layer violations when the file name only contains main.dart',
      () async {
        final result = await V2RuleHarness(rule: LayerDependencyRule()).analyze(
          files: {
            'lib/features/todo/presentation/pages/remain.dart': '''
import '../../data/repositories/todo_repository_impl.dart';

class RemainPage {}
''',
            'lib/features/todo/presentation/pages/domain_main.dart': '''
import '../../data/repositories/todo_repository_impl.dart';

class DomainMainPage {}
''',
            'lib/features/todo/data/repositories/todo_repository_impl.dart': '''
class TodoRepositoryImpl {}
''',
          },
          definingFile: 'lib/features/todo/presentation/pages/remain.dart',
          additionalDefiningFiles: [
            'lib/features/todo/presentation/pages/domain_main.dart',
          ],
        );

        result.expectDiagnostics([
          const ExpectedV2Diagnostic(
            relativePath: 'lib/features/todo/presentation/pages/remain.dart',
            codeName: 'layer_dependency',
            line: 1,
            problemMessage:
                'Layer dependency violation: Presentation layer should not directly depend on Data layer. Found import: ../../data/repositories/todo_repository_impl.dart',
          ),
          const ExpectedV2Diagnostic(
            relativePath:
                'lib/features/todo/presentation/pages/domain_main.dart',
            codeName: 'layer_dependency',
            line: 1,
            problemMessage:
                'Layer dependency violation: Presentation layer should not directly depend on Data layer. Found import: ../../data/repositories/todo_repository_impl.dart',
          ),
        ]);
      },
    );

    test('still treats lib/main.dart as a DI entrypoint', () async {
      final allowed = await V2RuleHarness(rule: LayerDependencyRule()).analyze(
        files: {
          'lib/main.dart': '''
import 'features/todo/data/repositories/todo_repository_impl.dart';

void main() {}
''',
          'lib/features/todo/data/repositories/todo_repository_impl.dart': '''
class TodoRepositoryImpl {}
''',
        },
        definingFile: 'lib/main.dart',
      );

      allowed.expectNoDiagnostics();

      final modelImport = await V2RuleHarness(rule: LayerDependencyRule())
          .analyze(
            files: {
              'lib/main.dart': '''
import 'features/todo/data/models/todo_model.dart';

void main() {}
''',
              'lib/features/todo/data/models/todo_model.dart': '''
class TodoModel {}
''',
            },
            definingFile: 'lib/main.dart',
          );

      modelImport.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath: 'lib/main.dart',
          codeName: 'layer_dependency',
          line: 1,
          problemMessage:
              'Layer dependency violation: Data Models should not be imported even in DI/Provider files. Found import: features/todo/data/models/todo_model.dart',
        ),
      ]);
    });

    test('reports domain imports of data, presentation, and http', () async {
      const domain = 'lib/features/todo/domain/entities/todo.dart';
      final result = await V2RuleHarness(rule: LayerDependencyRule()).analyze(
        files: {
          domain: '''
import '../../data/repositories/todo_repository.dart';
import '../../presentation/pages/todo_page.dart';
import 'package:http/http.dart';

class Todo {}
''',
          'lib/features/todo/data/repositories/todo_repository.dart':
              'class TodoRepository {}',
          'lib/features/todo/presentation/pages/todo_page.dart':
              'class TodoPage {}',
        },
        definingFile: domain,
      );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath: domain,
          codeName: 'layer_dependency',
          line: 1,
          problemMessage:
              'Layer dependency violation: Domain layer cannot depend on Data layer. Found import: ../../data/repositories/todo_repository.dart',
        ),
        const ExpectedV2Diagnostic(
          relativePath: domain,
          codeName: 'layer_dependency',
          line: 2,
          problemMessage:
              'Layer dependency violation: Domain layer cannot depend on Presentation layer. Found import: ../../presentation/pages/todo_page.dart',
        ),
        const ExpectedV2Diagnostic(
          relativePath: domain,
          codeName: 'layer_dependency',
          line: 3,
          problemMessage:
              'Layer dependency violation: Domain layer cannot depend on Infrastructure. Found import: package:http/http.dart',
        ),
      ]);
    });

    test(
      'reports a use case data import as an application-layer violation',
      () async {
        const usecase = 'lib/features/todo/domain/usecases/get_todo.dart';
        final result = await V2RuleHarness(rule: LayerDependencyRule()).analyze(
          files: {
            usecase: '''
import '../../data/repositories/todo_repository.dart';
import '../../presentation/pages/todo_page.dart';
import 'package:http/http.dart';

class GetTodo {}
''',
            'lib/features/todo/data/repositories/todo_repository.dart':
                'class TodoRepository {}',
            'lib/features/todo/presentation/pages/todo_page.dart':
                'class TodoPage {}',
          },
          definingFile: usecase,
        );

        result.expectDiagnostics([
          const ExpectedV2Diagnostic(
            relativePath: usecase,
            codeName: 'layer_dependency',
            line: 1,
            problemMessage:
                'Layer dependency violation: Application layer cannot depend on outer layers. Found import: ../../data/repositories/todo_repository.dart',
          ),
          const ExpectedV2Diagnostic(
            relativePath: usecase,
            codeName: 'layer_dependency',
            line: 2,
            problemMessage:
                'Layer dependency violation: Application layer cannot depend on outer layers. Found import: ../../presentation/pages/todo_page.dart',
          ),
          const ExpectedV2Diagnostic(
            relativePath: usecase,
            codeName: 'layer_dependency',
            line: 3,
            problemMessage:
                'Layer dependency violation: Application layer cannot depend on outer layers. Found import: package:http/http.dart',
          ),
        ]);
      },
    );

    test('reports data imports of presentation and path infrastructure', () async {
      const data = 'lib/features/todo/data/datasources/todo_remote.dart';
      final result = await V2RuleHarness(rule: LayerDependencyRule()).analyze(
        files: {
          data: '''
import '../../presentation/pages/todo_page.dart';
import '../../infrastructure/legacy_api.dart';

class TodoRemote {}
''',
          'lib/features/todo/presentation/pages/todo_page.dart':
              'class TodoPage {}',
          'lib/features/todo/infrastructure/legacy_api.dart':
              'class LegacyApi {}',
        },
        definingFile: data,
      );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath: data,
          codeName: 'layer_dependency',
          line: 1,
          problemMessage:
              'Layer dependency violation: Data layer cannot depend on Presentation layer. Found import: ../../presentation/pages/todo_page.dart',
        ),
        const ExpectedV2Diagnostic(
          relativePath: data,
          codeName: 'layer_dependency',
          line: 2,
          problemMessage:
              'Layer dependency violation: Data layer has suspicious Infrastructure dependency: ../../infrastructure/legacy_api.dart',
        ),
      ]);
    });

    test(
      'allows package:http in data and reports it from presentation',
      () async {
        const data = 'lib/features/todo/data/datasources/todo_remote.dart';
        final allowed = await V2RuleHarness(rule: LayerDependencyRule())
            .analyze(
              files: {
                data: '''
import 'package:http/http.dart';

class TodoRemote {}
''',
              },
              definingFile: data,
            );
        allowed.expectNoDiagnostics();

        const page = 'lib/features/todo/presentation/pages/todo_page.dart';
        final denied = await V2RuleHarness(rule: LayerDependencyRule()).analyze(
          files: {
            page: '''
import 'package:http/http.dart';

class TodoPage {}
''',
          },
          definingFile: page,
        );
        denied.expectDiagnostics([
          const ExpectedV2Diagnostic(
            relativePath: page,
            codeName: 'layer_dependency',
            line: 1,
            problemMessage:
                'Layer dependency violation: Presentation layer has improper Infrastructure dependency: package:http/http.dart',
          ),
        ]);
      },
    );

    test('reports infrastructure imports of presentation', () async {
      const infra = 'lib/features/todo/infrastructure/api.dart';
      final result = await V2RuleHarness(rule: LayerDependencyRule()).analyze(
        files: {
          infra: '''
import '../presentation/pages/todo_page.dart';

class Api {}
''',
          'lib/features/todo/presentation/pages/todo_page.dart':
              'class TodoPage {}',
        },
        definingFile: infra,
      );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath: infra,
          codeName: 'layer_dependency',
          line: 1,
          problemMessage:
              'Layer dependency violation: Infrastructure cannot depend on Presentation layer. Found import: ../presentation/pages/todo_page.dart',
        ),
      ]);
    });

    test(
      'reports data models nested off the data/models path in DI files',
      () async {
        const providers =
            'lib/features/todo/presentation/providers/todo_providers.dart';
        final result = await V2RuleHarness(rule: LayerDependencyRule()).analyze(
          files: {
            providers: '''
import '../../data/mappers/models/todo_model.dart';

final providers = <Object>[];
''',
            'lib/features/todo/data/mappers/models/todo_model.dart':
                'class TodoModel {}',
          },
          definingFile: providers,
        );

        result.expectDiagnostics([
          const ExpectedV2Diagnostic(
            relativePath: providers,
            codeName: 'layer_dependency',
            line: 1,
            problemMessage:
                'Layer dependency violation: Data Models should not be imported even in DI/Provider files. Found import: ../../data/mappers/models/todo_model.dart',
          ),
        ]);
      },
    );

    test('reports a data model re-exported through a DI barrel', () async {
      const providers =
          'lib/features/todo/presentation/providers/todo_providers.dart';
      final result = await V2RuleHarness(rule: LayerDependencyRule()).analyze(
        files: {
          providers: '''
import '../../todo.dart';
import 'package:meta/meta.dart';

final providers = <Object>[];
''',
          'lib/features/todo/todo.dart': '''
export 'data/models/todo_model.dart';
''',
          'lib/features/todo/data/models/todo_model.dart': 'class TodoModel {}',
        },
        definingFile: providers,
      );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath: providers,
          codeName: 'layer_dependency',
          line: 1,
          problemMessage:
              'Layer dependency violation: Data Models should not be imported even in DI/Provider files. Found import: ../../todo.dart',
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

    test('reports exports, conditional imports, and combinators', () async {
      const page = 'lib/features/todo/presentation/pages/todo_page.dart';
      final result = await V2RuleHarness(rule: LayerDependencyRule()).analyze(
        files: {
          page: '''
export '../../data/models/todo_model.dart' show TodoModel;
import '../domain/entities/todo.dart'
    if (dart.library.io) '../../data/models/todo_model.dart';
import '../../data/models/todo_model.dart' hide TodoModel;
import '../../data/models/todo_model.dart' as models;
import '../../data/models/todo_model.dart' deferred as lazyModels;

class TodoPage {}
''',
          'lib/features/todo/domain/entities/todo.dart': 'class Todo {}',
          'lib/features/todo/data/models/todo_model.dart': '''
class TodoModel<T> {}
''',
        },
        definingFile: page,
      );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath: page,
          codeName: 'layer_dependency',
          line: 1,
          problemMessage:
              'Layer dependency violation: Presentation layer should not directly depend on Data layer. Found export: ../../data/models/todo_model.dart',
        ),
        const ExpectedV2Diagnostic(
          relativePath: page,
          codeName: 'layer_dependency',
          line: 2,
          problemMessage:
              'Layer dependency violation: Presentation layer should not directly depend on Data layer. Found import: ../../data/models/todo_model.dart',
        ),
        const ExpectedV2Diagnostic(
          relativePath: page,
          codeName: 'layer_dependency',
          line: 4,
          problemMessage:
              'Layer dependency violation: Presentation layer should not directly depend on Data layer. Found import: ../../data/models/todo_model.dart',
        ),
        const ExpectedV2Diagnostic(
          relativePath: page,
          codeName: 'layer_dependency',
          line: 5,
          problemMessage:
              'Layer dependency violation: Presentation layer should not directly depend on Data layer. Found import: ../../data/models/todo_model.dart',
        ),
        const ExpectedV2Diagnostic(
          relativePath: page,
          codeName: 'layer_dependency',
          line: 6,
          problemMessage:
              'Layer dependency violation: Presentation layer should not directly depend on Data layer. Found import: ../../data/models/todo_model.dart',
        ),
      ]);
    });

    test('resolves package URIs and slash-less relative data imports', () async {
      const packaged = 'lib/features/todo/presentation/pages/packaged.dart';
      const relative = 'lib/features/todo/presentation/relative_page.dart';
      final result = await V2RuleHarness(rule: LayerDependencyRule()).analyze(
        files: {
          packaged: '''
import 'package:cal_v2_harness_app/features/todo/data/models/todo_model.dart';

class PackagedPage {}
''',
          relative: '''
import 'data/todo_model.dart';

class RelativePage {}
''',
          'lib/features/todo/presentation/data/todo_model.dart':
              'class TodoModel {}',
          'lib/features/todo/data/models/todo_model.dart': 'class TodoModel {}',
        },
        definingFile: packaged,
        additionalDefiningFiles: const [relative],
      );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath: packaged,
          codeName: 'layer_dependency',
          problemMessage:
              'Layer dependency violation: Presentation layer should not directly depend on Data layer. Found import: package:cal_v2_harness_app/features/todo/data/models/todo_model.dart',
        ),
        const ExpectedV2Diagnostic(
          relativePath: relative,
          codeName: 'layer_dependency',
          problemMessage:
              'Layer dependency violation: Presentation layer should not directly depend on Data layer. Found import: data/todo_model.dart',
        ),
      ]);
    });

    test(
      'reports a barrel that exports data and ignores a domain barrel',
      () async {
        const page = 'lib/features/todo/presentation/pages/todo_page.dart';
        const clean = 'lib/features/todo/presentation/pages/clean_page.dart';
        final result = await V2RuleHarness(rule: LayerDependencyRule()).analyze(
          files: {
            page: '''
import '../../todo_api.dart';

class TodoPage {}
''',
            clean: '''
import '../../domain_api.dart';

class CleanPage {}
''',
            'lib/features/todo/todo_api.dart': '''
export 'data/models/todo_model.dart' hide TodoModel;
export 'domain/entities/todo.dart';
''',
            'lib/features/todo/domain_api.dart': '''
export 'domain/entities/todo.dart' show Todo;
''',
            'lib/features/todo/data/models/todo_model.dart':
                'class TodoModel {}',
            'lib/features/todo/domain/entities/todo.dart': 'class Todo {}',
          },
          definingFile: page,
          additionalDefiningFiles: const [clean],
        );

        result.expectDiagnostics([
          const ExpectedV2Diagnostic(
            relativePath: page,
            codeName: 'layer_dependency',
            problemMessage:
                'Layer dependency violation: Presentation layer should not directly depend on Data layer. Found import: ../../todo_api.dart',
          ),
        ]);
      },
    );

    test(
      'a prefix named data does not make a domain import into data',
      () async {
        final result = await V2RuleHarness(rule: LayerDependencyRule()).analyze(
          files: {
            'lib/features/todo/presentation/pages/todo_page.dart': '''
import 'package:cal_v2_harness_app/features/todo/domain/entities/todo.dart' as data;

class TodoPage {}
''',
            'lib/features/todo/domain/entities/todo.dart': 'class Todo {}',
          },
          definingFile: 'lib/features/todo/presentation/pages/todo_page.dart',
        );

        result.expectNoDiagnostics();
      },
    );

    test(
      'ancestor folders named data or ui do not hide presentation imports',
      () async {
        const page = 'lib/features/todo/presentation/pages/todo_page.dart';
        final result = await V2RuleHarness(rule: LayerDependencyRule()).analyze(
          nestUnder: 'data/ui/pages',
          files: {
            page: '''
import '../../data/repositories/todo_repository_impl.dart';

class TodoPage {}
''',
            'lib/features/todo/data/repositories/todo_repository_impl.dart':
                'class TodoRepositoryImpl {}',
          },
          definingFile: page,
        );

        result.expectDiagnostics([
          const ExpectedV2Diagnostic(
            relativePath: page,
            codeName: 'layer_dependency',
            problemMessage:
                'Layer dependency violation: Presentation layer should not directly depend on Data layer. Found import: ../../data/repositories/todo_repository_impl.dart',
          ),
        ]);
      },
    );

    test(
      'a cancelled data segment does not classify a presentation file as data',
      () async {
        const widget = 'lib/features/todo/presentation/widgets/a.dart';
        final result = await V2RuleHarness(rule: LayerDependencyRule()).analyze(
          files: {
            widget: '''
import '../data/../pages/other.dart';

class A {}
''',
            'lib/features/todo/presentation/pages/other.dart': 'class Other {}',
          },
          definingFile: widget,
        );

        result.expectNoDiagnostics();
      },
    );
  });
}
