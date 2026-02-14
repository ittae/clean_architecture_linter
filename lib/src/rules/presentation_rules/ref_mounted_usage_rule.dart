import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../clean_architecture_linter_base.dart';

/// Detects usage of `ref.mounted` in Riverpod providers.
///
/// Using `ref.mounted` to guard async operations is a sign of architectural
/// issues, not a proper solution. If a provider gets disposed during async
/// operations, the root cause should be addressed instead.
///
/// **Why this is problematic:**
/// - `ref.mounted` masks the underlying design problem
/// - Provider disposal during async work indicates improper lifecycle management
/// - The real fix is usually restructuring the async flow
///
/// **Correct solutions:**
/// 1. Complete async work BEFORE screen transition
/// 2. Call UseCase directly then navigate (let new screen's provider load state)
/// 3. Use `ref.onDispose` to cancel pending work if truly needed
///
/// ❌ Wrong Pattern:
/// ```dart
/// Future<void> doSomething() async {
///   await someAsyncWork();
///   if (!ref.mounted) return;  // ❌ Hiding the problem
///   state = newState;
/// }
/// ```
///
/// ✅ Correct Pattern:
/// ```dart
/// // In the calling widget/page:
/// await useCase.call();  // Complete work first
/// context.push('/next');  // Then navigate
/// // New screen's provider loads state in build()
/// ```
class RefMountedUsageRule extends CleanArchitectureLintRule {
  const RefMountedUsageRule() : super(code: _code);

  static const _code = LintCode(
    name: 'ref_mounted_usage',
    problemMessage:
        'Avoid using "ref.mounted" to guard async operations. This masks design problems.',
    correctionMessage:
        'Instead: (1) Complete async work before navigation, or (2) Call UseCase directly then navigate - new screen\'s provider will load state.',
  );

  @override
  void runRule(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Check for ref.mounted property access
    context.registry.addPrefixedIdentifier((node) {
      _checkRefMounted(node, reporter, resolver);
    });

    // Check for !ref.mounted pattern
    context.registry.addPrefixExpression((node) {
      _checkNegatedRefMounted(node, reporter, resolver);
    });
  }

  void _checkRefMounted(
    PrefixedIdentifier node,
    DiagnosticReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    final normalized = filePath.replaceAll('\\', '/').toLowerCase();

    // Only check in presentation layer (providers)
    if (!normalized.contains('/presentation/') &&
        !normalized.contains('/providers/')) {
      return;
    }

    // Check for ref.mounted pattern
    final prefix = node.prefix.name;
    final identifier = node.identifier.name;

    if (prefix == 'ref' && identifier == 'mounted') {
      reporter.atNode(node, code);
    }
  }

  void _checkNegatedRefMounted(
    PrefixExpression node,
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

    // Check for !ref.mounted pattern
    if (node.operator.lexeme == '!' && node.operand is PrefixedIdentifier) {
      final operand = node.operand as PrefixedIdentifier;
      final prefix = operand.prefix.name;
      final identifier = operand.identifier.name;

      if (prefix == 'ref' && identifier == 'mounted') {
        reporter.atNode(node, code);
      }
    }
  }
}
