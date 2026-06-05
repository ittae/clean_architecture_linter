import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../../clean_architecture_linter_base.dart';

/// Enforces extensions in the same file as the class they extend.
class ExtensionLocationRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'extension_location',
    '{0}',
    correctionMessage: '{1}',
    severity: DiagnosticSeverity.INFO,
    uniqueName: 'LintCode.extension_location',
  );

  ExtensionLocationRule()
    : super(
        name: 'extension_location',
        description: 'Requires extensions to live with the class they extend.',
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
    final visitor = _ExtensionLocationVisitor(this, context);
    registry.addCompilationUnit(this, visitor);
    registry.addExtensionDeclaration(this, visitor);
  }
}

class _ExtensionLocationVisitor extends SimpleAstVisitor<void> {
  _ExtensionLocationVisitor(this.rule, this.context);

  final AnalysisRule rule;
  final RuleContext context;

  String get _filePath =>
      context.currentUnit?.file.path ?? context.definingUnit.file.path;

  @override
  void visitCompilationUnit(CompilationUnit node) {
    if (CleanArchitectureUtils.shouldExcludeFile(_filePath)) return;

    final normalized = _filePath.replaceAll('\\', '/').toLowerCase();
    const forbiddenPaths = [
      '/domain/extensions/',
      '/data/extensions/',
      '/presentation/extensions/',
      '/presentation/ui/',
    ];

    for (final forbidden in forbiddenPaths) {
      if (normalized.contains(forbidden)) {
        final layerName = _getLayerName(forbidden);
        rule.reportAtOffset(
          0,
          1,
          arguments: [
            'Extension directory is not allowed: $forbidden',
            'Move extensions to the $layerName file. Extensions should be in the same file as the class they extend.',
          ],
        );
        return;
      }
    }
  }

  @override
  void visitExtensionDeclaration(ExtensionDeclaration node) {
    if (CleanArchitectureUtils.shouldExcludeFile(_filePath)) return;

    final normalized = _filePath.replaceAll('\\', '/').toLowerCase();
    if (!normalized.contains('/presentation/')) return;

    if (normalized.contains('/states/') || normalized.endsWith('_state.dart')) {
      return;
    }

    final extendedType = node.onClause?.extendedType;
    if (extendedType == null) return;

    if (normalized.contains('/widgets/') ||
        normalized.contains('/pages/') ||
        normalized.contains('/screens/') ||
        normalized.endsWith('_widget.dart') ||
        normalized.endsWith('_page.dart') ||
        normalized.endsWith('_screen.dart')) {
      rule.reportAtNode(
        node,
        arguments: const [
          'Entity UI extensions are not allowed in widget/page/screen files',
          'Move entity UI extensions to the State file (e.g., todo_state.dart). Only State files should contain entity UI extensions. Widget files should use the State and its extensions, not define their own.',
        ],
      );
    }
  }

  String _getLayerName(String forbiddenPath) {
    if (forbiddenPath.contains('domain')) {
      return 'entity (e.g., ranking.dart with extension RankingX)';
    } else if (forbiddenPath.contains('data')) {
      return 'model (e.g., ranking_model.dart with extension RankingModelX)';
    } else if (forbiddenPath.contains('presentation')) {
      return 'state or widget (e.g., ranking_state.dart with UI extensions)';
    }
    return 'appropriate';
  }
}
