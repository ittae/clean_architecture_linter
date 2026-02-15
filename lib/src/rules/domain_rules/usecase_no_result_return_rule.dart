import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../clean_architecture_linter_base.dart';
import '../../mixins/return_type_validation_mixin.dart';

class UseCaseNoResultReturnRule extends CleanArchitectureLintRule
    with ReturnTypeValidationMixin {
  const UseCaseNoResultReturnRule() : super(code: _code);

  static const _code = LintCode(
    name: 'usecase_no_result_return',
    problemMessage:
        'UseCase should NOT return Result/Either. Use pass-through return type.',
    correctionMessage:
        'UseCase는 Future<Entity>를 반환하고, 검증 실패만 AppException으로 throw 하세요.',
  );

  @override
  void runRule(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((node) {
      _checkUseCaseMethod(node, reporter, resolver);
    });
  }

  void _checkUseCaseMethod(
    MethodDeclaration method,
    DiagnosticReporter reporter,
    CustomLintResolver resolver,
  ) {
    final classNode = method.thisOrAncestorOfType<ClassDeclaration>();
    if (classNode == null) return;

    final className = classNode.name.lexeme;
    if (!CleanArchitectureUtils.isUseCaseClass(className)) return;

    if (shouldSkipMethod(method)) return;

    final returnType = method.returnType;
    if (returnType == null) return;

    final unit = method.thisOrAncestorOfType<CompilationUnit>();
    if (isResultReturnType(returnType, unit: unit)) {
      final code = LintCode(
        name: 'usecase_no_result_return',
        problemMessage:
            'UseCase method "${method.name.lexeme}" should NOT return Result/Either (including typedef alias).',
        correctionMessage:
            'pass-through 기준으로 Future<Entity>를 반환하세요. 오류 처리는 Presentation에서 AsyncValue.guard()/when(error)로 처리합니다.',
      );
      reporter.atNode(returnType, code);
    }
  }
}
