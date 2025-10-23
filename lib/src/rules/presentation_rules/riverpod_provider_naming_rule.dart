import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show ErrorSeverity;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../clean_architecture_linter_base.dart';

/// Enforces proper naming convention for Riverpod provider functions.
///
/// **Naming Rules:**
/// When a @riverpod function returns Repository/UseCase/DataSource types,
/// the function name MUST include the suffix to enable proper provider generation.
///
/// **Why This Matters:**
/// - Riverpod code generation creates provider names from function names
/// - Without proper suffix, generated provider names are ambiguous
/// - Proper naming enables UseCase provider detection in ref.watch/ref.read rules
///
/// ❌ Anti-patterns:
/// ```dart
/// // ❌ WRONG - Missing 'usecase' suffix
/// @riverpod
/// GetEventsUsecase getEvents(Ref ref) {
///   return GetEventsUsecase(ref.watch(eventRepositoryProvider));
/// }
/// // Generates: getEventsProvider (ambiguous!)
///
/// // ❌ WRONG - Missing 'repository' suffix
/// @riverpod
/// EventRepository eventRepo(Ref ref) {
///   return EventRepositoryImpl(ref.watch(eventDataSourceProvider));
/// }
/// // Generates: eventRepoProvider (ambiguous!)
///
/// // ❌ WRONG - Missing 'datasource' suffix
/// @riverpod
/// EventDataSource eventData(Ref ref) {
///   return EventRemoteDataSource();
/// }
/// // Generates: eventDataProvider (ambiguous!)
/// ```
///
/// ✅ Correct patterns:
/// ```dart
/// // ✅ CORRECT - Includes 'usecase' suffix
/// @riverpod
/// GetEventsUsecase getEventsUsecase(Ref ref) {
///   return GetEventsUsecase(ref.watch(eventRepositoryProvider));
/// }
/// // Generates: getEventsUsecaseProvider (clear!)
///
/// // ✅ CORRECT - Includes 'repository' suffix
/// @riverpod
/// EventRepository eventRepository(Ref ref) {
///   return EventRepositoryImpl(ref.watch(eventDataSourceProvider));
/// }
/// // Generates: eventRepositoryProvider (clear!)
///
/// // ✅ CORRECT - Includes 'datasource' suffix
/// @riverpod
/// EventDataSource eventDataSource(Ref ref) {
///   return EventRemoteDataSource();
/// }
/// // Generates: eventDataSourceProvider (clear!)
/// ```
///
/// See CLAUDE.md § Riverpod State Management Patterns for detailed guidance.
class RiverpodProviderNamingRule extends CleanArchitectureLintRule {
  const RiverpodProviderNamingRule() : super(code: _code);

  static const _code = LintCode(
    name: 'riverpod_provider_naming',
    problemMessage:
        'Provider function name must include type suffix (repository/usecase/datasource).',
    correctionMessage:
        'Riverpod provider function naming rules:\n\n'
        '✅ Repository return type: name must end with "repository"\n'
        '✅ UseCase return type: name must end with "usecase"\n'
        '✅ DataSource return type: name must end with "datasource"\n\n'
        'See CLAUDE.md § Riverpod State Management Patterns',
    errorSeverity: ErrorSeverity.WARNING,
  );

  @override
  void runRule(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    final filePath = resolver.path;

    // Only check provider files in presentation layer
    if (!_isProviderFile(filePath)) return;

    context.registry.addFunctionDeclaration((node) {
      _checkProviderFunction(node, reporter);
    });
  }

  /// Check if file is a provider file
  bool _isProviderFile(String filePath) {
    final normalizedPath = filePath.replaceAll('\\', '/').toLowerCase();

    if (!normalizedPath.contains('/presentation/')) return false;

    return normalizedPath.contains('/providers/') ||
        normalizedPath.endsWith('_provider.dart') ||
        normalizedPath.endsWith('_providers.dart');
  }

  /// Check provider function for naming violations
  void _checkProviderFunction(
    FunctionDeclaration node,
    ErrorReporter reporter,
  ) {
    // Check if this is a @riverpod annotated function
    if (!_hasRiverpodAnnotation(node)) return;

    // Get function name and return type
    final functionName = node.name.lexeme;
    final returnType = node.returnType;

    if (returnType == null) return;

    final returnTypeName = _getReturnTypeName(returnType);
    if (returnTypeName == null) return;

    // Check if return type is Repository/UseCase/DataSource
    final requiredSuffix = _getRequiredSuffix(returnTypeName);
    if (requiredSuffix == null) return;

    // Check if function name has the required suffix
    final lowerFunctionName = functionName.toLowerCase();
    if (!lowerFunctionName.endsWith(requiredSuffix.toLowerCase())) {
      final suggestedName = _suggestFunctionName(functionName, requiredSuffix);

      final code = LintCode(
        name: 'riverpod_provider_naming',
        problemMessage:
            'Provider function returning $returnTypeName must end with "$requiredSuffix".',
        correctionMessage:
            'Provider function naming convention:\n\n'
            '❌ Current:\n'
            '   @riverpod\n'
            '   $returnTypeName $functionName(Ref ref) { }\n'
            '   // Generates: ${functionName}Provider (ambiguous!)\n\n'
            '✅ Correct:\n'
            '   @riverpod\n'
            '   $returnTypeName $suggestedName(Ref ref) { }\n'
            '   // Generates: ${suggestedName}Provider (clear!)\n\n'
            'Why: Function name must include "$requiredSuffix" suffix for:\n'
            '• Clear provider name generation\n'
            '• Proper UseCase provider detection\n'
            '• Consistent naming across codebase\n\n'
            'See CLAUDE.md § Riverpod State Management Patterns',
        errorSeverity: ErrorSeverity.WARNING,
      );
      reporter.atNode(node, code);
    }
  }

  /// Check if function has @riverpod annotation
  bool _hasRiverpodAnnotation(FunctionDeclaration node) {
    for (final metadata in node.metadata) {
      final name = metadata.name.name;
      if (name == 'riverpod' || name == 'Riverpod') {
        return true;
      }
    }
    return false;
  }

  /// Get return type name from type annotation
  String? _getReturnTypeName(TypeAnnotation returnType) {
    if (returnType is NamedType) {
      return returnType.name2.lexeme;
    }
    return null;
  }

  /// Get required suffix based on return type
  ///
  /// Returns:
  /// - "repository" for Repository types
  /// - "usecase" for UseCase types
  /// - "datasource" for DataSource types
  /// - null for other types
  String? _getRequiredSuffix(String returnTypeName) {
    final lowerTypeName = returnTypeName.toLowerCase();

    // Check for Repository
    if (lowerTypeName.contains('repository')) {
      return 'repository';
    }

    // Check for UseCase
    if (lowerTypeName.contains('usecase')) {
      return 'usecase';
    }

    // Check for DataSource
    if (lowerTypeName.contains('datasource')) {
      return 'datasource';
    }

    return null;
  }

  /// Suggest function name with proper suffix
  String _suggestFunctionName(String currentName, String requiredSuffix) {
    // If name is in camelCase, preserve it
    // Example: getEvents -> getEventsUsecase
    // Example: eventRepo -> eventRepository

    // Capitalize first letter of suffix for camelCase
    final capitalizedSuffix =
        requiredSuffix[0].toUpperCase() + requiredSuffix.substring(1);

    return '$currentName$capitalizedSuffix';
  }
}
