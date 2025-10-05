import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../clean_architecture_linter_base.dart';
import '../../utils/rule_utils.dart';

/// Enforces that DataSource should only use defined Data layer exceptions.
///
/// In Clean Architecture, DataSource should throw specific Data layer
/// exceptions for consistent error handling. Using generic exceptions or
/// custom exception types makes error handling inconsistent and harder to
/// maintain.
///
/// Allowed Data Layer Exceptions:
/// - NotFoundException
/// - UnauthorizedException
/// - NetworkException
/// - DataSourceException
/// - ServerException
/// - CacheException
/// - DatabaseException
///
/// ✅ Correct Pattern:
/// ```dart
/// // data/datasources/todo_remote_datasource.dart
/// class TodoRemoteDataSource {
///   Future<Todo> getTodo(String id) async {
///     final response = await client.get('/todos/$id');
///
///     if (response.statusCode == 404) {
///       // ✅ Use defined Data exception
///       throw NotFoundException('Todo not found: $id');
///     }
///
///     if (response.statusCode == 401) {
///       throw UnauthorizedException('Authentication required');
///     }
///
///     if (response.statusCode >= 500) {
///       throw ServerException('Server error: ${response.statusCode}');
///     }
///
///     return Todo.fromJson(response.data);
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
/// See ERROR_HANDLING_GUIDE.md for complete error handling patterns.
class DataSourceExceptionTypesRule extends CleanArchitectureLintRule {
  const DataSourceExceptionTypesRule() : super(code: _code);

  static const _code = LintCode(
    name: 'datasource_exception_types',
    problemMessage:
        'DataSource should only use defined Data layer exceptions. Found: {0}',
    correctionMessage:
        'Use one of the defined Data exceptions:\n'
        '  - NotFoundException (for 404 errors)\n'
        '  - UnauthorizedException (for 401/403 errors)\n'
        '  - NetworkException (for connection errors)\n'
        '  - ServerException (for 5xx errors)\n'
        '  - DataSourceException (for data source errors)\n'
        '  - CacheException (for cache errors)\n'
        '  - DatabaseException (for database errors)\n\n'
        'See ERROR_HANDLING_GUIDE.md',
  );

  /// Allowed Data layer exceptions
  static const allowedExceptions = {
    'NotFoundException',
    'UnauthorizedException',
    'NetworkException',
    'DataSourceException',
    'ServerException',
    'CacheException',
    'DatabaseException',
  };

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
    if (!RuleUtils.isDataSourceFile(filePath) && !_isDataSourceClass(node)) return;

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

    // Check if it's an allowed exception
    if (!_isAllowedException(exceptionType)) {
      final code = LintCode(
        name: 'datasource_exception_types',
        problemMessage:
            'DataSource should NOT use "$exceptionType". Use defined Data layer exceptions instead.',
        correctionMessage:
            'Replace with appropriate Data exception:\n'
            '  - NotFoundException (for 404 errors)\n'
            '  - UnauthorizedException (for 401/403 errors)\n'
            '  - NetworkException (for network/connection errors)\n'
            '  - ServerException (for 5xx server errors)\n'
            '  - DataSourceException (for data source specific errors)\n'
            '  - CacheException (for cache errors)\n'
            '  - DatabaseException (for database errors)\n\n'
            'Current: throw $exceptionType(...)\n'
            'Example: throw NotFoundException(\'Resource not found\')',
      );
      reporter.atNode(expression, code);
    }
  }

  /// Check if throw is inside a DataSource class
  bool _isDataSourceClass(ThrowExpression node) {
    final classNode = RuleUtils.findParentClass(node);
    if (classNode == null) return false;

    final className = classNode.name.lexeme;
    return RuleUtils.isDataSourceClass(className);
  }

  /// Check if exception is allowed in DataSource
  bool _isAllowedException(String exceptionType) {
    return allowedExceptions.contains(exceptionType);
  }
}
