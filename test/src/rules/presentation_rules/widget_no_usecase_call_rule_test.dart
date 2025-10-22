import 'package:test/test.dart';

import '../../../../lib/src/rules/presentation_rules/widget_no_usecase_call_rule.dart';

void main() {
  group('WidgetNoUseCaseCallRule', () {
    late WidgetNoUseCaseCallRule rule;

    setUp(() {
      rule = const WidgetNoUseCaseCallRule();
    });

    group('File Path Detection', () {
      test('detects Widget file in /pages/ directory', () {
        final path =
            '/project/lib/features/todo/presentation/pages/todo_page.dart';
        expect(rule.isWidgetOrPageFile(path), isTrue);
      });

      test('detects Widget file in /widgets/ directory', () {
        final path =
            '/project/lib/features/todo/presentation/widgets/todo_widget.dart';
        expect(rule.isWidgetOrPageFile(path), isTrue);
      });

      test('detects file ending with _page.dart', () {
        final path =
            '/project/lib/features/todo/presentation/views/todo_page.dart';
        expect(rule.isWidgetOrPageFile(path), isTrue);
      });

      test('detects file ending with _screen.dart', () {
        final path =
            '/project/lib/features/todo/presentation/todo_screen.dart';
        expect(rule.isWidgetOrPageFile(path), isTrue);
      });

      test('rejects Provider file', () {
        final path =
            '/project/lib/features/todo/presentation/providers/todo_provider.dart';
        expect(rule.isWidgetOrPageFile(path), isFalse);
      });

      test('rejects State file', () {
        final path =
            '/project/lib/features/todo/presentation/states/todo_state.dart';
        expect(rule.isWidgetOrPageFile(path), isFalse);
      });

      test('rejects Domain file', () {
        final path =
            '/project/lib/features/todo/domain/usecases/get_todos_usecase.dart';
        expect(rule.isWidgetOrPageFile(path), isFalse);
      });

      test('rejects Data file', () {
        final path =
            '/project/lib/features/todo/data/repositories/todo_repository_impl.dart';
        expect(rule.isWidgetOrPageFile(path), isFalse);
      });
    });

    group('UseCase Import Detection', () {
      test('detects UseCase import from /usecases/ directory', () {
        final importUri =
            'package:app/features/todo/domain/usecases/get_todos_usecase.dart';
        expect(rule.isUseCaseImport(importUri), isTrue);
      });

      test('detects UseCase import from /use_cases/ directory', () {
        final importUri =
            'package:app/features/todo/domain/use_cases/get_todos_usecase.dart';
        expect(rule.isUseCaseImport(importUri), isTrue);
      });

      test('detects file ending with _usecase.dart', () {
        final importUri =
            'package:app/features/todo/domain/get_todos_usecase.dart';
        expect(rule.isUseCaseImport(importUri), isTrue);
      });

      test('detects file ending with _use_case.dart', () {
        final importUri =
            'package:app/features/todo/domain/get_todos_use_case.dart';
        expect(rule.isUseCaseImport(importUri), isTrue);
      });

      test('rejects Entity import', () {
        final importUri =
            'package:app/features/todo/domain/entities/todo.dart';
        expect(rule.isUseCaseImport(importUri), isFalse);
      });

      test('rejects Repository import', () {
        final importUri =
            'package:app/features/todo/domain/repositories/todo_repository.dart';
        expect(rule.isUseCaseImport(importUri), isFalse);
      });

      test('rejects Provider import', () {
        final importUri =
            'package:app/features/todo/presentation/providers/todo_provider.dart';
        expect(rule.isUseCaseImport(importUri), isFalse);
      });
    });

    group('UseCase Provider Name Detection', () {
      test('detects provider ending with UseCaseProvider', () {
        expect(rule.isUseCaseProvider('getTodosUseCaseProvider'), isTrue);
      });

      test('detects provider ending with usecase', () {
        expect(rule.isUseCaseProvider('getTodosUsecase'), isTrue);
      });

      test('detects provider containing usecase', () {
        expect(rule.isUseCaseProvider('todoUseCaseListProvider'), isTrue);
      });

      test('detects provider with use_case pattern', () {
        expect(rule.isUseCaseProvider('get_todos_use_case_provider'), isTrue);
      });

      test('rejects normal provider name', () {
        expect(rule.isUseCaseProvider('todoListProvider'), isFalse);
      });

      test('rejects repository provider name', () {
        expect(rule.isUseCaseProvider('todoRepositoryProvider'), isFalse);
      });

      test('rejects state provider name', () {
        expect(rule.isUseCaseProvider('todoStateProvider'), isFalse);
      });
    });
  });
}

// Expose private methods for testing
extension WidgetNoUseCaseCallRuleTestExtension on WidgetNoUseCaseCallRule {
  bool isWidgetOrPageFile(String path) {
    final normalizedPath = path.replaceAll('\\', '/').toLowerCase();
    if (!normalizedPath.contains('/presentation/')) return false;
    return normalizedPath.contains('/widgets/') ||
        normalizedPath.contains('/pages/') ||
        normalizedPath.contains('/screens/') ||
        normalizedPath.contains('/views/') ||
        normalizedPath.endsWith('_page.dart') ||
        normalizedPath.endsWith('_screen.dart') ||
        normalizedPath.endsWith('_view.dart') ||
        normalizedPath.endsWith('_widget.dart');
  }

  bool isUseCaseImport(String importUri) {
    final normalizedUri = importUri.replaceAll('\\', '/').toLowerCase();
    return normalizedUri.contains('/usecases/') ||
        normalizedUri.contains('/use_cases/') ||
        normalizedUri.endsWith('_usecase.dart') ||
        normalizedUri.endsWith('_use_case.dart') ||
        normalizedUri.contains('usecase.dart');
  }

  bool isUseCaseProvider(String providerName) {
    final lowerName = providerName.toLowerCase();
    return lowerName.endsWith('usecaseprovider') ||
        lowerName.endsWith('usecase') ||
        lowerName.contains('usecase') ||
        lowerName.endsWith('use_case_provider') ||
        lowerName.contains('use_case');
  }
}
