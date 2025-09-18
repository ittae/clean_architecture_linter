import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

class PresentationLogicSeparationRule extends DartLintRule {
  const PresentationLogicSeparationRule() : super(code: _code);

  static const _code = LintCode(
    name: 'presentation_logic_separation',
    problemMessage:
        'Presentation logic should be separated from UI components.',
    correctionMessage:
        'Move presentation logic to separate classes like Controllers, ViewModels, or Providers.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((node) {
      _checkPresentationLogicSeparation(node, reporter, resolver);
    });
  }

  void _checkPresentationLogicSeparation(
    ClassDeclaration node,
    DiagnosticReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;

    // Only check files in presentation layer
    if (!_isPresentationLayerFile(filePath)) return;

    final className = node.name.lexeme;

    // Check if this is a UI widget
    if (!_isUIWidget(className, node)) return;

    // Check for presentation logic that should be separated
    final hasComplexPresentationLogic = _hasComplexPresentationLogic(node);

    if (hasComplexPresentationLogic) {
      reporter.atNode(node, _code);
    }
  }

  bool _isPresentationLayerFile(String filePath) {
    return filePath.contains('/presentation/') ||
        filePath.contains('\\presentation\\') ||
        filePath.contains('/ui/') ||
        filePath.contains('\\ui\\') ||
        filePath.contains('/widgets/') ||
        filePath.contains('\\widgets\\');
  }

  bool _isUIWidget(String className, ClassDeclaration node) {
    final extendsClause = node.extendsClause;
    if (extendsClause != null) {
      final superclass = extendsClause.superclass.name.lexeme;
      return superclass == 'StatefulWidget' ||
          superclass == 'StatelessWidget' ||
          superclass.endsWith('Widget');
    }

    return className.endsWith('Widget');
  }

  bool _hasComplexPresentationLogic(ClassDeclaration node) {
    var complexLogicScore = 0;

    for (final member in node.members) {
      if (member is MethodDeclaration && member.name.lexeme != 'build') {
        // Check for validation logic
        if (_hasValidationLogic(member)) {
          complexLogicScore += 2;
        }

        // Check for formatting logic
        if (_hasFormattingLogic(member)) {
          complexLogicScore += 1;
        }

        // Check for calculation logic
        if (_hasCalculationLogic(member)) {
          complexLogicScore += 2;
        }

        // Check for complex conditional logic
        if (_hasComplexConditionalLogic(member)) {
          complexLogicScore += 1;
        }
      }

      // Check for complex field declarations
      if (member is FieldDeclaration) {
        if (_hasComplexFieldLogic(member)) {
          complexLogicScore += 1;
        }
      }
    }

    // If score is high, widget has too much presentation logic
    return complexLogicScore >= 3;
  }

  bool _hasValidationLogic(MethodDeclaration method) {
    final methodName = method.name.lexeme.toLowerCase();
    return methodName.contains('valid') ||
        methodName.contains('check') ||
        methodName.contains('verify');
  }

  bool _hasFormattingLogic(MethodDeclaration method) {
    final methodName = method.name.lexeme.toLowerCase();
    return methodName.contains('format') ||
        methodName.contains('parse') ||
        methodName.contains('convert');
  }

  bool _hasCalculationLogic(MethodDeclaration method) {
    final methodName = method.name.lexeme.toLowerCase();
    return methodName.contains('calculate') ||
        methodName.contains('compute') ||
        methodName.contains('sum') ||
        methodName.contains('total');
  }

  bool _hasComplexConditionalLogic(MethodDeclaration method) {
    var ifStatementCount = 0;
    var switchStatementCount = 0;

    final visitor = _ConditionalLogicVisitor();
    method.accept(visitor);
    ifStatementCount = visitor.ifStatementCount;
    switchStatementCount = visitor.switchStatementCount;

    return ifStatementCount > 2 || switchStatementCount > 0;
  }

  bool _hasComplexFieldLogic(FieldDeclaration field) {
    // Check for computed properties or complex initializers
    for (final variable in field.fields.variables) {
      final initializer = variable.initializer;
      if (initializer != null) {
        // If initializer has method calls or complex expressions, it might be presentation logic
        var hasMethodCalls = false;
        final visitor = _MethodCallVisitor();
        initializer.accept(visitor);
        hasMethodCalls = visitor.hasMethodCalls;
        if (hasMethodCalls) return true;
      }
    }
    return false;
  }
}

class _ConditionalLogicVisitor extends RecursiveAstVisitor<void> {
  int ifStatementCount = 0;
  int switchStatementCount = 0;

  @override
  void visitIfStatement(IfStatement node) {
    ifStatementCount++;
    super.visitIfStatement(node);
  }

  @override
  void visitSwitchStatement(SwitchStatement node) {
    switchStatementCount++;
    super.visitSwitchStatement(node);
  }
}

class _MethodCallVisitor extends RecursiveAstVisitor<void> {
  bool hasMethodCalls = false;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    hasMethodCalls = true;
    super.visitMethodInvocation(node);
  }
}
