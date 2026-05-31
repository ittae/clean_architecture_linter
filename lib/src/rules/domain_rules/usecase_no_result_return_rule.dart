import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../../clean_architecture_linter_base.dart';
import '../../mixins/return_type_validation_mixin.dart';

class UseCaseNoResultReturnRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'usecase_no_result_return',
    'UseCase method "{0}" should NOT return Result/Either (including typedef alias).',
    correctionMessage:
        'pass-through 기준으로 Future<Entity>를 반환하세요. 오류 처리는 Presentation에서 AsyncValue.guard()/when(error)로 처리합니다.',
    severity: DiagnosticSeverity.WARNING,
    uniqueName: 'LintCode.usecase_no_result_return',
  );

  UseCaseNoResultReturnRule()
    : super(
        name: 'usecase_no_result_return',
        description:
            'Prevents UseCase methods from returning Result/Either wrappers.',
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
      _UseCaseNoResultReturnVisitor(this, context),
    );
  }
}

class _UseCaseNoResultReturnVisitor extends SimpleAstVisitor<void>
    with ReturnTypeValidationMixin {
  _UseCaseNoResultReturnVisitor(this.rule, this.context);

  final AnalysisRule rule;
  final RuleContext context;

  @override
  void visitMethodDeclaration(MethodDeclaration method) {
    final filePath =
        context.currentUnit?.file.path ?? context.definingUnit.file.path;
    if (CleanArchitectureUtils.shouldExcludeFile(filePath)) return;

    final classNode = method.thisOrAncestorOfType<ClassDeclaration>();
    if (classNode == null) return;

    final className = classNode.namePart.typeName.lexeme;
    if (!CleanArchitectureUtils.isUseCaseClass(className)) return;

    if (shouldSkipMethod(method)) return;

    final returnType = method.returnType;
    if (returnType == null) return;

    final unit = method.thisOrAncestorOfType<CompilationUnit>();
    if (isResultReturnType(returnType, unit: unit)) {
      rule.reportAtNode(returnType, arguments: [method.name.lexeme]);
    }
  }
}
