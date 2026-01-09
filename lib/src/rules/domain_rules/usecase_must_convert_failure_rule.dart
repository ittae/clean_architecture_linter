import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../clean_architecture_linter_base.dart';

/// @deprecated This rule is obsolete for pass-through error handling pattern.
///
/// With the pass-through pattern, UseCase does NOT receive Result from Repository.
/// Instead, exceptions propagate directly from DataSource through Repository to
/// AsyncValue.guard() in Presentation layer.
///
/// ## Pass-through Pattern (Current):
/// ```dart
/// // UseCase just calls repository - no Result unwrapping needed
/// class GetTodoUseCase {
///   Future<Todo> call(String id) {
///     if (id.isEmpty) {
///       throw const InvalidInputException.withCode('errorValidationIdRequired');
///     }
///     return _repository.get(id);  // Errors pass through
///   }
/// }
/// ```
///
/// See UNIFIED_ERROR_GUIDE.md for complete error handling patterns.
///
/// This rule is kept for backward compatibility but does nothing.
@Deprecated('Use pass-through pattern instead. See UNIFIED_ERROR_GUIDE.md')
class UseCaseMustConvertFailureRule extends CleanArchitectureLintRule {
  const UseCaseMustConvertFailureRule() : super(code: _code);

  static const _code = LintCode(
    name: 'usecase_must_convert_failure',
    problemMessage:
        'DEPRECATED: This rule is obsolete for pass-through pattern.',
    correctionMessage:
        'This rule is deprecated. Use pass-through error handling instead. '
        'See UNIFIED_ERROR_GUIDE.md',
  );

  @override
  void runRule(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    // NO-OP: This rule is deprecated and does nothing.
    // Kept for backward compatibility.
  }
}
