import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../../clean_architecture_linter_base.dart';
import '../../mixins/exception_validation_mixin.dart';

/// Enforces that Presentation layer should NOT handle Data layer exceptions.
class PresentationNoDataExceptionsRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'presentation_no_data_exceptions',
    '{0}',
    correctionMessage: '{1}',
    severity: DiagnosticSeverity.WARNING,
    uniqueName: 'LintCode.presentation_no_data_exceptions',
  );

  PresentationNoDataExceptionsRule()
    : super(
        name: 'presentation_no_data_exceptions',
        description:
            'Prevents presentation code from handling data layer exceptions.',
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
    final visitor = _PresentationNoDataExceptionsVisitor(this, context);
    registry.addIsExpression(this, visitor);
    registry.addCatchClause(this, visitor);
  }
}

class _PresentationNoDataExceptionsVisitor extends SimpleAstVisitor<void>
    with ExceptionValidationMixin {
  _PresentationNoDataExceptionsVisitor(this.rule, this.context);

  final AnalysisRule rule;
  final RuleContext context;

  String get _filePath =>
      context.currentUnit?.file.path ?? context.definingUnit.file.path;

  @override
  void visitIsExpression(IsExpression node) {
    if (CleanArchitectureUtils.shouldExcludeFile(_filePath) ||
        !CleanArchitectureUtils.isPresentationFile(_filePath)) {
      return;
    }

    final type = node.type;
    if (type is! NamedType) return;

    final typeName = type.name.lexeme;
    if (!isDataLayerException(typeName)) return;

    final domainException = suggestFeaturePrefix(typeName, _filePath);
    rule.reportAtNode(
      type,
      arguments: [
        'Presentation should NOT handle Data exception "$typeName". Use Domain exception instead.',
        'Replace with Domain exception "$domainException". UseCase should convert Data exceptions.',
      ],
    );
  }

  @override
  void visitCatchClause(CatchClause node) {
    if (CleanArchitectureUtils.shouldExcludeFile(_filePath) ||
        !CleanArchitectureUtils.isPresentationFile(_filePath)) {
      return;
    }

    final type = node.exceptionType;
    if (type == null) return;

    final typeName = type.toSource();
    if (!isDataLayerException(typeName)) return;

    final domainException = suggestFeaturePrefix(typeName, _filePath);
    rule.reportAtNode(
      type,
      arguments: [
        'Presentation should NOT handle Data exception "$typeName". Use Domain exception instead.',
        'Replace with Domain exception "$domainException". UseCase should convert Data exceptions.',
      ],
    );
  }
}
