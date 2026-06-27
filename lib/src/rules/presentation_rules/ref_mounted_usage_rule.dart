import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../../clean_architecture_linter_base.dart';

/// Detects usage of `ref.mounted` in Riverpod providers.
class RefMountedUsageRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'ref_mounted_usage',
    'Avoid "ref.mounted" in widgets/pages. State-lifecycle checks belong in the Notifier, not the UI.',
    correctionMessage:
        'Render state with ref.watch and delegate mutations to Notifier methods (ref.mounted is the correct post-await guard there). For widget-local async, use context.mounted.',
    severity: DiagnosticSeverity.INFO,
    uniqueName: 'LintCode.ref_mounted_usage',
  );

  RefMountedUsageRule()
    : super(
        name: 'ref_mounted_usage',
        description:
            'Disallows ref.mounted in the UI layer (widgets/pages); it is allowed in Notifiers/providers.',
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
    final visitor = _RefMountedUsageVisitor(this, context);
    registry.addPrefixedIdentifier(this, visitor);
    registry.addPrefixExpression(this, visitor);
  }
}

class _RefMountedUsageVisitor extends SimpleAstVisitor<void> {
  _RefMountedUsageVisitor(this.rule, this.context);

  final AnalysisRule rule;
  final RuleContext context;

  String get _filePath =>
      context.currentUnit?.file.path ?? context.definingUnit.file.path;

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (!_shouldCheckFile) return;

    final parent = node.parent;
    if (parent is PrefixExpression &&
        parent.operator.lexeme == '!' &&
        parent.operand == node &&
        node.prefix.name == 'ref' &&
        node.identifier.name == 'mounted') {
      return;
    }

    if (node.prefix.name == 'ref' && node.identifier.name == 'mounted') {
      rule.reportAtNode(node);
    }
  }

  @override
  void visitPrefixExpression(PrefixExpression node) {
    if (!_shouldCheckFile) return;

    if (node.operator.lexeme == '!' && node.operand is PrefixedIdentifier) {
      final operand = node.operand as PrefixedIdentifier;
      if (operand.prefix.name == 'ref' &&
          operand.identifier.name == 'mounted') {
        rule.reportAtNode(node);
      }
    }
  }

  bool get _shouldCheckFile {
    if (CleanArchitectureUtils.shouldExcludeFile(_filePath)) return false;

    final normalized = _filePath.replaceAll('\\', '/').toLowerCase();
    // UI 레이어(위젯/페이지)에서만 금지한다. Notifier/provider(상태 레이어)에서는
    // ref.mounted가 await-후 dispose 가드로 정당하므로 검사 대상에서 제외한다.
    return normalized.contains('/presentation/') &&
        !normalized.contains('/providers/');
  }
}
