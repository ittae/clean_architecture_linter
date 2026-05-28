import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

class PresentationNoThrowRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'presentation_no_throw',
    'Presentation layer should not throw exceptions directly.',
    correctionMessage:
        'Return AsyncValue.error or wrap the body with AsyncValue.guard instead.',
    severity: DiagnosticSeverity.WARNING,
    uniqueName: 'LintCode.presentation_no_throw',
  );

  PresentationNoThrowRule()
    : super(
        name: 'presentation_no_throw',
        description: 'Prevents direct throw expressions in presentation code.',
      );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final path = context.definingUnit.file.path.replaceAll('\\', '/');
    if (!path.contains('/presentation/')) {
      return;
    }

    registry.addThrowExpression(this, _ThrowVisitor(this));
  }
}

class _ThrowVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;

  _ThrowVisitor(this.rule);

  @override
  void visitThrowExpression(ThrowExpression node) {
    if (_isInsideAsyncValueGuard(node)) {
      return;
    }

    rule.reportAtNode(node);
  }

  bool _isInsideAsyncValueGuard(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is MethodInvocation &&
          current.methodName.name == 'guard' &&
          current.target is SimpleIdentifier &&
          (current.target as SimpleIdentifier).name == 'AsyncValue') {
        return true;
      }
      current = current.parent;
    }
    return false;
  }
}
