import 'package:analyzer/dart/ast/ast.dart';

import '../clean_architecture_linter_base.dart';

/// Mixin providing standardized exception validation for lint rules.
///
/// This mixin consolidates common patterns for checking exception-related code
/// across multiple Clean Architecture lint rules. It provides:
///
/// - **Exception detection**: Checks if a class implements Exception
/// - **Exception naming validation**: Validates feature-prefixed naming conventions
/// - **Exception type checking**: Identifies Data vs Domain exceptions
///
/// ## Usage Example
///
/// ```dart
/// class MyExceptionRule extends CleanArchitectureLintRule with ExceptionValidationMixin {
///   void _checkException(ClassDeclaration node, ErrorReporter reporter) {
///     // Check if class implements Exception
///     if (!isExceptionClass(node)) return;
///
///     final className = node.name.lexeme;
///
///     // Check naming convention
///     if (isGenericExceptionName(className)) {
///       reporter.atNode(node, myLintCode);
///     }
///   }
/// }
/// ```
///
/// ## Rules Using This Mixin
///
/// - `exception_naming_convention_rule` - Domain exception naming validation
/// - `exception_message_localization_rule` - Exception message language validation
/// - `presentation_no_data_exceptions_rule` - Presentation layer exception validation
///
/// ## Benefits
///
/// - **Consistency**: All rules use the same exception detection logic
/// - **Maintainability**: Changes to validation logic update all rules
/// - **Testability**: Mixin logic can be tested independently
/// - **Clarity**: Descriptive method names improve rule readability
mixin ExceptionValidationMixin {
  /// Generic exception suffixes that should have feature prefix.
  ///
  /// These are common exception types that should be prefixed with a feature name
  /// to avoid naming conflicts and improve clarity.
  ///
  /// Example:
  /// - ❌ `NotFoundException` (too generic)
  /// - ✅ `TodoNotFoundException` (feature-specific)
  static const exceptionSuffixes = {
    'NotFoundException',
    'ValidationException',
    'UnauthorizedException',
    'NetworkException',
    'ServerException',
    'TimeoutException',
    'CancelledException',
    'InvalidException',
    'DuplicateException',
  };

  /// Data layer exceptions that are allowed without feature prefix.
  ///
  /// These exceptions are used in the Data layer and don't need feature prefixes
  /// because they represent infrastructure concerns, not domain logic.
  static const dataLayerExceptions = {
    'DataSourceException',
    'CacheException',
    'DatabaseException',
    'NotFoundException', // Data layer version (404)
    'UnauthorizedException', // Data layer version (401/403)
    'NetworkException', // Data layer version (connection errors)
    'ServerException', // Data layer version (5xx errors)
    'ConflictException', // Data layer version (409 conflict)
    'TimeoutException', // Data layer version (request timeout)
  };

  /// Core AppException types that are allowed without feature prefix.
  ///
  /// These are the unified exception types from the AppException sealed class
  /// pattern. They use a `code` + `debugMessage` structure for i18n support.
  ///
  /// See: UNIFIED_ERROR_GUIDE.md for complete documentation.
  static const appExceptionTypes = {
    'AppException', // Base sealed class
    'NetworkException', // Network connectivity errors
    'TimeoutException', // Request timeout
    'ServerException', // Server errors (5xx)
    'UnauthorizedException', // Authentication required (401)
    'ForbiddenException', // Permission denied (403)
    'NotFoundException', // Resource not found (404)
    'InvalidInputException', // Validation errors (400)
    'ConflictException', // Resource conflict (409)
    'CacheException', // Local cache errors
    'UnknownException', // Fallback for unknown errors
  };

  /// Dart built-in exceptions that are allowed without feature prefix.
  static const dartBuiltInExceptions = {
    'Exception',
    'Error',
    'StateError',
    'ArgumentError',
    'FormatException',
    'RangeError',
    'UnimplementedError',
    'UnsupportedError',
  };

  /// Checks if the given [node] is a class that implements Exception.
  ///
  /// Example:
  /// ```dart
  /// if (isExceptionClass(classNode)) {
  ///   // This class implements Exception
  /// }
  /// ```
  bool isExceptionClass(ClassDeclaration node) {
    return CleanArchitectureUtils.implementsException(node);
  }

  /// Checks if the [className] is a generic exception name without feature prefix.
  ///
  /// Returns `true` if:
  /// - The name matches a generic exception suffix exactly (e.g., "NotFoundException")
  /// - The name is very short and generic (e.g., "DataException", "CustomException")
  ///
  /// Returns `false` for:
  /// - Core AppException types (AppException, InvalidInputException, etc.)
  /// - Feature-prefixed exceptions (TodoNotFoundException, UserValidationException)
  ///
  /// Example:
  /// ```dart
  /// isGenericExceptionName('NotFoundException') // true (generic, needs prefix)
  /// isGenericExceptionName('TodoNotFoundException') // false (has feature prefix)
  /// isGenericExceptionName('DataException') // true (generic)
  /// isGenericExceptionName('AppException') // false (core AppException type)
  /// isGenericExceptionName('InvalidInputException') // false (core AppException type)
  /// ```
  bool isGenericExceptionName(String className) {
    // Core AppException types are allowed without feature prefix
    if (appExceptionTypes.contains(className)) {
      return false;
    }

    // Check if it exactly matches a generic suffix
    if (exceptionSuffixes.contains(className)) {
      return true;
    }

    // Use shared utility for generic class name validation
    return CleanArchitectureUtils.isGenericClassName(className, 'Exception');
  }

  /// Checks if the [className] is allowed without a feature prefix.
  ///
  /// Exceptions are allowed without feature prefix if they are:
  /// - Dart built-in exceptions (Exception, Error, StateError, etc.)
  /// - Data layer infrastructure exceptions (DataSourceException, CacheException, etc.)
  /// - Core AppException types (AppException, NetworkException, etc.)
  ///
  /// Example:
  /// ```dart
  /// isAllowedWithoutPrefix('Exception') // true (Dart built-in)
  /// isAllowedWithoutPrefix('CacheException') // true (Data layer)
  /// isAllowedWithoutPrefix('AppException') // true (Core AppException)
  /// isAllowedWithoutPrefix('InvalidInputException') // true (Core AppException)
  /// isAllowedWithoutPrefix('TodoNotFoundException') // false (feature-specific)
  /// ```
  bool isAllowedWithoutPrefix(String className) {
    return dartBuiltInExceptions.contains(className) ||
        dataLayerExceptions.contains(className) ||
        appExceptionTypes.contains(className);
  }

  /// Checks if the [className] is a core AppException type or extends one.
  ///
  /// AppException types are the unified exception pattern using `code` + `debugMessage`.
  /// They can be used across all layers (DataSource, Repository, UseCase, Presentation).
  ///
  /// Returns `true` if:
  /// - The name exactly matches a core AppException type (e.g., "NotFoundException")
  /// - The name ends with a core AppException type (e.g., "ScheduleConfirmationUnauthorizedException")
  ///
  /// Example:
  /// ```dart
  /// isAppExceptionType('AppException') // true
  /// isAppExceptionType('InvalidInputException') // true
  /// isAppExceptionType('ScheduleConfirmationUnauthorizedException') // true (ends with UnauthorizedException)
  /// isAppExceptionType('CustomError') // false
  /// ```
  bool isAppExceptionType(String className) {
    // Exact match
    if (appExceptionTypes.contains(className)) {
      return true;
    }

    // Check if name ends with any AppException type (inheritance pattern)
    // e.g., ScheduleConfirmationUnauthorizedException ends with UnauthorizedException
    for (final exceptionType in appExceptionTypes) {
      if (exceptionType != 'AppException' && className.endsWith(exceptionType)) {
        return true;
      }
    }

    return false;
  }

  /// Checks if the [className] is a Data layer exception.
  ///
  /// Data layer exceptions represent infrastructure concerns (network, cache, database)
  /// and should only be used in the Data layer, not in Presentation or Domain layers.
  ///
  /// Example:
  /// ```dart
  /// isDataLayerException('NotFoundException') // true
  /// isDataLayerException('CacheException') // true
  /// isDataLayerException('TodoNotFoundException') // false (Domain exception)
  /// ```
  bool isDataLayerException(String className) {
    return dataLayerExceptions.contains(className);
  }

  /// Suggests a feature-prefixed name for the [className] based on [filePath].
  ///
  /// Extracts the feature name from the file path and prefixes the exception name.
  ///
  /// Example:
  /// ```dart
  /// // File: lib/features/todos/domain/exceptions/todo_exceptions.dart
  /// suggestFeaturePrefix('NotFoundException', filePath) // 'TodoNotFoundException'
  ///
  /// // File: lib/features/users/domain/exceptions/user_exceptions.dart
  /// suggestFeaturePrefix('ValidationException', filePath) // 'UserValidationException'
  /// ```
  String suggestFeaturePrefix(String className, String filePath) {
    final featureName = CleanArchitectureUtils.extractFeatureName(filePath);

    if (featureName.isNotEmpty) {
      return '$featureName$className';
    }

    // Fallback: use generic "Feature" prefix
    return 'Feature$className';
  }

  /// Checks if a throw statement throws a Data layer exception.
  ///
  /// Used to detect violations where Presentation layer code catches Data exceptions
  /// instead of Domain exceptions.
  ///
  /// Example:
  /// ```dart
  /// // In AST visitor:
  /// if (throwExpression != null && throwsDataException(throwExpression)) {
  ///   // Report violation: shouldn't throw Data exceptions in Presentation
  /// }
  /// ```
  bool throwsDataException(ThrowExpression throwExpression) {
    final thrownType = throwExpression.expression;
    if (thrownType is SimpleIdentifier) {
      return isDataLayerException(thrownType.name);
    }
    return false;
  }

  /// Checks if a catch clause catches a Data layer exception.
  ///
  /// Used to detect violations where Presentation layer code catches Data exceptions
  /// instead of Domain exceptions.
  ///
  /// Example:
  /// ```dart
  /// // In AST visitor:
  /// if (catchesDataException(catchClause)) {
  ///   // Report violation: shouldn't catch Data exceptions in Presentation
  /// }
  /// ```
  bool catchesDataException(CatchClause catchClause) {
    final exceptionType = catchClause.exceptionType;
    final typeName = exceptionType.toString();
    return isDataLayerException(typeName);
  }
}
