import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../../clean_architecture_linter_base.dart';
import '../../compat/analyzer_ast_compat.dart';

/// Enforces that `ref.read()` should NOT be followed by AsyncValue-style
/// branching (`.when` / `.maybeWhen` / `.map` / …).
///
/// Freezed/sealed Result snapshot handlers after a one-shot `ref.read` are
/// intentional and are **not** reported: only calls that look like Riverpod
/// `AsyncValue` lifecycle branching (`data` / `loading` / `error` named args)
/// are flagged. Parsed-only path — no type resolution required.
class WidgetRefReadThenWhenRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'widget_ref_read_then_when',
    '{0}',
    correctionMessage: '{1}',
    severity: DiagnosticSeverity.WARNING,
    uniqueName: 'LintCode.widget_ref_read_then_when',
  );

  /// Riverpod `AsyncValue` branch methods that rebuild-unsafe after `ref.read`.
  static const Set<String> asyncValueBranchMethods = {
    'when',
    'maybeWhen',
    'map',
    'maybeMap',
    'whenOrNull',
    'mapOrNull',
  };

  /// Named args that mark an AsyncValue-style branch (vs Freezed case names).
  static const Set<String> asyncValueBranchArgs = {'data', 'loading', 'error'};

  WidgetRefReadThenWhenRule()
    : super(
        name: 'widget_ref_read_then_when',
        description:
            'Prevents AsyncValue-style .when/.map after ref.read() in widgets.',
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
    final branchCalls = <MethodInvocation>[];
    final variableAssignments = <String, MethodInvocation>{};

    _collectNodes(functionBody, refReadCalls, branchCalls, variableAssignments);
    if (refReadCalls.isEmpty || branchCalls.isEmpty) return;

    for (final branchCall in branchCalls) {
      if (!_isAsyncValueStyleBranch(branchCall)) continue;
      if (_isBranchCalledOnRefRead(
        branchCall,
        refReadCalls,
        variableAssignments,
      )) {
        final method = branchCall.methodName.name;
        rule.reportAtNode(
          branchCall,
          arguments: [
            'Anti-pattern: Using AsyncValue.$method() after ref.read() '
                'in the same function',
            'Use ref.watch() + .$method() in build() for UI, ref.listen() '
                'for side effects, or try-catch for one-off operations. '
                'Freezed/sealed Result snapshot branching after a one-shot ref.read is allowed.',
          ],
        );
      }
    }
  }

  void _collectNodes(
    AstNode node,
    List<MethodInvocation> refReadCalls,
    List<MethodInvocation> branchCalls,
    Map<String, MethodInvocation> variableAssignments,
  ) {
    if (node is MethodInvocation) {
      if (node.methodName.name == 'read') {
        final target = node.target;
        if (target is SimpleIdentifier && target.name == 'ref') {
          refReadCalls.add(node);
        }
      }
      if (WidgetRefReadThenWhenRule.asyncValueBranchMethods.contains(
        node.methodName.name,
      )) {
        branchCalls.add(node);
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
        _collectNodes(child, refReadCalls, branchCalls, variableAssignments);
      }
    }
  }

  /// True when named args look like Riverpod AsyncValue lifecycle branching.
  ///
  /// Freezed/sealed Result handlers use custom case names (`success`,
  /// `failure`, …) and therefore do not match.
  bool _isAsyncValueStyleBranch(MethodInvocation call) {
    for (final arg in call.argumentList.arguments) {
      final name = namedArgumentName(arg);
      if (name != null &&
          WidgetRefReadThenWhenRule.asyncValueBranchArgs.contains(name)) {
        return true;
      }
    }
    return false;
  }

  bool _isBranchCalledOnRefRead(
    MethodInvocation branchCall,
    List<MethodInvocation> refReadCalls,
    Map<String, MethodInvocation> variableAssignments,
  ) {
    final target = branchCall.target;

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
