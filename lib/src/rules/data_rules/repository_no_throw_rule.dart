import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../clean_architecture_linter_base.dart';

/// Enforces that Repository implementations should NOT throw exceptions directly.
///
/// In Clean Architecture, Repository is responsible for error handling by
/// catching exceptions from DataSource and converting them to Result types.
/// Direct exception throwing breaks this error handling boundary.
///
/// Error handling flow:
/// - DataSource: Throws exceptions (NotFoundException, NetworkException, etc.)
/// - Repository Implementation: Catches exceptions → Converts to Result
/// - UseCase: Unwraps Result → Throws domain exceptions
/// - Presentation: Catches domain exceptions → Updates UI state
///
/// ✅ Allowed patterns:
/// - Throwing exceptions in private helper methods (will be caught by public methods)
/// - `rethrow` in catch blocks (re-throwing caught exceptions)
/// - Argument validation in constructors
///
/// ✅ Correct Pattern:
/// ```dart
/// class TodoRepositoryImpl implements TodoRepository {
///   Future<Result<Todo, TodoFailure>> getTodo(String id) async {
///     try {
///       final model = await dataSource.getTodo(id); // DataSource throws
///       return Success(model.toEntity());
///     } on NotFoundException catch (e) {
///       return Failure(TodoFailure.notFound(message: e.message));
///     }
///   }
/// }
/// ```
///
/// ❌ Wrong Pattern:
/// ```dart
/// class TodoRepositoryImpl implements TodoRepository {
///   Future<Result<Todo, TodoFailure>> getTodo(String id) async {
///     if (id.isEmpty) {
///       throw ArgumentError('ID required'); // ❌ Repository shouldn't throw
///     }
///     // Should return Failure instead
///   }
/// }
/// ```
///
/// See ERROR_HANDLING_GUIDE.md for complete error handling patterns.
class RepositoryNoThrowRule extends CleanArchitectureLintRule {
  const RepositoryNoThrowRule() : super(code: _code);

  static const _code = LintCode(
    name: 'repository_no_throw',
    problemMessage:
        'Repository should NOT throw exceptions directly. Convert exceptions to Result instead.',
    correctionMessage:
        'Remove throw statement and return Failure. Repository should catch exceptions and wrap in Result.',
  );

  @override
  void runRule(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addThrowExpression((node) {
      _checkThrowInRepository(node, reporter, resolver);
    });
  }

  void _checkThrowInRepository(
    ThrowExpression node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    // Check if this throw is in a Repository implementation class
    final classNode = node.thisOrAncestorOfType<ClassDeclaration>();
    if (classNode == null) return;

    final className = classNode.name.lexeme;
    if (!_isRepositoryImplClass(className, classNode)) return;

    // Check if this is a rethrow (allowed in catch blocks)
    if (_isRethrow(node)) return;

    // Check if throw is in a private method (allowed as helper)
    final method = node.thisOrAncestorOfType<MethodDeclaration>();
    if (method != null && _isPrivateMethod(method)) return;

    // Check if throw is in a constructor (allowed for validation)
    final constructor = node.thisOrAncestorOfType<ConstructorDeclaration>();
    if (constructor != null) return;

    // This is a direct throw in a public method - report error
    final code = LintCode(
      name: 'repository_no_throw',
      problemMessage:
          'Repository should NOT throw exceptions. Convert to Result instead.',
      correctionMessage:
          'Replace throw with Result.Failure:\n'
          '  Before: throw NotFoundException("Not found")\n'
          '  After:  return Failure(TodoFailure.notFound("Not found"))\n\n'
          'Repository must catch DataSource exceptions and convert to Result. '
          'See ERROR_HANDLING_GUIDE.md',
    );
    reporter.atNode(node, code);
  }

  /// Check if class is a Repository implementation
  bool _isRepositoryImplClass(String className, ClassDeclaration node) {
    // Check class name pattern
    final hasRepositoryName = className.contains('Repository') &&
                              (className.endsWith('Impl') ||
                               className.endsWith('Implementation'));

    if (!hasRepositoryName) return false;

    // Check if implements a Repository interface
    final implementsClause = node.implementsClause;
    if (implementsClause != null) {
      for (final interface in implementsClause.interfaces) {
        final interfaceName = interface.name2.lexeme;
        if (interfaceName.contains('Repository')) {
          return true;
        }
      }
    }

    // If no implements clause but has Repository in name
    return hasRepositoryName;
  }

  /// Check if this is a rethrow statement (allowed)
  bool _isRethrow(ThrowExpression node) {
    // rethrow has no expression (node.expression will be null for 'rethrow')
    // Actually in AST, rethrow is represented differently
    // Check if we're in a catch clause
    final catchClause = node.thisOrAncestorOfType<CatchClause>();
    if (catchClause == null) return false;

    // Check if throw expression is the caught exception
    final expression = node.expression;
    if (expression is SimpleIdentifier) {
      // Check if it matches the caught exception variable
      final catchParam = catchClause.exceptionParameter;
      if (catchParam != null && expression.name == catchParam.name.lexeme) {
        return true;
      }
    }

    return false;
  }

  /// Check if method is private (helper method - allowed to throw)
  bool _isPrivateMethod(MethodDeclaration method) {
    final methodName = method.name.lexeme;
    return methodName.startsWith('_');
  }
}
