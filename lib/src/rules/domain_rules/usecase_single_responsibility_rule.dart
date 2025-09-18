import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

class UseCaseSingleResponsibilityRule extends DartLintRule {
  const UseCaseSingleResponsibilityRule() : super(code: _code);

  static const _code = LintCode(
    name: 'usecase_single_responsibility',
    problemMessage: 'UseCase should have a single call() or execute() method.',
    correctionMessage: 'Remove extra public methods from UseCase. Keep only call() or execute().',
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((node) {
      _checkUseCaseResponsibility(node, reporter, resolver);
    });
  }

  void _checkUseCaseResponsibility(
    ClassDeclaration node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;

    // Only check files in domain layer
    if (!_isDomainLayerFile(filePath)) return;

    final className = node.name.lexeme;

    // Check if this is a UseCase class
    if (!_isUseCaseClass(className, filePath)) return;

    final publicMethods = <MethodDeclaration>[];

    for (final member in node.members) {
      if (member is MethodDeclaration &&
          !member.name.lexeme.startsWith('_') &&
          !member.isGetter &&
          !member.isSetter &&
          !member.isStatic) {
        publicMethods.add(member);
      }
    }

    // Check if there's exactly one call() or execute() method
    final mainMethods = publicMethods.where((method) {
      final name = method.name.lexeme;
      return name == 'call' || name == 'execute';
    }).toList();

    if (mainMethods.length != 1) {
      // Report error on extra public methods
      for (final method in publicMethods) {
        final name = method.name.lexeme;
        if (name != 'call' && name != 'execute') {
          reporter.atNode(method, _code);
        }
      }
    }
  }

  bool _isDomainLayerFile(String filePath) {
    return filePath.contains('/domain/') ||
           filePath.contains('\\domain\\');
  }

  bool _isUseCaseClass(String className, String filePath) {
    return className.endsWith('UseCase') ||
           className.endsWith('Usecase') ||
           filePath.contains('/usecases/') ||
           filePath.contains('\\usecases\\');
  }
}