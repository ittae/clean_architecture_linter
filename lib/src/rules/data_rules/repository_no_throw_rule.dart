import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../clean_architecture_linter_base.dart';
import '../../mixins/repository_rule_visitor.dart';

/// Enforces that Repository implementations should NOT throw exceptions directly.
///
/// In Clean Architecture, Repository is responsible for error handling by
/// catching exceptions from DataSource and converting them to Result types.
/// Direct exception throwing breaks this error handling boundary.
///
/// Error handling flow:
/// - DataSource: Throws exceptions (NotFoundException, NetworkException, etc.)
/// - Repository Implementation: Catches exceptions → Converts to Result
/// - UseCase: Unwraps Result → Throws domain exceptions
/// - Presentation: Catches domain exceptions → Updates UI state
///
/// ✅ Allowed patterns:
/// - Throwing exceptions in private helper methods (will be caught by public methods)
/// - `rethrow` in catch blocks (re-throwing caught exceptions)
/// - Argument validation in constructors
///
/// ✅ Correct Pattern:
/// ```dart
/// class TodoRepositoryImpl implements TodoRepository {
///   Future<Result<Todo, TodoFailure>> getTodo(String id) async {
///     try {
///       final model = await dataSource.getTodo(id); // DataSource throws
///       return Success(model.toEntity());
///     } on NotFoundException catch (e) {
///       return Failure(TodoFailure.notFound(message: e.message));
///     }
///   }
/// }
/// ```
///
/// ❌ Wrong Pattern:
/// ```dart
/// class TodoRepositoryImpl implements TodoRepository {
///   Future<Result<Todo, TodoFailure>> getTodo(String id) async {
///     if (id.isEmpty) {
///       throw ArgumentError('ID required'); // ❌ Repository shouldn't throw
///     }
///     // Should return Failure instead
///   }
/// }
/// ```
///
/// See ERROR_HANDLING_GUIDE.md for complete error handling patterns.
class RepositoryNoThrowRule extends CleanArchitectureLintRule
    with RepositoryRuleVisitor {
  const RepositoryNoThrowRule() : super(code: _code);

  static const _code = LintCode(
    name: 'repository_no_throw',
    problemMessage:
        'Repository should NOT throw exceptions directly. Convert exceptions to Result instead.',
    correctionMessage:
        'Remove throw statement and return Failure. Repository should catch exceptions and wrap in Result.',
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

    // Check if this is an allowed throw (rethrow, private method, constructor)
    if (isAllowedRepositoryThrow(node)) return;

    // This is a direct throw in a public method - report error
    final code = LintCode(
      name: 'repository_no_throw',
      problemMessage:
          'Repository should NOT throw exceptions. Convert to Result instead.',
      correctionMessage: 'Replace throw with Result.Failure:\n'
          '  Before: throw NotFoundException("Not found")\n'
          '  After:  return Failure(TodoFailure.notFound("Not found"))\n\n'
          'Repository must catch DataSource exceptions and convert to Result. '
          'See ERROR_HANDLING_GUIDE.md',
    );
    reporter.atNode(node, code);
  }
}
