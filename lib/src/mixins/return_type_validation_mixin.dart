import 'package:analyzer/dart/ast/ast.dart';

import '../clean_architecture_linter_base.dart';

/// Mixin providing standardized return type validation for lint rules.
///
/// This mixin consolidates common patterns for checking method return types
/// across multiple Clean Architecture lint rules. It provides:
///
/// - **Result type detection**: Checks if a type is `Result<T, F>` or `Either<L, R>`
/// - **Void type detection**: Checks if a type is `void` or `Future<void>`
/// - **Method filtering**: Filters private methods, constructors, and void methods
///
/// ## Usage Example
///
/// ```dart
/// class MyLintRule extends CleanArchitectureLintRule with ReturnTypeValidationMixin {
///   void _checkMethod(MethodDeclaration method, ErrorReporter reporter) {
///     // Skip private and void methods
///     if (shouldSkipMethod(method)) return;
///
///     final returnType = method.returnType;
///     if (returnType == null) return;
///
///     // Check for Result type (to warn against using it)
///     if (isResultReturnType(returnType)) {
///       reporter.atNode(returnType, myLintCode);
///     }
///   }
/// }
/// ```
///
/// ## Rules Using This Mixin
///
/// - `datasource_no_result_return_rule` - DataSource should not return Result
/// - `repository_must_return_result_rule` - Repository should not use Result (pass-through pattern)
/// - `usecase_no_result_return_rule` - UseCase should not return Result
///
/// ## Benefits
///
/// - **Consistency**: All rules use the same return type validation logic
/// - **Maintainability**: Changes to validation logic update all rules
/// - **Testability**: Mixin logic can be tested independently
/// - **Clarity**: Descriptive method names improve rule readability
mixin ReturnTypeValidationMixin {
  /// Checks if the given [returnType] is a `Result<T, F>` or `Either<L, R>` type.
  ///
  /// This method detects both:
  /// - Direct Result: `Result<Todo, TodoFailure>`
  /// - Future-wrapped Result: `Future<Result<Todo, TodoFailure>>`
  /// - Either type: `Either<Failure, Todo>`
  /// - Future-wrapped Either: `Future<Either<Failure, Todo>>`
  ///
  /// Example:
  /// ```dart
  /// final returnType = method.returnType;
  /// if (returnType != null && isResultReturnType(returnType)) {
  ///   // Method returns Result type
  /// }
  /// ```
  bool isResultReturnType(TypeAnnotation returnType) {
    return CleanArchitectureUtils.isResultType(returnType);
  }

  /// Checks if the given [returnType] is `void` or `Future<void>`.
  ///
  /// This is useful for skipping validation on methods that don't return data,
  /// such as delete operations or fire-and-forget actions.
  ///
  /// Example:
  /// ```dart
  /// final returnType = method.returnType;
  /// if (returnType != null && isVoidReturnType(returnType)) {
  ///   return; // Skip void methods
  /// }
  /// ```
  bool isVoidReturnType(TypeAnnotation returnType) {
    return CleanArchitectureUtils.isVoidType(returnType);
  }

  /// Determines if a method should be skipped from validation.
  ///
  /// A method is skipped if:
  /// - It's a private method (starts with `_`) - helpers don't need validation
  /// - It's a constructor - constructors don't have return types to validate
  /// - It returns void - void methods don't carry data
  ///
  /// Example:
  /// ```dart
  /// void _checkMethod(MethodDeclaration method, ErrorReporter reporter) {
  ///   if (shouldSkipMethod(method)) return;
  ///
  ///   // Validate public, non-void methods only
  ///   final returnType = method.returnType;
  ///   // ...
  /// }
  /// ```
  bool shouldSkipMethod(MethodDeclaration method) {
    // Skip private methods (helpers - will be caught by public methods)
    final methodName = method.name.lexeme;
    if (methodName.startsWith('_')) return true;

    // Skip constructors
    if (method.isOperator || method.isSetter || method.isGetter) return true;

    // Skip void methods (e.g., delete operations)
    final returnType = method.returnType;
    if (returnType != null && isVoidReturnType(returnType)) return true;

    return false;
  }

  /// Gets the return type of a method, handling null safety.
  ///
  /// Returns `null` if the method has no explicit return type annotation.
  ///
  /// Example:
  /// ```dart
  /// final returnType = getMethodReturnType(method);
  /// if (returnType == null) return; // No return type annotation
  ///
  /// if (isResultReturnType(returnType)) {
  ///   // Handle Result return type
  /// }
  /// ```
  TypeAnnotation? getMethodReturnType(MethodDeclaration method) {
    return method.returnType;
  }
}
