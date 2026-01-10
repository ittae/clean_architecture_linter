import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show ErrorSeverity;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../clean_architecture_linter_base.dart';
import '../../mixins/repository_rule_visitor.dart';
import '../../mixins/exception_validation_mixin.dart';

/// Validates exception throwing patterns in Repository implementations.
///
/// In Clean Architecture, Repository uses the pass-through pattern where
/// DataSource exceptions bubble up and are handled by AsyncValue.guard()
/// in the Presentation layer.
///
/// ```dart
/// // ✅ CORRECT - Pass-through pattern (no error handling needed)
/// class TodoRepositoryImpl implements TodoRepository {
///   Future<Todo> getTodo(String id) async {
///     final model = await dataSource.getTodo(id); // Errors pass through
///     return model.toEntity();
///   }
/// }
/// ```
///
/// ## What This Rule Checks
///
/// - ✅ Pass-through (no throws, no try-catch) - Allowed
/// - ✅ Throwing AppException types - Allowed
/// - ✅ Rethrow in catch blocks - Allowed
/// - ⚠️ Throwing non-AppException types - Warning (inconsistent with pattern)
///
/// See UNIFIED_ERROR_GUIDE.md for complete error handling patterns.
class RepositoryNoThrowRule extends CleanArchitectureLintRule
    with RepositoryRuleVisitor, ExceptionValidationMixin {
  const RepositoryNoThrowRule() : super(code: _code);

  static const _code = LintCode(
    name: 'repository_no_throw',
    problemMessage:
        'Repository should throw AppException types for consistent error handling.',
    correctionMessage:
        'Use AppException types (NotFoundException, InvalidInputException, etc.) '
        'or let DataSource exceptions pass through.',
  );

  @override
  void runRule(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addThrowExpression((node) {
      _checkThrowInRepository(node, reporter, resolver);
    });
  }

  void _checkThrowInRepository(
    ThrowExpression node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    // Check if this throw is in a Repository implementation class
    final classNode = node.thisOrAncestorOfType<ClassDeclaration>();
    if (classNode == null) return;

    if (!isRepositoryImplementation(classNode)) return;

    // Allow rethrow (pass-through pattern)
    if (isAllowedRepositoryThrow(node)) return;

    // Check what is being thrown
    final thrownExpression = node.expression;
    final thrownTypeName = _getExceptionTypeName(thrownExpression);

    if (thrownTypeName == null) return;

    // Allow AppException types
    if (isAppExceptionType(thrownTypeName)) return;

    // Allow Data layer exceptions (they're essentially AppException types)
    if (isDataLayerException(thrownTypeName)) return;

    // Warn about throwing non-standard exception types
    // This helps maintain consistency with the AppException pattern
    final code = LintCode(
      name: 'repository_no_throw',
      problemMessage:
          'Repository throws non-standard exception type "$thrownTypeName". '
          'Consider using AppException types for consistent error handling.',
      correctionMessage:
          'Use AppException types (NotFoundException, ServerException, etc.) '
          'or let DataSource handle error conversion.',
      errorSeverity: ErrorSeverity.INFO,
    );
    reporter.atNode(node, code);
  }

  /// Extracts the exception type name from a throw expression.
  String? _getExceptionTypeName(Expression expression) {
    if (expression is InstanceCreationExpression) {
      return expression.constructorName.type.name2.lexeme;
    }
    if (expression is MethodInvocation) {
      // e.g., Exception('message') or CustomException.create()
      final target = expression.target;
      if (target is SimpleIdentifier) {
        return target.name;
      }
    }
    if (expression is SimpleIdentifier) {
      // e.g., throw existingException
      return expression.name;
    }
    return null;
  }
}
