import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../../clean_architecture_linter_base.dart';
import '../../mixins/exception_validation_mixin.dart';

/// Enforces that DataSource code only throws defined AppException types.
class DataSourceExceptionTypesRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'datasource_exception_types',
    '{0}',
    correctionMessage: '{1}',
    severity: DiagnosticSeverity.WARNING,
    uniqueName: 'LintCode.datasource_exception_types',
  );

  DataSourceExceptionTypesRule()
    : super(
        name: 'datasource_exception_types',
        description:
            'Requires DataSource code to throw AppException/Data layer exceptions.',
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
    registry.addThrowExpression(
      this,
      _DataSourceExceptionTypesVisitor(this, context),
    );
  }
}

class _DataSourceExceptionTypesVisitor extends SimpleAstVisitor<void>
    with ExceptionValidationMixin {
  _DataSourceExceptionTypesVisitor(this.rule, this.context);

  final AnalysisRule rule;
  final RuleContext context;

  @override
  void visitThrowExpression(ThrowExpression node) {
    final filePath =
        context.currentUnit?.file.path ?? context.definingUnit.file.path;
    if (CleanArchitectureUtils.shouldExcludeFile(filePath)) return;

    if (!CleanArchitectureUtils.isDataSourceFile(filePath) &&
        !_isDataSourceClass(node)) {
      return;
    }

    final exceptionType = _exceptionType(node.expression);
    if (exceptionType == null) return;

    if (!isAppExceptionType(exceptionType) &&
        !isDataLayerException(exceptionType)) {
      rule.reportAtNode(
        node.expression,
        arguments: [
          'DataSource should NOT use "$exceptionType". Use AppException types instead.',
          'Use AppException types: NotFoundException, UnauthorizedException, ServerException, NetworkException, etc.',
        ],
      );
    }
  }

  String? _exceptionType(Expression expression) {
    if (expression is InstanceCreationExpression) {
      return expression.constructorName.type.name.lexeme;
    }

    if (expression is SimpleIdentifier) {
      return null;
    }

    return null;
  }

  bool _isDataSourceClass(ThrowExpression node) {
    final classNode = CleanArchitectureUtils.findParentClass(node);
    if (classNode == null) return false;

    return CleanArchitectureUtils.isDataSourceClass(classNode.name.lexeme);
  }
}
