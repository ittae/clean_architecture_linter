import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../../clean_architecture_linter_base.dart';
import '../../mixins/exception_validation_mixin.dart';

/// Enforces Domain Exception naming convention with feature prefix.
class ExceptionNamingConventionRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'exception_naming_convention',
    'Domain Exception "{0}" should have feature prefix',
    correctionMessage:
        'Rename to "{1}" with feature prefix. Use pattern: {Feature}{ExceptionType}.',
    severity: DiagnosticSeverity.WARNING,
    uniqueName: 'LintCode.exception_naming_convention',
  );

  ExceptionNamingConventionRule()
    : super(
        name: 'exception_naming_convention',
        description:
            'Requires feature-prefixed names for generic domain exceptions.',
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
    registry.addClassDeclaration(
      this,
      _ExceptionNamingConventionVisitor(this, context),
    );
  }
}

class _ExceptionNamingConventionVisitor extends SimpleAstVisitor<void>
    with ExceptionValidationMixin {
  _ExceptionNamingConventionVisitor(this.rule, this.context);

  final AnalysisRule rule;
  final RuleContext context;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final filePath =
        context.currentUnit?.file.path ?? context.definingUnit.file.path;
    if (CleanArchitectureUtils.shouldExcludeFile(filePath)) return;
    if (!CleanArchitectureUtils.isDomainFile(filePath)) return;
    if (filePath.contains('/core/')) return;
    if (!isExceptionClass(node)) return;

    final className = node.namePart.typeName.lexeme;
    if (ExceptionValidationMixin.dartBuiltInExceptions.contains(className)) {
      return;
    }

    if (isGenericExceptionName(className)) {
      final suggestedName = suggestFeaturePrefix(className, filePath);
      rule.reportAtNode(node, arguments: [className, suggestedName]);
    }
  }
}
