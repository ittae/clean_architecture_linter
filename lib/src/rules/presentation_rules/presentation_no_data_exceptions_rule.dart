import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:analyzer/error/error.dart' show ErrorSeverity;

import '../../clean_architecture_linter_base.dart';
import '../../mixins/exception_validation_mixin.dart';

/// Enforces that Presentation layer should NOT handle Data layer exceptions.
///
/// In Clean Architecture, Presentation should only catch and handle Domain
/// exceptions, not Data layer exceptions. This enforces proper error handling
/// boundaries and layer separation.
///
/// Error handling flow:
/// - DataSource: Throws Data exceptions (NotFoundException, NetworkException, etc.)
/// - Repository: Catches Data exceptions → Converts to Result
/// - UseCase: Unwraps Result → Throws Domain exceptions (TodoNotFoundException, etc.)
/// - Presentation: Catches Domain exceptions → Updates UI state
///
/// Data Layer Exceptions (NOT allowed in Presentation):
/// - NotFoundException
/// - UnauthorizedException
/// - NetworkException
/// - DataSourceException
///
/// Domain Layer Exceptions (Allowed in Presentation):
/// - TodoNotFoundException (feature-specific)
/// - UserNotFoundException (feature-specific)
/// - TodoValidationException
/// - etc.
///
/// ✅ Correct Pattern:
/// ```dart
/// // presentation/widgets/todo_list.dart
/// Widget build(BuildContext context, WidgetRef ref) {
///   return asyncValue.when(
///     error: (error, stack) {
///       // ✅ Handle Domain exceptions
///       if (error is TodoNotFoundException) {
///         return ErrorWidget('할 일을 찾을 수 없습니다');
///       }
///       if (error is TodoNetworkException) {
///         return ErrorWidget('네트워크 연결을 확인해주세요');
///       }
///     },
///   );
/// }
/// ```
///
/// ❌ Wrong Pattern:
/// ```dart
/// // ❌ Presentation handling Data exceptions
/// if (error is NotFoundException) { // Data exception
///   return ErrorWidget('Not found');
/// }
/// if (error is NetworkException) { // Data exception
///   return ErrorWidget('Network error');
/// }
/// ```
///
/// See ERROR_HANDLING_GUIDE.md for complete error handling patterns.
class PresentationNoDataExceptionsRule extends CleanArchitectureLintRule
    with ExceptionValidationMixin {
  const PresentationNoDataExceptionsRule() : super(code: _code);

  static const _code = LintCode(
    name: 'presentation_no_data_exceptions',
    problemMessage:
        'Presentation layer should NOT handle Data layer exceptions. Use Domain exceptions instead.',
    correctionMessage:
        'Replace with feature-prefixed Domain exception, e.g., "TodoNotFoundException".',
    errorSeverity: ErrorSeverity.WARNING,
  );

  @override
  void runRule(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addIsExpression((node) {
      _checkExceptionTypeCheck(node, reporter, resolver);
    });
  }

  void _checkExceptionTypeCheck(
    IsExpression node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;

    // Only check files in presentation layer
    if (!CleanArchitectureUtils.isPresentationFile(filePath)) return;

    // Get the type being checked
    final type = node.type;
    if (type is! NamedType) return;

    final typeName = type.name2.lexeme;

    // Check if it's a Data layer exception
    if (isDataLayerException(typeName)) {
      final domainException = suggestFeaturePrefix(typeName, filePath);

      final code = LintCode(
        name: 'presentation_no_data_exceptions',
        problemMessage:
            'Presentation should NOT handle Data exception "$typeName". '
            'Use Domain exception instead.',
        correctionMessage:
            'Replace with Domain exception "$domainException". UseCase should convert Data exceptions.',
        errorSeverity: ErrorSeverity.WARNING,
      );
      reporter.atNode(type, code);
    }
  }
}
