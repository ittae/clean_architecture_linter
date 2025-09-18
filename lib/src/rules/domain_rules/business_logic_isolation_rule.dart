import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

class BusinessLogicIsolationRule extends DartLintRule {
  const BusinessLogicIsolationRule() : super(code: _code);

  static const _code = LintCode(
    name: 'business_logic_isolation',
    problemMessage: 'Business logic should be isolated in domain layer, not in UI components.',
    correctionMessage: 'Move business logic to UseCase or Entity classes in domain layer.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((node) {
      _checkBusinessLogicIsolation(node, reporter, resolver);
    });
  }

  void _checkBusinessLogicIsolation(
    ClassDeclaration node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;

    // Only check files in presentation layer
    if (!_isPresentationLayerFile(filePath)) return;

    final className = node.name.lexeme;

    // Check if this is a UI component
    if (!_isUIComponent(className)) return;

    // Look for complex business logic in UI components
    for (final member in node.members) {
      if (member is MethodDeclaration) {
        final body = member.body;
        if (body is BlockFunctionBody) {
          final hasComplexLogic = _hasComplexBusinessLogic(body);
          if (hasComplexLogic) {
            reporter.atNode(member, _code);
          }
        }
      }
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

  bool _isUIComponent(String className) {
    return className.endsWith('Widget') ||
           className.endsWith('Page') ||
           className.endsWith('Screen') ||
           className.endsWith('View');
  }

  bool _hasComplexBusinessLogic(BlockFunctionBody body) {
    final visitor = _ComplexityVisitor();
    body.accept(visitor);
    return visitor.ifCount > 2 || visitor.loopCount > 1;
  }
}

class _ComplexityVisitor extends RecursiveAstVisitor<void> {
  int ifCount = 0;
  int loopCount = 0;

  @override
  void visitIfStatement(IfStatement node) {
    ifCount++;
    super.visitIfStatement(node);
  }

  @override
  void visitForStatement(ForStatement node) {
    loopCount++;
    super.visitForStatement(node);
  }

  @override
  void visitWhileStatement(WhileStatement node) {
    loopCount++;
    super.visitWhileStatement(node);
  }

  @override
  void visitDoStatement(DoStatement node) {
    loopCount++;
    super.visitDoStatement(node);
  }
}