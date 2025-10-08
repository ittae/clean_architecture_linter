import 'package:analyzer/dart/ast/ast.dart';

import '../clean_architecture_linter_base.dart';

/// Mixin providing standardized Repository identification for lint rules.
///
/// This mixin consolidates common patterns for identifying and validating
/// Repository-related classes across multiple Clean Architecture lint rules.
/// It provides:
///
/// - **Repository interface detection**: Identifies abstract Repository contracts
/// - **Repository implementation detection**: Identifies concrete Repository classes
/// - **Method filtering**: Distinguishes public vs private methods, constructors
///
/// ## Usage Example
///
/// ```dart
/// class MyRepositoryRule extends CleanArchitectureLintRule with RepositoryRuleVisitor {
///   void _checkRepository(ClassDeclaration node, ErrorReporter reporter) {
///     if (!isRepositoryImplementation(node)) return;
///
///     // Validate Repository implementation patterns
///     final methods = node.members.whereType<MethodDeclaration>();
///     for (final method in methods) {
///       if (shouldValidateRepositoryMethod(method)) {
///         // Check method follows Repository patterns
///       }
///     }
///   }
/// }
/// ```
///
/// ## Rules Using This Mixin
///
/// - `repository_interface_rule` - Repository interface validation
/// - `repository_must_return_result_rule` - Repository return type validation
/// - `repository_no_throw_rule` - Repository error handling validation
/// - `dependency_inversion_rule` - UseCase dependency validation
///
/// ## Benefits
///
/// - **Consistency**: All rules use the same Repository identification logic
/// - **Maintainability**: Changes to identification logic update all rules
/// - **Testability**: Mixin logic can be tested independently
/// - **Clarity**: Descriptive method names improve rule readability
mixin RepositoryRuleVisitor {
  /// Checks if the [node] is a Repository interface (abstract class).
  ///
  /// A class is considered a Repository interface if:
  /// - It has "Repository" in its name
  /// - It's an abstract class (all methods are abstract)
  /// - It's in the Domain layer
  ///
  /// Example:
  /// ```dart
  /// // Domain layer
  /// abstract class TodoRepository {
  ///   Future<Result<Todo, TodoFailure>> getTodo(String id);
  /// }
  ///
  /// isRepositoryInterface(node) // true
  /// ```
  bool isRepositoryInterface(ClassDeclaration node) {
    final className = node.name.lexeme;

    // Must have "Repository" in name
    if (!className.contains('Repository')) return false;

    // Abstract class indicates interface
    if (node.abstractKeyword != null) return true;

    // Check if all methods are abstract (no implementation)
    final methods = node.members.whereType<MethodDeclaration>();
    if (methods.isEmpty) return false;

    return methods.every((method) => method.body is EmptyFunctionBody);
  }

  /// Checks if the [node] is a Repository implementation class.
  ///
  /// A class is considered a Repository implementation if:
  /// - It has "Repository" in its name AND ends with "Impl" or "Implementation"
  /// - OR it implements a Repository interface
  ///
  /// Example:
  /// ```dart
  /// // Data layer
  /// class TodoRepositoryImpl implements TodoRepository {
  ///   @override
  ///   Future<Result<Todo, TodoFailure>> getTodo(String id) async {
  ///     // Implementation
  ///   }
  /// }
  ///
  /// isRepositoryImplementation(node) // true
  /// ```
  bool isRepositoryImplementation(ClassDeclaration node) {
    final className = node.name.lexeme;

    // Check class name pattern
    if (CleanArchitectureUtils.isRepositoryImplClass(className)) {
      return true;
    }

    // Check if implements a Repository interface
    return implementsRepositoryInterface(node);
  }

  /// Checks if the [node] implements a Repository interface.
  ///
  /// Example:
  /// ```dart
  /// class TodoRepositoryImpl implements TodoRepository {
  ///   // ...
  /// }
  ///
  /// implementsRepositoryInterface(node) // true
  /// ```
  bool implementsRepositoryInterface(ClassDeclaration node) {
    final implementsClause = node.implementsClause;
    if (implementsClause == null) return false;

    for (final interface in implementsClause.interfaces) {
      final interfaceName = interface.name2.lexeme;
      if (interfaceName.contains('Repository')) {
        return true;
      }
    }

    return false;
  }

  /// Checks if a [method] should be validated for Repository rules.
  ///
  /// Returns `false` for:
  /// - Private methods (helpers - will be caught by public methods)
  /// - Constructors
  /// - Getters/setters/operators
  ///
  /// Example:
  /// ```dart
  /// void _checkMethod(MethodDeclaration method) {
  ///   if (!shouldValidateRepositoryMethod(method)) return;
  ///
  ///   // Validate public Repository methods only
  /// }
  /// ```
  bool shouldValidateRepositoryMethod(MethodDeclaration method) {
    // Skip private methods (helpers)
    if (CleanArchitectureUtils.isPrivateMethod(method)) return false;

    // Skip constructors, getters, setters, operators
    if (method.isOperator || method.isSetter || method.isGetter) return false;

    return true;
  }

  /// Checks if a throw expression is allowed in a Repository.
  ///
  /// Allowed throw patterns:
  /// - `rethrow` in catch blocks
  /// - Throws in private helper methods
  /// - Throws in constructors (for argument validation)
  ///
  /// Example:
  /// ```dart
  /// void _checkThrow(ThrowExpression throwNode) {
  ///   if (isAllowedRepositoryThrow(throwNode)) return;
  ///
  ///   // Report violation: Repository shouldn't throw directly
  /// }
  /// ```
  bool isAllowedRepositoryThrow(ThrowExpression throwNode) {
    // Allow rethrows in catch blocks
    if (CleanArchitectureUtils.isRethrow(throwNode)) return true;

    // Allow throws in private methods (helpers)
    final method = throwNode.thisOrAncestorOfType<MethodDeclaration>();
    if (method != null && CleanArchitectureUtils.isPrivateMethod(method)) {
      return true;
    }

    // Allow throws in constructors (validation)
    final constructor = throwNode.thisOrAncestorOfType<ConstructorDeclaration>();
    if (constructor != null) return true;

    return false;
  }

  /// Gets the Repository interface name that the [node] implements.
  ///
  /// Returns the first Repository interface name found, or `null` if none.
  ///
  /// Example:
  /// ```dart
  /// class TodoRepositoryImpl implements TodoRepository {
  ///   // ...
  /// }
  ///
  /// getImplementedRepositoryInterface(node) // 'TodoRepository'
  /// ```
  String? getImplementedRepositoryInterface(ClassDeclaration node) {
    final implementsClause = node.implementsClause;
    if (implementsClause == null) return null;

    for (final interface in implementsClause.interfaces) {
      final interfaceName = interface.name2.lexeme;
      if (interfaceName.contains('Repository')) {
        return interfaceName;
      }
    }

    return null;
  }

  /// Checks if a [className] follows Repository naming conventions.
  ///
  /// Valid patterns:
  /// - Abstract: `TodoRepository`, `UserRepository`
  /// - Implementation: `TodoRepositoryImpl`, `UserRepositoryImplementation`
  ///
  /// Example:
  /// ```dart
  /// isValidRepositoryName('TodoRepository') // true
  /// isValidRepositoryName('TodoRepositoryImpl') // true
  /// isValidRepositoryName('TodoRepo') // false (should use full "Repository")
  /// ```
  bool isValidRepositoryName(String className) {
    if (!className.contains('Repository')) return false;

    // Either abstract (no suffix) or implementation (Impl/Implementation suffix)
    if (className.endsWith('Repository')) return true;
    if (className.endsWith('Impl')) return true;
    if (className.endsWith('Implementation')) return true;

    return false;
  }
}
