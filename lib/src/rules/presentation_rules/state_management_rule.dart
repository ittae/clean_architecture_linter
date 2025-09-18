import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

class StateManagementRule extends DartLintRule {
  const StateManagementRule() : super(code: _code);

  static const _code = LintCode(
    name: 'state_management_pattern',
    problemMessage:
        'State management should follow proper architectural patterns.',
    correctionMessage:
        'Use proper state management patterns like Provider, Riverpod, or Bloc instead of direct state manipulation.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((node) {
      _checkStateManagementPattern(node, reporter, resolver);
    });
  }

  void _checkStateManagementPattern(
    ClassDeclaration node,
    DiagnosticReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;

    // Only check files in presentation layer
    if (!_isPresentationLayerFile(filePath)) return;

    final className = node.name.lexeme;

    // Check if this is a widget class
    if (!_isWidgetClass(className, node)) return;

    // Check for improper state management patterns
    final hasImproperStateManagement = _hasImproperStateManagement(node);

    if (hasImproperStateManagement) {
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

  bool _isWidgetClass(String className, ClassDeclaration node) {
    // Check if extends StatefulWidget or StatelessWidget
    final extendsClause = node.extendsClause;
    if (extendsClause != null) {
      final superclass = extendsClause.superclass.name.lexeme;
      return superclass == 'StatefulWidget' ||
          superclass == 'StatelessWidget' ||
          superclass.endsWith('Widget');
    }

    return className.endsWith('Widget') ||
        className.endsWith('Page') ||
        className.endsWith('Screen');
  }

  bool _hasImproperStateManagement(ClassDeclaration node) {
    // Check for direct business logic calls without proper state management
    for (final member in node.members) {
      if (member is MethodDeclaration) {
        final methodName = member.name.lexeme;

        // Check for build method with complex business logic
        if (methodName == 'build') {
          if (_hasBusinessLogicInBuildMethod(member)) {
            return true;
          }
        }

        // Check for event handlers with direct repository/usecase calls
        if (_isEventHandler(methodName) &&
            _hasDirectBusinessLogicCalls(member)) {
          return true;
        }
      }
    }

    return false;
  }

  bool _hasBusinessLogicInBuildMethod(MethodDeclaration method) {
    final visitor = _BusinessLogicVisitor();
    method.accept(visitor);
    return visitor.hasBusinessLogic;
  }

  bool _isEventHandler(String methodName) {
    return methodName.startsWith('on') ||
        methodName.startsWith('handle') ||
        methodName.contains('Pressed') ||
        methodName.contains('Tapped') ||
        methodName.contains('Changed');
  }

  bool _hasDirectBusinessLogicCalls(MethodDeclaration method) {
    final visitor = _BusinessLogicVisitor();
    method.accept(visitor);
    return visitor.hasBusinessLogic;
  }
}

class _BusinessLogicVisitor extends RecursiveAstVisitor<void> {
  bool hasBusinessLogic = false;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final methodName = node.methodName.name;
    if (_isBusinessLogicMethod(methodName)) {
      hasBusinessLogic = true;
    }
    super.visitMethodInvocation(node);
  }

  bool _isBusinessLogicMethod(String methodName) {
    final businessLogicMethods = [
      'save',
      'update',
      'delete',
      'create',
      'fetch',
      'load',
      'post',
      'get',
      'put',
      'patch',
    ];

    return businessLogicMethods.any(
      (method) => methodName.toLowerCase().contains(method),
    );
  }
}
