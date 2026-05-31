import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../../clean_architecture_linter_base.dart';

/// Enforces that `ref.read()` should NOT be followed by `.when()`.
class WidgetRefReadThenWhenRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'widget_ref_read_then_when',
    '{0}',
    correctionMessage: '{1}',
    severity: DiagnosticSeverity.WARNING,
    uniqueName: 'LintCode.widget_ref_read_then_when',
  );

  WidgetRefReadThenWhenRule()
    : super(
        name: 'widget_ref_read_then_when',
        description: 'Prevents .when() on values read via ref.read().',
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
    final visitor = _WidgetRefReadThenWhenVisitor(this, context);
    registry.addMethodDeclaration(this, visitor);
    registry.addFunctionExpression(this, visitor);
  }
}

class _WidgetRefReadThenWhenVisitor extends SimpleAstVisitor<void> {
  _WidgetRefReadThenWhenVisitor(this.rule, this.context);

  final AnalysisRule rule;
  final RuleContext context;

  String get _filePath =>
      context.currentUnit?.file.path ?? context.definingUnit.file.path;

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (!_isWidgetOrPageFile(_filePath)) return;
    final body = node.body;
    if (body is! BlockFunctionBody) return;

    _checkFunctionForAntiPattern(body.block);
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    if (!_isWidgetOrPageFile(_filePath)) return;
    _checkFunctionForAntiPattern(node.body);
  }

  void _checkFunctionForAntiPattern(AstNode functionBody) {
    final refReadCalls = <MethodInvocation>[];
    final whenCalls = <MethodInvocation>[];
    final variableAssignments = <String, MethodInvocation>{};

    _collectNodes(functionBody, refReadCalls, whenCalls, variableAssignments);
    if (refReadCalls.isEmpty || whenCalls.isEmpty) return;

    for (final whenCall in whenCalls) {
      if (_isWhenCalledOnRefRead(whenCall, refReadCalls, variableAssignments)) {
        rule.reportAtNode(
          whenCall,
          arguments: const [
            'Anti-pattern: Using .when() after ref.read() in the same function',
            'Use ref.watch() + .when() in build() for UI, ref.listen() for side effects, or try-catch for one-off operations.',
          ],
        );
      }
    }
  }

  void _collectNodes(
    AstNode node,
    List<MethodInvocation> refReadCalls,
    List<MethodInvocation> whenCalls,
    Map<String, MethodInvocation> variableAssignments,
  ) {
    if (node is MethodInvocation) {
      if (node.methodName.name == 'read') {
        final target = node.target;
        if (target is SimpleIdentifier && target.name == 'ref') {
          refReadCalls.add(node);
        }
      }
      if (node.methodName.name == 'when') {
        whenCalls.add(node);
      }
    } else if (node is VariableDeclaration) {
      final initializer = node.initializer;
      if (initializer is MethodInvocation) {
        variableAssignments[node.name.lexeme] = initializer;
      }
    } else if (node is AssignmentExpression) {
      final leftHandSide = node.leftHandSide;
      final rightHandSide = node.rightHandSide;
      if (leftHandSide is SimpleIdentifier &&
          rightHandSide is MethodInvocation) {
        variableAssignments[leftHandSide.name] = rightHandSide;
      }
    }

    for (final child in node.childEntities) {
      if (child is AstNode) {
        _collectNodes(child, refReadCalls, whenCalls, variableAssignments);
      }
    }
  }

  bool _isWhenCalledOnRefRead(
    MethodInvocation whenCall,
    List<MethodInvocation> refReadCalls,
    Map<String, MethodInvocation> variableAssignments,
  ) {
    final target = whenCall.target;

    if (target is MethodInvocation && _isRefRead(target)) return true;

    if (target is SimpleIdentifier) {
      final varName = target.name;
      final assignment = variableAssignments[varName];
      if (assignment != null && _isRefRead(assignment)) return true;

      for (final refRead in refReadCalls) {
        final parent = refRead.parent;
        if (parent is VariableDeclaration && parent.name.lexeme == varName) {
          return true;
        }
        if (parent is AssignmentExpression) {
          final leftHandSide = parent.leftHandSide;
          if (leftHandSide is SimpleIdentifier &&
              leftHandSide.name == varName) {
            return true;
          }
        }
      }
    }

    return false;
  }

  bool _isRefRead(MethodInvocation node) {
    if (node.methodName.name != 'read') return false;

    final target = node.target;
    return target is SimpleIdentifier && target.name == 'ref';
  }

  bool _isWidgetOrPageFile(String filePath) {
    if (CleanArchitectureUtils.shouldExcludeFile(filePath)) return false;

    final normalizedPath = filePath.replaceAll('\\', '/').toLowerCase();
    if (!normalizedPath.contains('/presentation/')) return false;

    return normalizedPath.contains('/widgets/') ||
        normalizedPath.contains('/pages/') ||
        normalizedPath.contains('/screens/') ||
        normalizedPath.contains('/views/') ||
        normalizedPath.endsWith('_page.dart') ||
        normalizedPath.endsWith('_screen.dart') ||
        normalizedPath.endsWith('_view.dart') ||
        normalizedPath.endsWith('_widget.dart');
  }
}
