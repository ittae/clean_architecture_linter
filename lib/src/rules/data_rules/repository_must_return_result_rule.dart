import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../clean_architecture_linter_base.dart';

/// Enforces that Repository implementations must return Result type.
///
/// In Clean Architecture, Repository implementations in the Data Layer are
/// responsible for catching exceptions from DataSources and converting them
/// to Result types. This enforces proper error handling boundaries.
///
/// Error handling flow:
/// - DataSource: Throws exceptions
/// - Repository Implementation: Catches exceptions → Returns Result
/// - UseCase: Unwraps Result → Throws domain exceptions
/// - Presentation: Catches exceptions → Updates UI state
///
/// ✅ Correct Pattern:
/// ```dart
/// // data/repositories/todo_repository_impl.dart
/// class TodoRepositoryImpl implements TodoRepository {
///   final TodoRemoteDataSource remoteDataSource;
///
///   @override
///   Future<Result<Todo, TodoFailure>> getTodo(String id) async {
///     try {
///       final model = await remoteDataSource.getTodo(id);
///       return Success(model.toEntity());
///     } on NotFoundException catch (e) {
///       return Failure(TodoFailure.notFound(message: e.message));
///     } on NetworkException catch (e) {
///       return Failure(TodoFailure.networkError(message: e.message));
///     }
///   }
/// }
/// ```
///
/// ❌ Wrong Pattern:
/// ```dart
/// // ❌ Repository should return Result, not throw
/// class TodoRepositoryImpl implements TodoRepository {
///   Future<Todo> getTodo(String id) async {
///     final model = await remoteDataSource.getTodo(id);
///     return model.toEntity(); // ❌ No error handling
///   }
/// }
/// ```
///
/// See ERROR_HANDLING_GUIDE.md for complete error handling patterns.
class RepositoryMustReturnResultRule extends CleanArchitectureLintRule {
  const RepositoryMustReturnResultRule() : super(code: _code);

  static const _code = LintCode(
    name: 'repository_must_return_result',
    problemMessage:
        'Repository implementation must return Result type to handle errors properly.',
    correctionMessage:
        'Wrap return type in Result (e.g., Future<Result<Todo, TodoFailure>>). '
        'Catch DataSource exceptions and convert to Result.',
  );

  @override
  void runRule(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((node) {
      _checkRepositoryMethod(node, reporter, resolver);
    });
  }

  void _checkRepositoryMethod(
    MethodDeclaration method,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    // Check if this method is in a Repository implementation class
    final classNode = method.thisOrAncestorOfType<ClassDeclaration>();
    if (classNode == null) return;

    final className = classNode.name.lexeme;
    if (!_isRepositoryImplClass(className, classNode)) return;

    // Skip private methods (helpers - can throw, will be caught by public methods)
    final methodName = method.name.lexeme;
    if (methodName.startsWith('_')) return;

    // Check if method returns Result type
    final returnType = method.returnType;
    if (returnType == null) return;

    // Skip void methods (e.g., delete operations)
    if (_isVoidReturn(returnType)) return;

    if (!_isResultType(returnType)) {
      final code = LintCode(
        name: 'repository_must_return_result',
        problemMessage:
            'Repository method "${method.name.lexeme}" must return Result type. '
            'Repository should catch exceptions and convert to Result.',
        correctionMessage:
            'Wrap return type in Result:\n'
            '  Before: Future<${returnType.toString()}>\n'
            '  After:  Future<Result<${returnType.toString()}, TodoFailure>>\n\n'
            'Catch DataSource exceptions and convert to Failure. See ERROR_HANDLING_GUIDE.md',
      );
      reporter.atNode(returnType, code);
    }
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

  /// Check if return type is void or Future<void>
  bool _isVoidReturn(TypeAnnotation returnType) {
    final typeStr = returnType.toString();
    return typeStr == 'void' ||
           typeStr == 'Future<void>' ||
           typeStr.startsWith('Future<void>');
  }

  /// Check if return type is Result or Either
  bool _isResultType(TypeAnnotation returnType) {
    final typeStr = returnType.toString();

    // Check for common Result/Either patterns
    if (typeStr.contains('Result<') ||
        typeStr.contains('Either<') ||
        typeStr.contains('Result ') ||
        typeStr.contains('Either ')) {
      return true;
    }

    // Check with NamedType for more precise detection
    if (returnType is NamedType) {
      final name = returnType.name2.lexeme;
      if (name == 'Result' || name == 'Either') {
        return true;
      }

      // Check type arguments (e.g., Future<Result<T, E>>)
      final typeArgs = returnType.typeArguments?.arguments;
      if (typeArgs != null) {
        for (final arg in typeArgs) {
          if (_isResultType(arg)) {
            return true;
          }
        }
      }
    }

    return false;
  }
}
