import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../clean_architecture_linter_base.dart';

/// Enforces Failure naming convention with feature prefix.
///
/// Failure classes in Data layer should include feature-specific prefixes.
/// Pattern: {Feature}Failure
///
/// ✅ Correct: TodoFailure, UserFailure, OrderFailure
/// ❌ Wrong: Failure, DataFailure, CustomFailure
class FailureNamingConventionRule extends CleanArchitectureLintRule {
  const FailureNamingConventionRule() : super(code: _code);

  static const _code = LintCode(
    name: 'failure_naming_convention',
    problemMessage: 'Failure should have feature prefix: {Feature}Failure',
    correctionMessage: 'Add feature prefix:\\n'
        '  ❌ Bad:  class Failure\\n'
        '  ✅ Good: class TodoFailure',
  );

  @override
  void runRule(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((node) {
      final className = node.name.lexeme;

      // Check if it's a Failure class
      if (className == 'Failure' ||
          (className.endsWith('Failure') && className.length < 12)) {
        final filePath = resolver.path;

        // Skip /core/ directory - core failures don't need feature prefix
        if (filePath.contains('/core/')) {
          return;
        }

        if (filePath.contains('/data/') || filePath.contains('/domain/')) {
          reporter.atNode(node, _code);
        }
      }
    });
  }
}
