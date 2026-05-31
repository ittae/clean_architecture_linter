import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../../clean_architecture_linter_base.dart';

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

    final initializer = node.initializer;
    if (initializer is! MethodInvocation) return;

    final methodName = initializer.methodName.name;
    const manualProviders = {
      'StateNotifierProvider',
      'ChangeNotifierProvider',
      'StateProvider',
      'FutureProvider',
      'StreamProvider',
    };

    if (manualProviders.contains(methodName)) {
      rule.reportAtNode(
        node,
        arguments: [
          'Manual provider "$methodName" detected. Use @riverpod annotation instead.',
          'Use riverpod_generator: Create a class with @riverpod annotation instead of manual provider declaration.',
        ],
      );
    }
  }

  bool _isProviderFile(String filePath) {
    if (CleanArchitectureUtils.shouldExcludeFile(filePath)) return false;

    final normalized = filePath.replaceAll('\\', '/').toLowerCase();
    if (!normalized.contains('/presentation/')) return false;
    return normalized.contains('/providers/') ||
        normalized.endsWith('_provider.dart');
  }
}
