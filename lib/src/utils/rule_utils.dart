import 'package:analyzer/dart/ast/ast.dart';

/// Utility functions for Clean Architecture lint rules.
///
/// This file contains common helper functions used across multiple lint rules
/// to avoid code duplication and maintain consistency.
class RuleUtils {
  // Private constructor to prevent instantiation
  RuleUtils._();

  // ============================================================================
  // File Path Checkers
  // ============================================================================

  /// Check if file is in Presentation layer
  static bool isPresentationFile(String filePath) {
    final normalized = _normalizePath(filePath);
    return normalized.contains('/presentation/') ||
        normalized.contains('/ui/') ||
        normalized.contains('/views/') ||
        normalized.contains('/widgets/') ||
        normalized.contains('/pages/') ||
        normalized.contains('/screens/') ||
        normalized.contains('/states/');
  }

  /// Check if file is in Domain layer
  static bool isDomainFile(String filePath) {
    final normalized = _normalizePath(filePath);
    return normalized.contains('/domain/') ||
        normalized.contains('/usecases/') ||
        normalized.contains('/use_cases/') ||
        normalized.contains('/entities/') ||
        normalized.contains('/exceptions/');
  }

  /// Check if file is in Data layer
  static bool isDataFile(String filePath) {
    final normalized = _normalizePath(filePath);
    return normalized.contains('/data/') ||
        normalized.contains('/datasources/') ||
        normalized.contains('/data_sources/') ||
        normalized.contains('/repositories/') ||
        normalized.contains('/models/');
  }

  /// Check if file is a DataSource file
  static bool isDataSourceFile(String filePath) {
    final normalized = _normalizePath(filePath);
    return normalized.contains('/datasources/') ||
        normalized.contains('/data_sources/');
  }

  /// Check if file is a Repository implementation file
  static bool isRepositoryImplFile(String filePath) {
    final normalized = _normalizePath(filePath);
    return normalized.contains('/repositories/') &&
        normalized.endsWith('_impl.dart');
  }

  /// Check if file is a UseCase file
  static bool isUseCaseFile(String filePath) {
    final normalized = _normalizePath(filePath);
    return normalized.contains('/usecases/') ||
        normalized.contains('/use_cases/');
  }

  // ============================================================================
  // Class Name Checkers
  // ============================================================================

  /// Check if class name is a UseCase
  static bool isUseCaseClass(String className) {
    return className.endsWith('UseCase') ||
        className.endsWith('Usecase') ||
        className.contains('UseCase');
  }

  /// Check if class name is a DataSource
  static bool isDataSourceClass(String className) {
    return className.endsWith('DataSource') ||
        className.contains('DataSource');
  }

  /// Check if class name is a Repository
  static bool isRepositoryClass(String className) {
    return className.endsWith('Repository') ||
        className.contains('Repository');
  }

  /// Check if class name is a Repository implementation
  static bool isRepositoryImplClass(String className) {
    return className.endsWith('RepositoryImpl') ||
        className.endsWith('Impl') && className.contains('Repository');
  }

  // ============================================================================
  // Type Checkers
  // ============================================================================

  /// Check if type annotation is a Result type (Result or Either)
  static bool isResultType(TypeAnnotation? returnType) {
    if (returnType == null) return false;

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
      final typeArgs = returnType.typeArguments;
      if (typeArgs != null) {
        for (final arg in typeArgs.arguments) {
          if (isResultType(arg)) {
            return true;
          }
        }
      }
    }

    return false;
  }

  /// Check if type annotation is void
  static bool isVoidType(TypeAnnotation? returnType) {
    if (returnType == null) return false;
    return returnType.toString().contains('void');
  }

  /// Check if class implements Exception
  static bool implementsException(ClassDeclaration node) {
    final implementsClause = node.implementsClause;
    if (implementsClause == null) return false;

    for (final type in implementsClause.interfaces) {
      final typeName = type.name2.lexeme;
      if (typeName == 'Exception') {
        return true;
      }
    }
    return false;
  }

  // ============================================================================
  // Exception & Error Patterns
  // ============================================================================

  /// Data layer exceptions (should NOT be used in Presentation)
  static const dataExceptions = {
    'NotFoundException',
    'UnauthorizedException',
    'NetworkException',
    'DataSourceException',
    'ServerException',
    'CacheException',
    'DatabaseException',
  };

  /// Check if exception type is a Data layer exception
  static bool isDataException(String typeName) {
    return dataExceptions.contains(typeName);
  }

  /// Check if exception type is a Domain exception (has feature prefix)
  static bool isDomainException(String typeName) {
    // Domain exceptions have feature prefix and are not data exceptions
    return typeName.endsWith('Exception') &&
        !isDataException(typeName) &&
        typeName.length > 15; // Has feature prefix
  }

  // ============================================================================
  // Feature & Path Utilities
  // ============================================================================

  /// Extract feature name from file path
  /// e.g., /features/todos/domain/ -> Todo
  static String? extractFeatureName(String filePath) {
    final normalized = _normalizePath(filePath);

    // Try to extract from /features/{feature}/ pattern
    final featureMatch = RegExp(r'/features/(\w+)/').firstMatch(normalized);
    if (featureMatch != null) {
      var featureName = featureMatch.group(1)!;
      return _capitalizeAndSingularize(featureName);
    }

    // Try to extract from directory name
    final pathParts = normalized.split('/');
    for (var i = pathParts.length - 1; i >= 0; i--) {
      final part = pathParts[i];
      if (part != 'domain' &&
          part != 'data' &&
          part != 'presentation' &&
          part != 'lib' &&
          !part.contains('.')) {
        return _capitalizeAndSingularize(part);
      }
    }

    return null;
  }

  /// Normalize file path (convert backslashes to forward slashes)
  static String _normalizePath(String filePath) {
    return filePath.replaceAll('\\', '/');
  }

  /// Capitalize first letter and remove trailing 's' if plural
  static String _capitalizeAndSingularize(String name) {
    var result = name[0].toUpperCase() + name.substring(1);
    if (result.endsWith('s') && result.length > 1) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }

  // ============================================================================
  // AST Navigation Helpers
  // ============================================================================

  /// Find parent class declaration of a node
  static ClassDeclaration? findParentClass(AstNode? node) {
    var current = node;
    while (current != null) {
      if (current is ClassDeclaration) {
        return current;
      }
      current = current.parent;
    }
    return null;
  }

  /// Check if a method is private (starts with _)
  static bool isPrivateMethod(MethodDeclaration method) {
    return method.name.lexeme.startsWith('_');
  }

  /// Check if throw expression is a rethrow
  static bool isRethrow(ThrowExpression node) {
    return node.expression.toString() == 'rethrow' ||
        node.expression is RethrowExpression;
  }
}
