import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../clean_architecture_linter_base.dart';
import '../../mixins/return_type_validation_mixin.dart';

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
class UseCaseNoResultReturnRule extends CleanArchitectureLintRule
    with ReturnTypeValidationMixin {
  const UseCaseNoResultReturnRule() : super(code: _code);

  static const _code = LintCode(
    name: 'usecase_no_result_return',
    problemMessage:
        'UseCase should NOT return Result type. UseCase should unwrap Result and return Entity or throw domain exception.',
    correctionMessage:
        'Unwrap Result using result.when() and return Entity or throw domain exception.',
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
    if (!CleanArchitectureUtils.isUseCaseClass(className)) return;

    // Skip private methods and void methods
    if (shouldSkipMethod(method)) return;

    // Check if method returns Result type
    final returnType = method.returnType;
    if (returnType == null) return;

    if (isResultReturnType(returnType)) {
      final code = LintCode(
        name: 'usecase_no_result_return',
        problemMessage:
            'UseCase method "${method.name.lexeme}" should NOT return Result. '
            'UseCase should unwrap Result and return Entity or throw domain exception.',
        correctionMessage:
            'Return Entity directly and use result.when() to unwrap Result.',
      );
      reporter.atNode(returnType, code);
    }
  }
}
