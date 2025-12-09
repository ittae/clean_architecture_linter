import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show ErrorSeverity;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../clean_architecture_linter_base.dart';

/// Enforces that Widgets/Pages should NOT directly call or import UseCases.
///
/// In Clean Architecture with Riverpod, the proper flow is:
/// Widget → Provider → UseCase
///
/// Widgets should only interact with Providers, not UseCases directly.
///
/// ✅ Correct Pattern:
/// ```dart
/// // presentation/pages/todo_page.dart
/// class TodoPage extends ConsumerWidget {
///   @override
///   Widget build(BuildContext context, WidgetRef ref) {
///     // ✅ Call Provider, not UseCase
///     final todosAsync = ref.watch(todoListProvider);
///
///     return todosAsync.when(
///       data: (todos) => ListView(...),
///       loading: () => CircularProgressIndicator(),
///       error: (e, s) => ErrorWidget(e),
///     );
///   }
/// }
/// ```
///
/// ❌ Wrong Pattern:
/// ```dart
/// // presentation/pages/todo_page.dart
/// import 'package:app/domain/usecases/get_todos_usecase.dart';  // ❌ Don't import UseCase
///
/// class TodoPage extends ConsumerWidget {
///   @override
///   Widget build(BuildContext context, WidgetRef ref) {
///     return ElevatedButton(
///       onPressed: () async {
///         // ❌ Don't call UseCase directly
///         final useCase = ref.read(getTodosUseCaseProvider);
///         await useCase();
///       },
///     );
///   }
/// }
/// ```
///
/// **Why this rule exists:**
/// 1. **Separation of Concerns**: Widgets handle UI, Providers handle state/business logic
/// 2. **Testability**: Easier to test widgets by mocking providers
/// 3. **State Management**: Providers manage loading/error states via AsyncValue
/// 4. **Architecture Boundaries**: Maintains clear layer separation
///
/// See CLAUDE.md § Riverpod State Management Patterns for complete guide.
class WidgetNoUseCaseCallRule extends CleanArchitectureLintRule {
  const WidgetNoUseCaseCallRule() : super(code: _code);

  static const _code = LintCode(
    name: 'widget_no_usecase_call',
    problemMessage:
        'Widgets/Pages should NOT directly call or import UseCases. Use Providers instead.',
    correctionMessage:
        'Create a Provider that calls the UseCase, then use ref.watch(provider) in the Widget.\n\n'
        'Current: Widget → UseCase (direct)\n'
        'Correct: Widget → Provider → UseCase\n\n'
        'See CLAUDE.md § Riverpod State Management Patterns',
    errorSeverity: ErrorSeverity.WARNING,
  );

  @override
  void runRule(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    final filePath = resolver.path;

    // Only check Widget/Page files in presentation layer
    if (!_isWidgetOrPageFile(filePath)) return;

    // Check 1: UseCase imports
    context.registry.addImportDirective((node) {
      _checkUseCaseImport(node, reporter, resolver);
    });

    // Check 2: UseCase provider calls (ref.read/ref.watch)
    context.registry.addMethodInvocation((node) {
      _checkUseCaseProviderCall(node, reporter, resolver);
    });
  }

  /// Check if file is a Widget or Page file in presentation layer
  bool _isWidgetOrPageFile(String filePath) {
    final normalizedPath = filePath.replaceAll('\\', '/').toLowerCase();

    // Must be in presentation layer
    if (!normalizedPath.contains('/presentation/')) return false;

    // Check for widget/page directories
    return normalizedPath.contains('/widgets/') ||
        normalizedPath.contains('/pages/') ||
        normalizedPath.contains('/screens/') ||
        normalizedPath.contains('/views/') ||
        normalizedPath.endsWith('_page.dart') ||
        normalizedPath.endsWith('_screen.dart') ||
        normalizedPath.endsWith('_view.dart') ||
        normalizedPath.endsWith('_widget.dart');
  }

  /// Check for UseCase imports in Widget files
  void _checkUseCaseImport(
    ImportDirective node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final importUri = node.uri.stringValue;
    if (importUri == null) return;

    // Check if importing a UseCase file
    if (_isUseCaseImport(importUri)) {
      final code = LintCode(
        name: 'widget_no_usecase_call',
        problemMessage: 'Widget/Page should NOT import UseCase: $importUri',
        correctionMessage:
            'Remove UseCase import. Create a Provider that calls the UseCase instead.',
        errorSeverity: ErrorSeverity.WARNING,
      );
      reporter.atNode(node, code);
    }
  }

  /// Check if import URI is a UseCase
  bool _isUseCaseImport(String importUri) {
    final normalizedUri = importUri.replaceAll('\\', '/').toLowerCase();

    // Check for UseCase file patterns
    return normalizedUri.contains('/usecases/') ||
        normalizedUri.contains('/use_cases/') ||
        normalizedUri.endsWith('_usecase.dart') ||
        normalizedUri.endsWith('_use_case.dart') ||
        normalizedUri.contains('usecase.dart');
  }

  /// Check for UseCase provider calls in Widget methods
  void _checkUseCaseProviderCall(
    MethodInvocation node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    // Check if it's a ref.read() or ref.watch() call
    if (!_isRefCall(node)) return;

    // Get the provider name being called
    final providerName = _getProviderName(node);
    if (providerName == null) return;

    // Check if it's a UseCase provider
    if (_isUseCaseProvider(providerName)) {
      final methodName = node.methodName.name;

      final code = LintCode(
        name: 'widget_no_usecase_call',
        problemMessage:
            'Widget/Page should NOT call UseCase provider "$providerName" directly via $methodName()',
        correctionMessage:
            'Create an Entity Provider that calls the UseCase, then ref.watch() that provider.',
        errorSeverity: ErrorSeverity.WARNING,
      );
      reporter.atNode(node, code);
    }
  }

  /// Check if method invocation is ref.read() or ref.watch()
  bool _isRefCall(MethodInvocation node) {
    final methodName = node.methodName.name;
    if (methodName != 'read' && methodName != 'watch') return false;

    // Check if it's called on 'ref' object
    final target = node.target;
    if (target is SimpleIdentifier && target.name == 'ref') {
      return true;
    }

    return false;
  }

  /// Extract provider name from ref.read(providerName) or ref.watch(providerName)
  String? _getProviderName(MethodInvocation node) {
    final arguments = node.argumentList.arguments;
    if (arguments.isEmpty) return null;

    final firstArg = arguments.first;

    // Handle: ref.read(todoUseCaseProvider)
    if (firstArg is SimpleIdentifier) {
      return firstArg.name;
    }

    // Handle: ref.read(todoUseCaseProvider())
    if (firstArg is MethodInvocation) {
      return firstArg.methodName.name;
    }

    // Handle: ref.read(todoUseCaseProvider.notifier)
    if (firstArg is PropertyAccess) {
      final target = firstArg.target;
      if (target is SimpleIdentifier) {
        return target.name;
      }
    }

    return null;
  }

  /// Check if provider name indicates a UseCase provider
  bool _isUseCaseProvider(String providerName) {
    final lowerName = providerName.toLowerCase();

    // Check for UseCase provider naming patterns
    return lowerName.endsWith('usecaseprovider') ||
        lowerName.endsWith('usecase') ||
        lowerName.contains('usecase') ||
        lowerName.endsWith('use_case_provider') ||
        lowerName.contains('use_case');
  }
}
