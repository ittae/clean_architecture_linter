import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../../clean_architecture_linter_base.dart';
import '../../mixins/exception_validation_mixin.dart';
import '../../mixins/repository_rule_visitor.dart';

/// Validates exception throwing patterns in Repository implementations.
class RepositoryNoThrowRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'repository_no_throw',
    '{0}',
    correctionMessage: '{1}',
    severity: DiagnosticSeverity.INFO,
    uniqueName: 'LintCode.repository_no_throw',
  );

  RepositoryNoThrowRule()
    : super(
        name: 'repository_no_throw',
        description:
            'Warns when repositories throw non-AppException types directly.',
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
    registry.addThrowExpression(this, _RepositoryNoThrowVisitor(this, context));
  }
}

class _RepositoryNoThrowVisitor extends SimpleAstVisitor<void>
    with RepositoryRuleVisitor, ExceptionValidationMixin {
  _RepositoryNoThrowVisitor(this.rule, this.context);

  final AnalysisRule rule;
  final RuleContext context;

  String get _filePath =>
      context.currentUnit?.file.path ?? context.definingUnit.file.path;

  @override
  void visitThrowExpression(ThrowExpression node) {
    final filePath = _filePath;
    if (CleanArchitectureUtils.shouldExcludeFile(filePath)) return;

    final classNode = node.thisOrAncestorOfType<ClassDeclaration>();
    if (classNode == null) return;

    if (!isRepositoryImplementation(classNode)) return;

    if (isAllowedRepositoryThrow(node)) return;

    final thrownExpression = node.expression;
    final thrownTypeName = _getExceptionTypeName(thrownExpression);
    if (thrownTypeName == null) return;

    if (isAppExceptionType(thrownTypeName)) return;
    if (isDataLayerException(thrownTypeName)) return;

    rule.reportAtNode(
      node,
      arguments: [
        'Repository throws non-standard exception type "$thrownTypeName". Consider using AppException types for consistent error handling.',
        'Use AppException types (NotFoundException, ServerException, etc.) or let DataSource handle error conversion.',
      ],
    );
  }

  String? _getExceptionTypeName(Expression expression) {
    if (expression is InstanceCreationExpression) {
      return expression.constructorName.type.name.lexeme;
    }
    if (expression is MethodInvocation) {
      final target = expression.target;
      if (target is SimpleIdentifier) {
        return target.name;
      }
    }
    if (expression is SimpleIdentifier) {
      return expression.name;
    }
    return null;
  }
}
