import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../clean_architecture_linter_base.dart';
import '../../mixins/return_type_validation_mixin.dart';

/// Enforces that DataSource methods should NOT return Result type.
///
/// In Clean Architecture, DataSource should throw exceptions instead of
/// returning Result. The Repository layer is responsible for catching
/// exceptions and converting them to Result/Either types.
///
/// This enforces proper error handling boundaries:
/// - DataSource: Throws exceptions (NotFoundException, NetworkException, etc.)
/// - Repository: Catches exceptions and returns Result<Success, Failure>
/// - UseCase: Unwraps Result and throws domain exceptions
/// - Presentation: Catches exceptions and updates UI state (AsyncValue)
///
/// ✅ Correct Pattern:
/// ```dart
/// // data/datasources/todo_remote_datasource.dart
/// class TodoRemoteDataSource {
///   Future<TodoModel> getTodo(String id) async {
///     final response = await client.get('/todos/$id');
///
///     if (response.statusCode == 404) {
///       throw NotFoundException('Todo not found: $id');
///     }
///
///     return TodoModel.fromJson(response.data);
///   }
/// }
/// ```
///
/// ❌ Wrong Pattern:
/// ```dart
/// // ❌ DataSource should NOT return Result
/// class TodoRemoteDataSource {
///   Future<Result<TodoModel, Failure>> getTodo(String id) async {
///     try {
///       final response = await client.get('/todos/$id');
///       return Success(TodoModel.fromJson(response.data));
///     } catch (e) {
///       return Failure(TodoFailure.fromException(e));
///     }
///   }
/// }
/// ```
///
/// See ERROR_HANDLING_GUIDE.md for complete error handling patterns.
class DataSourceNoResultReturnRule extends CleanArchitectureLintRule
    with ReturnTypeValidationMixin {
  const DataSourceNoResultReturnRule() : super(code: _code);

  static const _code = LintCode(
    name: 'datasource_no_result_return',
    problemMessage:
        'DataSource should NOT return Result type. DataSource should throw exceptions.',
    correctionMessage:
        'Change return type to the data type (e.g., TodoModel) and throw exceptions for errors. '
        'Repository will catch exceptions and convert to Result.',
  );

  @override
  void runRule(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((node) {
      _checkDataSourceMethod(node, reporter, resolver);
    });
  }

  void _checkDataSourceMethod(
    MethodDeclaration method,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    // Check if this method is in a DataSource class
    final classNode = method.thisOrAncestorOfType<ClassDeclaration>();
    if (classNode == null) return;

    final className = classNode.name.lexeme;
    // Only check classes with DataSource in the name
    if (!CleanArchitectureUtils.isDataSourceClass(className)) return;

    // Check if method returns Result type
    final returnType = method.returnType;
    if (returnType == null) return;

    if (isResultReturnType(returnType)) {
      final code = LintCode(
        name: 'datasource_no_result_return',
        problemMessage:
            'DataSource method "${method.name.lexeme}" should NOT return Result. '
            'DataSource should throw exceptions instead.',
        correctionMessage:
            'Remove Result wrapper and throw exceptions for errors:\n'
            '  Before: Future<Result<TodoModel, Failure>> getTodo()\n'
            '  After:  Future<TodoModel> getTodo() // throws NotFoundException\n\n'
            'Repository will catch and convert to Result. See ERROR_HANDLING_GUIDE.md',
      );
      reporter.atNode(returnType, code);
    }
  }
}
