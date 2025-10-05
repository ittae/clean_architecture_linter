import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../clean_architecture_linter_base.dart';
import '../../utils/rule_utils.dart';

/// Enforces that UseCase should convert Failure to Domain Exception.
///
/// In Clean Architecture, UseCase receives Result<T, Failure> from Repository
/// and should convert Failure to Domain Exception using .toException() method.
/// This ensures Presentation layer only handles Domain exceptions.
///
/// Error handling flow:
/// - Repository: Returns Result<Entity, Failure>
/// - UseCase: Unwraps Result → Converts Failure to Domain Exception
/// - Presentation: Catches Domain Exception only
///
/// ✅ Correct Pattern:
/// ```dart
/// // domain/usecases/get_todo_usecase.dart
/// class GetTodoUseCase {
///   Future<Todo> call(String id) async {
///     final result = await repository.getTodo(id);
///
///     // ✅ Convert Failure to Domain Exception
///     return result.when(
///       success: (todo) => todo,
///       failure: (error) => throw error.toException(), // ✅ Convert
///     );
///   }
/// }
/// ```
///
/// ❌ Wrong Pattern:
/// ```dart
/// // ❌ Throwing Failure directly without conversion
/// return result.when(
///   success: (data) => data,
///   failure: (error) => throw error, // ❌ Should use .toException()
/// );
///
/// // ❌ Returning Failure directly
/// return result.when(
///   success: (data) => data,
///   failure: (error) => error, // ❌ Should throw exception
/// );
/// ```
///
/// See ERROR_HANDLING_GUIDE.md for complete error handling patterns.
class UseCaseMustConvertFailureRule extends CleanArchitectureLintRule {
  const UseCaseMustConvertFailureRule() : super(code: _code);

  static const _code = LintCode(
    name: 'usecase_must_convert_failure',
    problemMessage:
        'UseCase should convert Failure to Domain Exception using .toException()',
    correctionMessage:
        'In Result.when() failure case, call .toException():\\n'
        '  Before: failure: (error) => throw error\\n'
        '  After:  failure: (error) => throw error.toException()\\n\\n'
        'This converts Failure to Domain Exception for Presentation layer.\\n'
        'See ERROR_HANDLING_GUIDE.md',
  );

  @override
  void runRule(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((node) {
      _checkWhenMethodCall(node, reporter, resolver);
    });
  }

  void _checkWhenMethodCall(
    MethodInvocation node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;

    // Only check UseCase files
    if (!RuleUtils.isUseCaseFile(filePath) && !_isUseCaseClass(node)) return;

    // Check if this is a .when() method call
    if (node.methodName.name != 'when') return;

    // Find failure argument
    final failureArg = _findFailureArgument(node);
    if (failureArg == null) return;

    // Check if failure handler uses .toException()
    if (!_usesToException(failureArg)) {
      reporter.atNode(failureArg, _code);
    }
  }

  /// Find 'failure' named argument in when() call
  NamedExpression? _findFailureArgument(MethodInvocation node) {
    for (final arg in node.argumentList.arguments) {
      if (arg is NamedExpression && arg.name.label.name == 'failure') {
        return arg;
      }
    }
    return null;
  }

  /// Check if failure handler uses .toException()
  bool _usesToException(NamedExpression failureArg) {
    final expression = failureArg.expression;

    // failure: (error) => throw error.toException()
    if (expression is FunctionExpression) {
      final body = expression.body;

      if (body is ExpressionFunctionBody) {
        return _containsToExceptionCall(body.expression);
      } else if (body is BlockFunctionBody) {
        // Check all statements in block
        for (final statement in body.block.statements) {
          if (_containsToExceptionInStatement(statement)) {
            return true;
          }
        }
      }
    }

    return false;
  }

  /// Check if expression contains .toException() call
  bool _containsToExceptionCall(Expression expression) {
    // throw error.toException()
    if (expression is ThrowExpression) {
      return _containsToExceptionCall(expression.expression);
    }

    // error.toException()
    if (expression is MethodInvocation) {
      if (expression.methodName.name == 'toException') {
        return true;
      }
      // Check nested calls
      if (expression.target != null) {
        return _containsToExceptionCall(expression.target as Expression);
      }
    }

    // Handle other expression types
    if (expression is PrefixedIdentifier) {
      return expression.identifier.name == 'toException';
    }

    return false;
  }

  /// Check if statement contains .toException() call
  bool _containsToExceptionInStatement(Statement statement) {
    if (statement is ExpressionStatement) {
      return _containsToExceptionCall(statement.expression);
    }

    if (statement is ReturnStatement) {
      if (statement.expression != null) {
        return _containsToExceptionCall(statement.expression!);
      }
    }

    // ThrowExpression is an Expression, not a Statement
    // So we check for ExpressionStatement with ThrowExpression
    // Already handled by ExpressionStatement case above

    return false;
  }

  /// Check if method is inside a UseCase class
  bool _isUseCaseClass(MethodInvocation node) {
    final classNode = RuleUtils.findParentClass(node);
    if (classNode == null) return false;

    final className = classNode.name.lexeme;
    return RuleUtils.isUseCaseClass(className);
  }
}
