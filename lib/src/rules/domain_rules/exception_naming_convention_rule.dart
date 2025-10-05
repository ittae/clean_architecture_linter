import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../clean_architecture_linter_base.dart';

/// Enforces Domain Exception naming convention with feature prefix.
///
/// In Clean Architecture, Domain Exceptions should include feature-specific
/// prefixes to clearly indicate which feature they belong to. This improves
/// code readability and prevents naming conflicts.
///
/// Naming Pattern: {Feature}{ExceptionType}
/// - Feature: Capitalized feature name (Todo, User, Order, etc.)
/// - ExceptionType: Standard exception suffix (NotFoundException, ValidationException, etc.)
///
/// ✅ Correct Pattern:
/// ```dart
/// // domain/exceptions/todo_exceptions.dart
/// class TodoNotFoundException implements Exception {
///   final String message;
///   TodoNotFoundException(this.message);
/// }
///
/// class TodoValidationException implements Exception {
///   final String message;
///   TodoValidationException(this.message);
/// }
///
/// class UserNotFoundException implements Exception {
///   final String message;
///   UserNotFoundException(this.message);
/// }
/// ```
///
/// ❌ Wrong Pattern:
/// ```dart
/// // ❌ Missing feature prefix
/// class NotFoundException implements Exception {}
/// class ValidationException implements Exception {}
///
/// // ❌ Generic exceptions without context
/// class DataException implements Exception {}
/// class CustomException implements Exception {}
/// ```
///
/// See ERROR_HANDLING_GUIDE.md for complete naming conventions.
class ExceptionNamingConventionRule extends CleanArchitectureLintRule {
  const ExceptionNamingConventionRule() : super(code: _code);

  static const _code = LintCode(
    name: 'exception_naming_convention',
    problemMessage:
        'Domain Exception should have feature prefix: {Feature}{ExceptionType}',
    correctionMessage:
        'Add feature prefix to exception name:\\n'
        '  ❌ Bad:  class NotFoundException implements Exception\\n'
        '  ✅ Good: class TodoNotFoundException implements Exception\\n\\n'
        'Pattern: {Feature}{ExceptionType}\\n'
        'Examples: TodoNotFoundException, UserValidationException\\n'
        'See ERROR_HANDLING_GUIDE.md',
  );

  /// Generic exception suffixes that should have feature prefix
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

  /// Allowed exceptions without feature prefix (Data layer, Dart built-in)
  static const allowedWithoutPrefix = {
    'Exception',
    'Error',
    'StateError',
    'ArgumentError',
    'FormatException',
    'RangeError',
    'UnimplementedError',
    'UnsupportedError',
    // Data layer exceptions (allowed)
    'DataSourceException',
    'CacheException',
    'DatabaseException',
  };

  @override
  void runRule(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((node) {
      _checkExceptionNaming(node, reporter, resolver);
    });
  }

  void _checkExceptionNaming(
    ClassDeclaration node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;

    // Only check Domain layer files
    if (!_isDomainFile(filePath)) return;

    // Check if class implements Exception
    if (!_implementsException(node)) return;

    final className = node.name.lexeme;

    // Skip allowed exceptions
    if (_isAllowedWithoutPrefix(className)) return;

    // Check if class needs feature prefix
    if (_needsFeaturePrefix(className)) {
      final suggestedName = _suggestFeatureName(className, filePath);

      final code = LintCode(
        name: 'exception_naming_convention',
        problemMessage:
            'Domain Exception "$className" should have feature prefix',
        correctionMessage:
            'Add feature prefix to exception name:\\n'
            '  Current:  class $className implements Exception\\n'
            '  Suggested: class $suggestedName implements Exception\\n\\n'
            'Pattern: {Feature}{ExceptionType}\\n'
            'Examples: TodoNotFoundException, UserValidationException\\n\\n'
            'This helps identify which feature the exception belongs to.',
      );
      reporter.atNode(node, code);
    }
  }

  /// Check if file is in Domain layer
  bool _isDomainFile(String filePath) {
    final normalized = filePath.replaceAll('\\', '/');
    return normalized.contains('/domain/') ||
        normalized.contains('/exceptions/');
  }

  /// Check if class implements Exception
  bool _implementsException(ClassDeclaration node) {
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

  /// Check if exception is allowed without prefix
  bool _isAllowedWithoutPrefix(String className) {
    return allowedWithoutPrefix.contains(className);
  }

  /// Check if exception needs feature prefix
  bool _needsFeaturePrefix(String className) {
    // Check if it ends with common exception suffixes
    for (final suffix in exceptionSuffixes) {
      if (className == suffix) {
        // Exact match without prefix (e.g., "NotFoundException")
        return true;
      }
    }

    // Check if it's a generic exception name without feature context
    if (className.endsWith('Exception') && className.length < 20) {
      // Short exception names without clear feature context
      final withoutSuffix = className.replaceAll('Exception', '');
      if (withoutSuffix.length < 5) {
        // Very short prefix suggests it might be generic
        return true;
      }
    }

    return false;
  }

  /// Suggest feature name based on file path
  String _suggestFeatureName(String className, String filePath) {
    // Try to extract feature from path
    // e.g., /features/todos/domain/ -> Todo
    final featureMatch = RegExp(r'/features/(\w+)/').firstMatch(filePath);
    if (featureMatch != null) {
      var featureName = featureMatch.group(1)!;
      // Capitalize and singularize
      featureName = featureName[0].toUpperCase() + featureName.substring(1);
      if (featureName.endsWith('s')) {
        featureName = featureName.substring(0, featureName.length - 1);
      }
      return '$featureName$className';
    }

    // Try to extract from directory name
    final pathParts = filePath.split('/');
    for (var i = pathParts.length - 1; i >= 0; i--) {
      final part = pathParts[i];
      if (part != 'domain' &&
          part != 'exceptions' &&
          part != 'lib' &&
          !part.contains('.')) {
        final featureName = part[0].toUpperCase() + part.substring(1);
        return '$featureName$className';
      }
    }

    // Fallback: use generic "Feature" prefix
    return 'Feature$className';
  }
}
