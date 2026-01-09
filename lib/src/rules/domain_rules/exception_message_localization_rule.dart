import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../clean_architecture_linter_base.dart';

/// @deprecated This rule is obsolete for pass-through error handling pattern.
///
/// In the pass-through pattern, exception constructor arguments are `debugMessage`
/// for developer logging, NOT user-facing messages. User-facing messages are
/// generated via `error.toLocalizedMessage(context)` using ARB files.
///
/// ## Pass-through Pattern (Current):
/// ```dart
/// // debugMessage is for developers (English is fine)
/// throw InvalidInputException('availableTimes is empty');
///
/// // User sees localized message via:
/// // error.toLocalizedMessage(context) → uses ARB files
/// ```
///
/// See UNIFIED_ERROR_GUIDE.md for complete error handling patterns.
///
/// This rule is kept for backward compatibility but does nothing.
@Deprecated(
  'Exception messages are now debugMessage for developers. '
  'User messages come from toLocalizedMessage(context). See UNIFIED_ERROR_GUIDE.md',
)
class ExceptionMessageLocalizationRule extends CleanArchitectureLintRule {
  const ExceptionMessageLocalizationRule() : super(code: _code);

  static const _code = LintCode(
    name: 'exception_message_localization',
    problemMessage:
        'DEPRECATED: This rule is obsolete for pass-through pattern.',
    correctionMessage:
        'Exception messages are now debugMessage for developers. '
        'User-facing messages come from error.toLocalizedMessage(context) using ARB files. '
        'See UNIFIED_ERROR_GUIDE.md',
  );

  @override
  void runRule(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    // NO-OP: This rule is deprecated for pass-through pattern.
    // In pass-through pattern:
    // - Exception constructor args are debugMessage (for developers)
    // - User messages come from toLocalizedMessage(context) using ARB files
  }
}
