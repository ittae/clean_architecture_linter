import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../clean_architecture_linter_base.dart';

/// Warns against unnecessary usage of `@Riverpod(keepAlive: true)`.
///
/// `keepAlive: true` prevents provider auto-disposal, keeping it alive for the
/// entire app lifecycle. This should only be used for truly global state.
///
/// **Valid uses for keepAlive:**
/// - Authentication state (user session)
/// - App-wide settings/preferences
/// - Global cache that must persist
/// - Background services (timers, notifications)
///
/// **Invalid uses (design smell):**
/// - Avoiding `ref.mounted` errors → Fix the async flow instead
/// - Feature-specific state → Should dispose with the feature
/// - Screen-specific data → Should dispose when leaving screen
///
/// ❌ Wrong Pattern:
/// ```dart
/// @Riverpod(keepAlive: true)  // ❌ Just to avoid dispose errors
/// class TodoListNotifier extends _$TodoListNotifier {
///   // ...
/// }
/// ```
///
/// ✅ Correct Pattern:
/// ```dart
/// // For auth state - valid keepAlive usage
/// @Riverpod(keepAlive: true)
/// class AuthNotifier extends _$AuthNotifier { ... }
///
/// // For feature state - let it auto-dispose
/// @riverpod
/// class TodoListNotifier extends _$TodoListNotifier { ... }
/// ```
class RiverpodKeepAliveRule extends CleanArchitectureLintRule {
  const RiverpodKeepAliveRule() : super(code: _code);

  static const _code = LintCode(
    name: 'riverpod_keep_alive',
    problemMessage:
        'Verify that "keepAlive: true" is necessary. Only use for app-wide persistent state.',
    correctionMessage:
        'Valid uses: auth state, app settings, global cache. Invalid: avoiding dispose errors (fix async flow instead).',
  );

  /// Class name patterns that legitimately need keepAlive
  static const _validKeepAlivePatterns = [
    'auth',
    'user',
    'session',
    'settings',
    'preferences',
    'config',
    'theme',
    'locale',
    'cache',
    'analytics',
    'notification',
    'connectivity',
    'permission',
    'account',
  ];

  /// File path patterns that indicate valid keepAlive context
  static const _validPathPatterns = [
    '/auth/',
    '/core/auth/',
    '/features/auth/',
  ];

  /// Class name patterns for infrastructure providers (no keepAlive warning needed)
  static const _infrastructurePatterns = [
    'datasource',
    'repository',
    'usecase',
    'service',
    'client',
    'api',
  ];

  @override
  void runRule(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addAnnotation((node) {
      _checkKeepAliveAnnotation(node, reporter, resolver);
    });
  }

  void _checkKeepAliveAnnotation(
    Annotation node,
    DiagnosticReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    final normalized = filePath.replaceAll('\\', '/').toLowerCase();

    // Only check in presentation layer
    if (!normalized.contains('/presentation/') &&
        !normalized.contains('/providers/')) {
      return;
    }

    // Check if this is a @Riverpod annotation
    final annotationName = node.name.name;
    if (annotationName != 'Riverpod') return;

    // Check for keepAlive argument
    final arguments = node.arguments;
    if (arguments == null) return;

    bool hasKeepAliveTrue = false;
    for (final arg in arguments.arguments) {
      if (arg is NamedExpression) {
        final name = arg.name.label.name;
        final value = arg.expression;

        if (name == 'keepAlive' &&
            value is BooleanLiteral &&
            value.value == true) {
          hasKeepAliveTrue = true;
          break;
        }
      }
    }

    if (!hasKeepAliveTrue) return;

    // Find the associated class to check if it's a valid use case
    final parent = node.parent;
    if (parent is! ClassDeclaration) return;

    final className = parent.name.lexeme.toLowerCase();

    // Skip infrastructure providers (DataSource, Repository, UseCase, etc.)
    final isInfrastructure = _infrastructurePatterns.any(
      (pattern) => className.contains(pattern),
    );
    if (isInfrastructure) return;

    // Check if the class name suggests a valid keepAlive use case
    final isValidUseCase = _validKeepAlivePatterns.any(
      (pattern) => className.contains(pattern),
    );

    // Check if the file path suggests a valid keepAlive context
    final isValidPath = _validPathPatterns.any(
      (pattern) => normalized.contains(pattern),
    );

    // If not a clearly valid use case, report a warning
    if (!isValidUseCase && !isValidPath) {
      reporter.atNode(node, code);
    }
  }
}
