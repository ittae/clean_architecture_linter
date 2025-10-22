import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show ErrorSeverity;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../clean_architecture_linter_base.dart';

/// Enforces that Presentation layer (States/Notifiers) should NOT throw exceptions.
///
/// In Clean Architecture, Presentation layer should handle errors through state
/// management (AsyncValue, State objects) rather than throwing exceptions.
///
/// Error handling flow:
/// - DataSource: Throws Data exceptions
/// - Repository: Catches exceptions → Converts to Result
/// - UseCase: Unwraps Result → Throws Domain exceptions
/// - **Presentation State: Catches exceptions → Sets state (AsyncValue.error, etc.)**
/// - UI Widget: Renders error state
///
/// ✅ Correct Pattern:
/// ```dart
/// // presentation/states/todo_state.dart
/// class TodoNotifier extends StateNotifier<AsyncValue<List<Todo>>> {
///   Future<void> loadTodos() async {
///     state = const AsyncValue.loading();
///
///     try {
///       final result = await getTodosUseCase();
///       result.when(
///         success: (todos) => state = AsyncValue.data(todos),  // ✅ Set state
///         failure: (failure) => state = AsyncValue.error(failure, StackTrace.current),  // ✅ Set state
///       );
///     } catch (e, stack) {
///       state = AsyncValue.error(e, stack);  // ✅ Set state, don't throw
///     }
///   }
/// }
/// ```
///
/// ❌ Wrong Pattern:
/// ```dart
/// // ❌ Throwing in Presentation State
/// class TodoNotifier extends StateNotifier<AsyncValue<List<Todo>>> {
///   Future<void> loadTodos() async {
///     try {
///       final result = await getTodosUseCase();
///       if (result.isFailure) {
///         throw TodoException('Failed');  // ❌ Don't throw!
///       }
///     } catch (e) {
///       throw;  // ❌ Don't rethrow!
///     }
///   }
/// }
/// ```
///
/// **Exceptions to this rule:**
/// - Programming errors (ArgumentError, AssertionError) are allowed
/// - Private helper methods (_privateMethod) are allowed to throw
/// - Constructors are allowed to throw
///
/// See ERROR_HANDLING_GUIDE.md for complete error handling patterns.
class PresentationNoThrowRule extends CleanArchitectureLintRule {
  const PresentationNoThrowRule() : super(code: _code);

  static const _code = LintCode(
    name: 'presentation_no_throw',
    problemMessage:
        'Presentation States/Notifiers should NOT throw exceptions. Use state management instead.',
    correctionMessage: 'Replace throw with state update:\n'
        '  Before: throw TodoException("Error")\n'
        '  After:  state = AsyncValue.error(TodoFailure.error(), stack)\n\n'
        'Presentation should handle errors through state, not exceptions.\n'
        'See ERROR_HANDLING_GUIDE.md',
    errorSeverity: ErrorSeverity.WARNING,
  );

  @override
  void runRule(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addThrowExpression((node) {
      _checkThrowInPresentation(node, reporter, resolver);
    });
  }

  void _checkThrowInPresentation(
    ThrowExpression node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;

    // Only check Presentation layer files
    if (!CleanArchitectureUtils.isPresentationFile(filePath)) return;

    // Check /states/, /state/, or /providers/ directories
    if (!filePath.contains('/states/') &&
        !filePath.contains('/state/') &&
        !filePath.contains('/providers/')) {
      return;
    }

    // Check if throw is inside a State/Notifier class
    final classNode = CleanArchitectureUtils.findParentClass(node);
    if (classNode == null) return;

    final className = classNode.name.lexeme;

    // Skip if not a State/Notifier/Provider class
    if (!_isStateOrNotifierClass(className, classNode)) return;

    // Find the method containing this throw
    final methodNode = _findParentMethod(node);
    if (methodNode == null) return;

    // Allow throw in private methods
    if (CleanArchitectureUtils.isPrivateMethod(methodNode)) return;

    // Allow throw in constructors
    if (methodNode.parent is ConstructorDeclaration) return;

    // Check if it's throwing a programming error (ArgumentError, AssertionError)
    if (_isThrowingProgrammingError(node)) return;

    // Get the exception type being thrown
    final exceptionType = _getExceptionType(node);

    final code = LintCode(
      name: 'presentation_no_throw',
      problemMessage:
          'Presentation State "$className.${methodNode.name.lexeme}" should NOT throw $exceptionType. '
          'Use state management instead.',
      correctionMessage: 'Replace throw with state update:\n'
          '  ❌ Current: throw $exceptionType\n'
          '  ✅ Better:  state = AsyncValue.error(failure, stack)\n\n'
          'Presentation layer should handle errors through state objects:\n'
          '  - Riverpod: AsyncValue.error(error, stack)\n'
          '  - Bloc: emit(ErrorState(failure))\n'
          '  - StateNotifier: state = ErrorState(failure)\n\n'
          'This prevents app crashes and enables declarative error UI.\n'
          'See ERROR_HANDLING_GUIDE.md',
      errorSeverity: ErrorSeverity.WARNING,
    );

    reporter.atNode(node, code);
  }

  /// Checks if class is a State/Notifier/Provider class
  ///
  /// Detection methods:
  /// 1. Has @riverpod annotation (Riverpod Generator pattern)
  /// 2. Extends AsyncNotifier, Notifier, StateNotifier
  /// 3. Class name contains State/Notifier/Provider/Bloc keywords
  bool _isStateOrNotifierClass(String className, ClassDeclaration classNode) {
    // Check for @riverpod annotation (Riverpod Generator)
    for (final metadata in classNode.metadata) {
      final name = metadata.name.name;
      if (name == 'riverpod' || name == 'Riverpod') {
        return true;
      }
    }

    // Check if extends AsyncNotifier, Notifier, StateNotifier
    final extendsClause = classNode.extendsClause;
    if (extendsClause != null) {
      final superclass = extendsClause.superclass.name2.lexeme;
      if (superclass == 'AsyncNotifier' ||
          superclass == 'Notifier' ||
          superclass == 'StateNotifier' ||
          superclass == 'ChangeNotifier' ||
          superclass.startsWith('_\$')) {
        // _$ prefix indicates generated Riverpod class
        return true;
      }
    }

    // Fallback: Check class name pattern
    return className.contains('Notifier') ||
        className.contains('State') ||
        className.contains('Provider') ||
        className.contains('Bloc') ||
        className.contains('Cubit') ||
        className.contains('Controller') ||
        className.contains('ViewModel');
  }

  /// Finds the parent method of a throw expression
  MethodDeclaration? _findParentMethod(ThrowExpression node) {
    var current = node.parent;
    while (current != null) {
      if (current is MethodDeclaration) return current;
      if (current is ConstructorDeclaration) return null;
      current = current.parent;
    }
    return null;
  }

  /// Checks if throwing a programming error (ArgumentError, AssertionError, etc.)
  bool _isThrowingProgrammingError(ThrowExpression node) {
    final expression = node.expression;

    if (expression is InstanceCreationExpression) {
      final typeName = expression.constructorName.type.name2.lexeme;

      // Allow programming errors (developer mistakes, not business logic errors)
      const programmingErrors = [
        'ArgumentError',
        'AssertionError',
        'StateError',
        'UnimplementedError',
        'UnsupportedError',
        'TypeError',
        'RangeError',
      ];

      return programmingErrors.contains(typeName);
    }

    return false;
  }

  /// Gets the exception type being thrown
  String _getExceptionType(ThrowExpression node) {
    final expression = node.expression;

    if (expression is InstanceCreationExpression) {
      return expression.constructorName.type.name2.lexeme;
    }

    if (expression is SimpleIdentifier) {
      return 'exception (variable)';
    }

    if (expression is RethrowExpression || expression.toString() == 'rethrow') {
      return 'rethrow';
    }

    return 'exception';
  }
}
