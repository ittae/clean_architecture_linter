import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../clean_architecture_linter_base.dart';

/// Enforces that UseCase should NOT return Result type.
///
/// In Clean Architecture, UseCase is responsible for unwrapping Result from
/// Repository and either returning the Entity or throwing a domain exception.
/// This maintains proper error handling boundaries.
///
/// Error handling flow:
/// - DataSource: Throws exceptions
/// - Repository: Catches exceptions → Returns Result
/// - UseCase: Unwraps Result → Returns Entity OR throws domain exception
/// - Presentation: Catches domain exceptions → Updates UI state (AsyncValue)
///
/// ✅ Correct Pattern:
/// ```dart
/// // domain/usecases/get_todo_usecase.dart
/// class GetTodoUseCase {
///   final TodoRepository repository;
///
///   GetTodoUseCase(this.repository);
///
///   Future<Todo> call(String id) async {
///     final result = await repository.getTodo(id);
///
///     return result.when(
///       success: (data) => data,
///       failure: (error) => throw error.toException(), // Convert to domain exception
///     );
///   }
/// }
/// ```
///
/// ❌ Wrong Pattern:
/// ```dart
/// // ❌ UseCase should NOT return Result
/// class GetTodoUseCase {
///   Future<Result<Todo, TodoFailure>> call(String id) async {
///     return await repository.getTodo(id); // Just passing through
///   }
/// }
/// ```
///
/// See ERROR_HANDLING_GUIDE.md for complete error handling patterns.
class UseCaseNoResultReturnRule extends CleanArchitectureLintRule {
  const UseCaseNoResultReturnRule() : super(code: _code);

  static const _code = LintCode(
    name: 'usecase_no_result_return',
    problemMessage:
        'UseCase should NOT return Result type. UseCase should unwrap Result and return Entity or throw domain exception.',
    correctionMessage:
        'Unwrap Result and return Entity:\n'
        '  return result.when(\n'
        '    success: (data) => data,\n'
        '    failure: (error) => throw error.toException(),\n'
        '  );\n\n'
        'See ERROR_HANDLING_GUIDE.md for complete patterns.',
  );

  @override
  void runRule(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((node) {
      _checkUseCaseMethod(node, reporter, resolver);
    });
  }

  void _checkUseCaseMethod(
    MethodDeclaration method,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    // Check if this method is in a UseCase class
    final classNode = method.thisOrAncestorOfType<ClassDeclaration>();
    if (classNode == null) return;

    final className = classNode.name.lexeme;
    if (!_isUseCaseClass(className)) return;

    // Skip private methods (helpers)
    final methodName = method.name.lexeme;
    if (methodName.startsWith('_')) return;

    // Check if method returns Result type
    final returnType = method.returnType;
    if (returnType == null) return;

    // Skip void methods
    if (_isVoidReturn(returnType)) return;

    if (_isResultType(returnType)) {
      final code = LintCode(
        name: 'usecase_no_result_return',
        problemMessage:
            'UseCase method "${method.name.lexeme}" should NOT return Result. '
            'UseCase should unwrap Result and return Entity or throw domain exception.',
        correctionMessage:
            'Unwrap Result from Repository:\n'
            '  Before: Future<Result<Todo, TodoFailure>> call()\n'
            '  After:  Future<Todo> call() // unwrap and throw on failure\n\n'
            'Pattern:\n'
            '  final result = await repository.getTodo(id);\n'
            '  return result.when(\n'
            '    success: (data) => data,\n'
            '    failure: (error) => throw error.toException(),\n'
            '  );\n\n'
            'See ERROR_HANDLING_GUIDE.md',
      );
      reporter.atNode(returnType, code);
    }
  }

  /// Check if class name indicates it's a UseCase
  bool _isUseCaseClass(String className) {
    return className.endsWith('UseCase') ||
           className.endsWith('Usecase') ||
           className.contains('UseCase');
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
