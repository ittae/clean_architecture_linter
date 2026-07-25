import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../../clean_architecture_linter_base.dart';
import '../../utils/riverpod_provider_detector.dart';

/// Enforces riverpod_generator usage for state management.
class RiverpodGeneratorRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'riverpod_generator',
    '{0}',
    correctionMessage: '{1}',
    severity: DiagnosticSeverity.INFO,
    uniqueName: 'LintCode.riverpod_generator',
  );

  RiverpodGeneratorRule()
    : super(
        name: 'riverpod_generator',
        description: 'Requires @riverpod instead of manual providers.',
      );

  @override
  bool get canUseParsedResult => true;

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addVariableDeclaration(
      this,
      _RiverpodGeneratorVisitor(this, context),
    );
  }
}

class _RiverpodGeneratorVisitor extends SimpleAstVisitor<void> {
  _RiverpodGeneratorVisitor(this.rule, this.context);

  final AnalysisRule rule;
  final RuleContext context;

  String get _filePath =>
      context.currentUnit?.file.path ?? context.definingUnit.file.path;

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    if (!_isProviderFile(_filePath)) return;

    final providerName = _manualProviderName(node.initializer);
    if (providerName == null) return;

    rule.reportAtNode(
      node,
      arguments: [
        'Manual provider "$providerName" detected. Use @riverpod annotation instead.',
        'Use riverpod_generator: Create a class with @riverpod annotation instead of manual provider declaration.',
      ],
    );
  }

  /// Returns the manual Riverpod provider name that [initializer] declares, or
  /// `null` when it is not a manual provider.
  ///
  /// Handles both the fixture form where the provider reads as a
  /// [MethodInvocation] and the real Riverpod 3 form where a constructor with
  /// type arguments — `NotifierProvider<TodoNotifier, TodoState>(...)` — parses
  /// as an [InstanceCreationExpression].
  String? _manualProviderName(Expression? initializer) {
    if (initializer is MethodInvocation) {
      final name = initializer.methodName.name;
      return isManualRiverpodProviderConstructor(name) ? name : null;
    }

    if (initializer is InstanceCreationExpression) {
      final name = initializer.constructorName.type.name.lexeme;
      return isManualRiverpodProviderConstructor(name) ? name : null;
    }

    return null;
  }

  bool _isProviderFile(String filePath) {
    if (CleanArchitectureUtils.shouldExcludeFile(filePath)) return false;

    final normalized = filePath.replaceAll('\\', '/').toLowerCase();
    if (!normalized.contains('/presentation/')) return false;
    return normalized.contains('/providers/') ||
        normalized.endsWith('_provider.dart');
  }
}
