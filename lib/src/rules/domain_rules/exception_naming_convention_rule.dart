import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../clean_architecture_linter_base.dart';
import '../../mixins/exception_validation_mixin.dart';

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
class ExceptionNamingConventionRule extends CleanArchitectureLintRule
    with ExceptionValidationMixin {
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
    if (!CleanArchitectureUtils.isDomainFile(filePath)) return;

    // Skip /core/ directory - core exceptions don't need feature prefix
    if (filePath.contains('/core/')) {
      return;
    }

    // Check if class implements Exception
    if (!isExceptionClass(node)) return;

    final className = node.name.lexeme;

    // Skip Dart built-in exceptions (Exception, Error, StateError, etc.)
    if (ExceptionValidationMixin.dartBuiltInExceptions.contains(className)) {
      return;
    }

    // Check if class needs feature prefix
    if (isGenericExceptionName(className)) {
      final suggestedName = suggestFeaturePrefix(className, filePath);

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
}
