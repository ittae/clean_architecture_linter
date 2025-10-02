import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../clean_architecture_linter_base.dart';

/// Enforces riverpod_generator usage for state management.
///
/// Following CLEAN_ARCHITECTURE_GUIDE.md:
/// - Use @riverpod annotation with riverpod_generator
/// - NO manual StateNotifierProvider
/// - NO ChangeNotifierProvider
/// - Use generated providers for type safety
///
/// ✅ Correct Pattern:
/// ```dart
/// @riverpod
/// class RankingNotifier extends _$RankingNotifier {
///   @override
///   RankingState build() => const RankingState();
///
///   Future<void> loadRankings() async { }
/// }
/// ```
///
/// ❌ Wrong Pattern:
/// ```dart
/// final rankingProvider = StateNotifierProvider<RankingNotifier, RankingState>(  // ❌
///   (ref) => RankingNotifier(),
/// );
///
/// final viewModelProvider = ChangeNotifierProvider(  // ❌
///   (ref) => RankingViewModel(),
/// );
/// ```
class RiverpodGeneratorRule extends CleanArchitectureLintRule {
  const RiverpodGeneratorRule() : super(code: _code);

  static const _code = LintCode(
    name: 'riverpod_generator',
    problemMessage: 'Use @riverpod annotation instead of manual providers',
    correctionMessage:
        'Use riverpod_generator with @riverpod annotation. Remove manual StateNotifierProvider or ChangeNotifierProvider.',
  );

  @override
  void runRule(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addVariableDeclaration((node) {
      _checkManualProvider(node, reporter, resolver);
    });
  }

  void _checkManualProvider(
    VariableDeclaration node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    final normalized = filePath.replaceAll('\\', '/').toLowerCase();

    // Only check in presentation/providers directory
    if (!normalized.contains('/presentation/')) return;
    if (!normalized.contains('/providers/') &&
        !normalized.endsWith('_provider.dart')) {
      return;
    }

    final initializer = node.initializer;
    if (initializer == null) return;

    // Only check if initializer is a method invocation (provider creation)
    if (initializer is! MethodInvocation) return;

    final methodName = initializer.methodName.name;

    // Check for manual providers
    final manualProviders = [
      'StateNotifierProvider',
      'ChangeNotifierProvider',
      'StateProvider',
      'FutureProvider',
      'StreamProvider',
    ];

    if (manualProviders.contains(methodName)) {
      final code = LintCode(
        name: 'riverpod_generator',
        problemMessage:
            'Manual provider "$methodName" detected. Use @riverpod annotation instead.',
        correctionMessage:
            'Use riverpod_generator: Create a class with @riverpod annotation instead of manual provider declaration.',
      );
      reporter.atNode(node, code);
    }
  }
}
