import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../../clean_architecture_linter_base.dart';
import '../../compat/analyzer_ast_compat.dart';
import '../../mixins/return_type_validation_mixin.dart';

/// Prevents DataSource methods from returning Result/Either wrappers.
class DataSourceNoResultReturnRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'datasource_no_result_return',
    '{0}',
    correctionMessage: '{1}',
    severity: DiagnosticSeverity.WARNING,
    uniqueName: 'LintCode.datasource_no_result_return',
  );

  DataSourceNoResultReturnRule()
    : super(
        name: 'datasource_no_result_return',
        description:
            'Requires DataSource methods to return data directly and throw exceptions for errors.',
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
    registry.addMethodDeclaration(
      this,
      _DataSourceNoResultReturnVisitor(this, context),
    );
  }
}

class _DataSourceNoResultReturnVisitor extends SimpleAstVisitor<void>
    with ReturnTypeValidationMixin {
  _DataSourceNoResultReturnVisitor(this.rule, this.context);

  final AnalysisRule rule;
  final RuleContext context;

  @override
  void visitMethodDeclaration(MethodDeclaration method) {
    final filePath =
        context.currentUnit?.file.path ?? context.definingUnit.file.path;
    if (CleanArchitectureUtils.shouldExcludeFile(filePath)) return;

    final classNode = method.thisOrAncestorOfType<ClassDeclaration>();
    if (classNode == null) return;

    final className = classDeclarationName(classNode) ?? '';
    if (!CleanArchitectureUtils.isDataSourceClass(className)) return;

    final returnType = method.returnType;
    if (returnType == null) return;

    final unit = method.thisOrAncestorOfType<CompilationUnit>();
    if (isResultReturnType(returnType, unit: unit)) {
      rule.reportAtNode(
        returnType,
        arguments: [
          'DataSource method "${method.name.lexeme}" should NOT return Result. DataSource should throw exceptions instead.',
          'Remove Result wrapper and throw exceptions for errors:\n'
              '  Before: Future<Result<TodoModel, Failure>> getTodo()\n'
              '  After:  Future<TodoModel> getTodo() // throws AppException\n\n'
              'Exceptions pass through to AsyncValue.guard(). See UNIFIED_ERROR_GUIDE.md',
        ],
      );
    }
  }
}
