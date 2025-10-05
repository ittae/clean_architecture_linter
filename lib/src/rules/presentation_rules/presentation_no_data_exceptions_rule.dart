import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../clean_architecture_linter_base.dart';
import '../../utils/rule_utils.dart';

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
class PresentationNoDataExceptionsRule extends CleanArchitectureLintRule {
  const PresentationNoDataExceptionsRule() : super(code: _code);

  static const _code = LintCode(
    name: 'presentation_no_data_exceptions',
    problemMessage:
        'Presentation layer should NOT handle Data layer exceptions. Use Domain exceptions instead.',
    correctionMessage:
        'Replace Data exception with Domain exception:\n'
        '  Before: if (error is NotFoundException)\n'
        '  After:  if (error is TodoNotFoundException)\n\n'
        'UseCase should convert Data exceptions to Domain exceptions. '
        'See ERROR_HANDLING_GUIDE.md',
  );

  /// Data layer exceptions that should NOT be used in Presentation
  static const dataExceptions = {
    'NotFoundException',
    'UnauthorizedException',
    'NetworkException',
    'DataSourceException',
    'ServerException',
    'CacheException',
    'DatabaseException',
  };

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
    if (!RuleUtils.isPresentationFile(filePath)) return;

    // Get the type being checked
    final type = node.type;
    if (type is! NamedType) return;

    final typeName = type.name2.lexeme;

    // Check if it's a Data layer exception
    if (RuleUtils.isDataException(typeName)) {
      final domainException = _suggestDomainException(typeName, filePath);

      final code = LintCode(
        name: 'presentation_no_data_exceptions',
        problemMessage:
            'Presentation should NOT handle Data exception "$typeName". '
            'Use Domain exception instead.',
        correctionMessage:
            'Replace with Domain exception:\n'
            '  Before: if (error is $typeName)\n'
            '  After:  if (error is $domainException)\n\n'
            'UseCase layer should convert Data exceptions to Domain exceptions. '
            'Data exceptions should never reach Presentation layer.\n\n'
            'See ERROR_HANDLING_GUIDE.md for complete patterns.',
      );
      reporter.atNode(type, code);
    }
  }

  /// Suggest appropriate Domain exception based on context
  String _suggestDomainException(String dataException, String filePath) {
    // Extract feature name using RuleUtils
    final featureName = RuleUtils.extractFeatureName(filePath);

    if (featureName != null) {
      return '$featureName$dataException'; // e.g., TodoNotFoundException
    }

    // Fallback: generic Domain exception
    return 'Domain$dataException';
  }
}
