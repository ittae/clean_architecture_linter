import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../clean_architecture_linter_base.dart';

/// @deprecated Failure classes are deprecated in pass-through error handling pattern.
///
/// With the pass-through pattern, we use AppException directly instead of
/// Failure classes. This rule now warns when Failure classes are detected,
/// suggesting migration to AppException.
///
/// ## Pass-through Pattern (Current):
/// ```dart
/// // ❌ OLD - Failure class (deprecated)
/// sealed class TodoFailure {
///   const factory TodoFailure.notFound() = TodoNotFoundFailure;
/// }
///
/// // ✅ NEW - AppException (recommended)
/// throw NotFoundException('Todo $id');
/// throw InvalidInputException.withCode('errorValidationTitleRequired');
/// ```
///
/// See UNIFIED_ERROR_GUIDE.md for complete error handling patterns.
@Deprecated(
  'Use AppException instead of Failure classes. See UNIFIED_ERROR_GUIDE.md',
)
class FailureNamingConventionRule extends CleanArchitectureLintRule {
  const FailureNamingConventionRule() : super(code: _code);

  static const _code = LintCode(
    name: 'failure_naming_convention',
    problemMessage:
        'Failure classes are deprecated. Use AppException instead (pass-through pattern).',
    correctionMessage:
        'Migrate to AppException:\n'
        '  Before: TodoFailure.notFound()\n'
        '  After:  throw NotFoundException("Todo \$id")\n\n'
        'See UNIFIED_ERROR_GUIDE.md for migration guide.',
  );

  @override
  void runRule(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((node) {
      final className = node.name.lexeme;

      // Check if it's a Failure class (deprecated)
      if (className.endsWith('Failure')) {
        final filePath = resolver.path;

        // Skip /core/ directory - core failures may still exist during migration
        if (filePath.contains('/core/')) {
          return;
        }

        // Warn about Failure classes in data/domain layers
        if (filePath.contains('/data/') || filePath.contains('/domain/')) {
          reporter.atNode(node, _code);
        }
      }
    });
  }
}
