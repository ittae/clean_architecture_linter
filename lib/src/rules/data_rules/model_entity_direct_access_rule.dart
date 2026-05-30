import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../../clean_architecture_linter_base.dart';

/// Enforces using toEntity() instead of direct model.entity access.
class ModelEntityDirectAccessRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'model_entity_direct_access',
    '{0}',
    correctionMessage: '{1}',
    severity: DiagnosticSeverity.WARNING,
    uniqueName: 'LintCode.model_entity_direct_access',
  );

  ModelEntityDirectAccessRule()
    : super(
        name: 'model_entity_direct_access',
        description:
            'Prevents direct model.entity access in data layer conversion code.',
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
    final visitor = _ModelEntityDirectAccessVisitor(this, context);
    registry.addPropertyAccess(this, visitor);
    registry.addPrefixedIdentifier(this, visitor);
  }
}

class _ModelEntityDirectAccessVisitor extends SimpleAstVisitor<void> {
  _ModelEntityDirectAccessVisitor(this.rule, this.context);

  final AnalysisRule rule;
  final RuleContext context;

  String get _filePath =>
      context.currentUnit?.file.path ?? context.definingUnit.file.path;

  @override
  void visitPropertyAccess(PropertyAccess node) {
    if (!_shouldCheckFile) return;
    if (node.propertyName.name != 'entity') return;
    if (_isInsideExtension(node)) return;

    _report(node, node.toSource());
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (!_shouldCheckFile) return;
    if (node.identifier.name != 'entity') return;
    if (_isInsideExtension(node)) return;

    _report(node, node.toSource());
  }

  bool get _shouldCheckFile {
    final filePath = _filePath;
    if (CleanArchitectureUtils.shouldExcludeFile(filePath)) return false;
    return CleanArchitectureUtils.isDataFile(filePath);
  }

  bool _isInsideExtension(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is ExtensionDeclaration) return true;
      if (current is ClassDeclaration) return false;
      current = current.parent;
    }
    return false;
  }

  void _report(AstNode node, String accessSource) {
    rule.reportAtNode(
      node,
      arguments: [
        'Direct access to "$accessSource" is not allowed in Data layer. Use the toEntity() extension method instead.',
        'Replace ".entity" with ".toEntity()" to maintain clear conversion boundaries. Example: model.toEntity() instead of model.entity',
      ],
    );
  }
}
