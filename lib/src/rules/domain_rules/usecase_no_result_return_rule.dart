import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../clean_architecture_linter_base.dart';
import '../../mixins/return_type_validation_mixin.dart';

/// Enforces that UseCase should NOT return Result type.
///
/// In Clean Architecture with pass-through error handling, UseCase receives
/// Entity directly from Repository (not Result). UseCase performs business
/// validation and throws AppException for validation errors. Other exceptions
/// pass through to AsyncValue.guard() in Presentation layer.
///
/// Pass-through error handling flow:
/// - DataSource: Throws AppException
/// - Repository: Passes through (no error handling)
/// - UseCase: Passes through + validation → Returns Entity OR throws AppException
/// - Presentation: AsyncValue.guard() automatically catches exceptions
///
/// ✅ Correct Pattern:
/// ```dart
/// // domain/usecases/get_todo_usecase.dart
/// class GetTodoUseCase {
///   final TodoRepository repository;
///
///   GetTodoUseCase(this.repository);
///
///   Future<Todo> call(String id) {
///     // Business validation
///     if (id.isEmpty) {
///       throw const InvalidInputException.withCode('errorValidationIdRequired');
///     }
///     return repository.getTodo(id);  // Errors pass through
///   }
/// }
/// ```
///
/// ❌ Wrong Pattern:
/// ```dart
/// // ❌ UseCase should NOT return Result
/// class GetTodoUseCase {
///   Future<Result<Todo, TodoFailure>> call(String id) async {
///     return await repository.getTodo(id); // Result pattern is obsolete
///   }
/// }
/// ```
///
/// See UNIFIED_ERROR_GUIDE.md for complete error handling patterns.
class UseCaseNoResultReturnRule extends CleanArchitectureLintRule
    with ReturnTypeValidationMixin {
  const UseCaseNoResultReturnRule() : super(code: _code);

  static const _code = LintCode(
    name: 'usecase_no_result_return',
    problemMessage:
        'UseCase should NOT return Result type. UseCase should return Entity directly (pass-through pattern).',
    correctionMessage:
        'Return Future<Entity> directly. Throw InvalidInputException for validation errors.',
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
            'Return Entity directly (pass-through pattern).',
        correctionMessage:
            'Return Future<Entity> directly. Throw InvalidInputException for validation errors.',
      );
      reporter.atNode(returnType, code);
    }
  }
}
