import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:analyzer/error/error.dart' show ErrorSeverity;

import '../../clean_architecture_linter_base.dart';
import '../../mixins/repository_rule_visitor.dart';
import '../../mixins/return_type_validation_mixin.dart';

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
class RepositoryMustReturnResultRule extends CleanArchitectureLintRule
    with RepositoryRuleVisitor, ReturnTypeValidationMixin {
  const RepositoryMustReturnResultRule() : super(code: _code);

  static const _code = LintCode(
    name: 'repository_must_return_result',
    problemMessage:
        'Repository implementation must return Result type to handle errors properly.',
    correctionMessage:
        'Wrap return type in Result (e.g., Future<Result<Todo, TodoFailure>>). '
        'Catch DataSource exceptions and convert to Result.',
    errorSeverity: ErrorSeverity.WARNING,
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

    if (!isRepositoryImplementation(classNode)) return;

    // Skip private methods and void methods
    if (shouldSkipMethod(method)) return;

    final returnType = method.returnType;
    if (returnType == null) return;

    if (!isResultReturnType(returnType)) {
      final code = LintCode(
        name: 'repository_must_return_result',
        problemMessage:
            'Repository method "${method.name.lexeme}" must return Result type. '
            'Repository should catch exceptions and convert to Result.',
        correctionMessage:
            'Wrap return type in Result<T, Failure> and catch DataSource exceptions.',
        errorSeverity: ErrorSeverity.WARNING,
      );
      reporter.atNode(returnType, code);
    }
  }
}
