import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:analyzer/error/error.dart' show ErrorSeverity;

import '../../clean_architecture_linter_base.dart';
import '../../mixins/exception_validation_mixin.dart';

/// Enforces that DataSource should only use defined AppException types.
///
/// In Clean Architecture, DataSource should throw specific AppException types
/// for consistent error handling. Using generic exceptions or custom exception
/// types makes error handling inconsistent and harder to maintain.
///
/// Allowed AppException Types:
/// - AppException (base sealed class)
/// - NetworkException (connection errors)
/// - TimeoutException (request timeout)
/// - ServerException (5xx server errors)
/// - UnauthorizedException (401 authentication)
/// - ForbiddenException (403 permission denied)
/// - NotFoundException (404 resource not found)
/// - InvalidInputException (400 validation errors)
/// - ConflictException (409 resource conflict)
/// - CacheException (local cache errors)
/// - UnknownException (fallback for unknown errors)
///
/// ✅ Correct Pattern:
/// ```dart
/// // data/datasources/todo_remote_datasource.dart
/// class TodoRemoteDataSource {
///   Future<TodoModel> getTodo(String id) async {
///     try {
///       final response = await client.get('/todos/$id');
///       return TodoModel.fromJson(response.data);
///     } on DioException catch (e) {
///       // ✅ Convert to AppException
///       throw switch (e.response?.statusCode) {
///         404 => NotFoundException('Todo not found: $id'),
///         401 => UnauthorizedException('Authentication required'),
///         403 => ForbiddenException('Access denied'),
///         >= 500 => ServerException('Server error'),
///         _ => UnknownException('Request failed', e),
///       };
///     }
///   }
/// }
/// ```
///
/// ❌ Wrong Pattern:
/// ```dart
/// // ❌ Using generic Exception
/// throw Exception('Custom error');
///
/// // ❌ Using Dart built-in exceptions
/// throw StateError('Invalid state');
/// throw FormatException('Invalid format');
///
/// // ❌ Creating custom exception types
/// throw CustomDataException('Error');
/// ```
///
/// See UNIFIED_ERROR_GUIDE.md for complete error handling patterns.
class DataSourceExceptionTypesRule extends CleanArchitectureLintRule
    with ExceptionValidationMixin {
  const DataSourceExceptionTypesRule() : super(code: _code);

  static const _code = LintCode(
    name: 'datasource_exception_types',
    problemMessage: 'DataSource should only use defined AppException types.',
    correctionMessage:
        'Use AppException types: NotFoundException, UnauthorizedException, '
        'ServerException, NetworkException, etc.',
    errorSeverity: ErrorSeverity.WARNING,
  );

  @override
  void runRule(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addThrowExpression((node) {
      _checkThrowException(node, reporter, resolver);
    });
  }

  void _checkThrowException(
    ThrowExpression node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;

    // Only check DataSource files or classes
    if (!CleanArchitectureUtils.isDataSourceFile(filePath) &&
        !_isDataSourceClass(node)) {
      return;
    }

    final expression = node.expression;

    // Get exception type from throw statement
    String? exceptionType;

    if (expression is InstanceCreationExpression) {
      // throw NotFoundException(...)
      final constructorName = expression.constructorName;
      exceptionType = constructorName.type.name2.lexeme;
    } else if (expression is SimpleIdentifier) {
      // throw error (variable)
      // Skip variable throws - we can't determine type at compile time
      return;
    }

    if (exceptionType == null) return;

    // Check if it's an allowed AppException or Data layer exception
    if (!isAppExceptionType(exceptionType) &&
        !isDataLayerException(exceptionType)) {
      final code = LintCode(
        name: 'datasource_exception_types',
        problemMessage:
            'DataSource should NOT use "$exceptionType". Use AppException types instead.',
        correctionMessage:
            'Use AppException types: NotFoundException, UnauthorizedException, '
            'ServerException, NetworkException, etc.',
        errorSeverity: ErrorSeverity.WARNING,
      );
      reporter.atNode(expression, code);
    }
  }

  /// Check if throw is inside a DataSource class
  bool _isDataSourceClass(ThrowExpression node) {
    final classNode = CleanArchitectureUtils.findParentClass(node);
    if (classNode == null) return false;

    final className = classNode.name.lexeme;
    return CleanArchitectureUtils.isDataSourceClass(className);
  }
}
