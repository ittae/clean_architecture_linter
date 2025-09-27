import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Enforces strict separation between business logic and presentation layer.
///
/// This rule ensures that business logic remains isolated in the domain layer:
/// - UI components should only handle presentation concerns
/// - Business logic should be delegated to UseCases
/// - No direct repository calls from UI components
/// - No complex calculations or validations in UI
/// - State management should not contain business rules
///
/// Benefits of business logic isolation:
/// - Better testability of business rules
/// - UI components become simpler and more focused
/// - Business logic can be reused across different UIs
/// - Easier to maintain and modify business rules
/// - Clear separation of concerns
class BusinessLogicIsolationRule extends DartLintRule {
  const BusinessLogicIsolationRule() : super(code: _code);

  static const _code = LintCode(
    name: 'business_logic_isolation',
    problemMessage: 'Business logic must be isolated in domain layer, not mixed with UI components.',
    correctionMessage:
        'Move business logic to UseCases, Entities, or domain services. Keep UI components focused on presentation.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    // Check class declarations for business logic in UI components
    context.registry.addClassDeclaration((node) {
      _checkBusinessLogicIsolation(node, reporter, resolver);
    });

    // Check method invocations for direct repository/UseCase calls
    context.registry.addMethodInvocation((node) {
      _checkDirectBusinessLogicCalls(node, reporter, resolver);
    });

    // Check field declarations for business logic dependencies
    context.registry.addFieldDeclaration((node) {
      _checkBusinessLogicDependencies(node, reporter, resolver);
    });

    // Check variable declarations for business logic computations
    context.registry.addVariableDeclaration((node) {
      _checkBusinessLogicComputations(node, reporter, resolver);
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

    // Analyze the UI component for business logic violations
    final analysis = _analyzeUIComponent(node);

    // Check for various types of business logic violations
    _checkComplexBusinessLogic(analysis, reporter);
    _checkValidationLogic(analysis, reporter);
    _checkCalculationLogic(analysis, reporter);
    _checkDataTransformation(analysis, reporter);
    _checkStateManagementLogic(analysis, reporter);
  }

  void _checkDirectBusinessLogicCalls(
    MethodInvocation node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    if (!_isPresentationLayerFile(filePath)) return;

    final methodName = node.methodName.name;
    final target = node.target;

    // Check for direct repository calls
    if (_isRepositoryCall(methodName, target)) {
      final code = LintCode(
        name: 'business_logic_isolation',
        problemMessage: 'Direct repository call detected in UI component: $methodName',
        correctionMessage:
            'Use UseCases or state management to handle data operations instead of direct repository calls.',
      );
      reporter.atNode(node, code);
    }

    // Check for direct UseCase calls in build methods or event handlers
    if (_isUseCaseCall(methodName, target) && _isInInappropriateContext(node)) {
      final code = LintCode(
        name: 'business_logic_isolation',
        problemMessage: 'UseCase called directly in UI context: $methodName',
        correctionMessage: 'Handle UseCase calls through proper state management or event handlers.',
      );
      reporter.atNode(node, code);
    }
  }

  void _checkBusinessLogicDependencies(
    FieldDeclaration node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    if (!_isPresentationLayerFile(filePath)) return;

    final type = node.fields.type;
    if (type is NamedType) {
      final typeName = type.name2.lexeme;

      // Check for direct repository dependencies
      if (_isRepositoryType(typeName)) {
        final code = LintCode(
          name: 'business_logic_isolation',
          problemMessage: 'Direct repository dependency in UI component: $typeName',
          correctionMessage:
              'Remove direct repository dependencies. Use state management or dependency injection patterns.',
        );
        reporter.atNode(type, code);
      }

      // Check for domain service dependencies
      if (_isDomainServiceType(typeName)) {
        final code = LintCode(
          name: 'business_logic_isolation',
          problemMessage: 'Domain service dependency in UI component: $typeName',
          correctionMessage:
              'UI components should not depend directly on domain services. Use proper architectural patterns.',
        );
        reporter.atNode(type, code);
      }
    }
  }

  void _checkBusinessLogicComputations(
    VariableDeclaration node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    if (!_isPresentationLayerFile(filePath)) return;

    final initializer = node.initializer;
    if (initializer != null) {
      // Check for complex calculations in variable initialization
      final hasComplexCalculation = _hasComplexCalculation(initializer);
      if (hasComplexCalculation) {
        final code = LintCode(
          name: 'business_logic_isolation',
          problemMessage: 'Complex business calculation detected in UI component',
          correctionMessage: 'Move calculations to domain layer and provide computed values to UI.',
        );
        reporter.atNode(initializer, code);
      }
    }
  }

  UIComponentAnalysis _analyzeUIComponent(ClassDeclaration node) {
    final methods = <MethodDeclaration>[];
    final fields = <FieldDeclaration>[];

    for (final member in node.members) {
      if (member is MethodDeclaration) {
        methods.add(member);
      } else if (member is FieldDeclaration) {
        fields.add(member);
      }
    }

    return UIComponentAnalysis(
      className: node.name.lexeme,
      methods: methods,
      fields: fields,
    );
  }

  void _checkComplexBusinessLogic(
    UIComponentAnalysis analysis,
    ErrorReporter reporter,
  ) {
    for (final method in analysis.methods) {
      final body = method.body;
      if (body is BlockFunctionBody) {
        final complexity = _calculateBusinessLogicComplexity(body);
        if (complexity.hasComplexBusinessLogic) {
          final code = LintCode(
            name: 'business_logic_isolation',
            problemMessage: 'Complex business logic detected in UI method: ${method.name.lexeme}',
            correctionMessage: 'Extract business logic to domain layer UseCases or services.',
          );
          reporter.atNode(method, code);
        }
      }
    }
  }

  void _checkValidationLogic(
    UIComponentAnalysis analysis,
    ErrorReporter reporter,
  ) {
    for (final method in analysis.methods) {
      if (_hasValidationLogic(method)) {
        final code = LintCode(
          name: 'business_logic_isolation',
          problemMessage: 'Business validation logic in UI component: ${method.name.lexeme}',
          correctionMessage: 'Move validation logic to domain entities or validation services.',
        );
        reporter.atNode(method, code);
      }
    }
  }

  void _checkCalculationLogic(
    UIComponentAnalysis analysis,
    ErrorReporter reporter,
  ) {
    for (final method in analysis.methods) {
      if (_hasCalculationLogic(method)) {
        final code = LintCode(
          name: 'business_logic_isolation',
          problemMessage: 'Business calculation logic in UI component: ${method.name.lexeme}',
          correctionMessage: 'Move calculation logic to domain layer and provide computed values.',
        );
        reporter.atNode(method, code);
      }
    }
  }

  void _checkDataTransformation(
    UIComponentAnalysis analysis,
    ErrorReporter reporter,
  ) {
    for (final method in analysis.methods) {
      if (_hasDataTransformation(method)) {
        final code = LintCode(
          name: 'business_logic_isolation',
          problemMessage: 'Data transformation logic in UI component: ${method.name.lexeme}',
          correctionMessage: 'Move data transformation to domain layer or use proper data mapping patterns.',
        );
        reporter.atNode(method, code);
      }
    }
  }

  void _checkStateManagementLogic(
    UIComponentAnalysis analysis,
    ErrorReporter reporter,
  ) {
    for (final method in analysis.methods) {
      if (_hasComplexStateLogic(method)) {
        final code = LintCode(
          name: 'business_logic_isolation',
          problemMessage: 'Complex state management logic in UI component: ${method.name.lexeme}',
          correctionMessage: 'Move complex state logic to dedicated state management classes or UseCases.',
        );
        reporter.atNode(method, code);
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
        className.endsWith('View') ||
        className.endsWith('Component');
  }

  bool _isRepositoryCall(String methodName, Expression? target) {
    // Check method names that suggest repository operations
    final repositoryMethods = [
      'save',
      'create',
      'update',
      'delete',
      'find',
      'get',
      'fetch',
      'load',
      'store',
      'persist',
      'remove',
    ];

    return repositoryMethods.any(
          (method) => methodName.toLowerCase().contains(method),
        ) ||
        (target != null && _isRepositoryTarget(target));
  }

  bool _isRepositoryTarget(Expression target) {
    if (target is SimpleIdentifier) {
      final name = target.name.toLowerCase();
      return name.contains('repository') || name.contains('repo');
    }
    return false;
  }

  bool _isUseCaseCall(String methodName, Expression? target) {
    return methodName == 'call' || methodName == 'execute' || (target != null && _isUseCaseTarget(target));
  }

  bool _isUseCaseTarget(Expression target) {
    if (target is SimpleIdentifier) {
      final name = target.name.toLowerCase();
      return name.contains('usecase') || name.contains('use_case');
    }
    return false;
  }

  bool _isInInappropriateContext(MethodInvocation node) {
    // Check if the call is within a build method or similar UI context
    var parent = node.parent;
    while (parent != null) {
      if (parent is MethodDeclaration) {
        final methodName = parent.name.lexeme;
        return methodName == 'build' || methodName.startsWith('build');
      }
      parent = parent.parent;
    }
    return false;
  }

  bool _isRepositoryType(String typeName) {
    return typeName.endsWith('Repository') || typeName.contains('Repository');
  }

  bool _isDomainServiceType(String typeName) {
    final domainServicePatterns = [
      'Service',
      'UseCase',
      'DomainService',
      'BusinessService',
    ];
    return domainServicePatterns.any((pattern) => typeName.contains(pattern));
  }

  bool _hasComplexCalculation(Expression expression) {
    final visitor = _CalculationVisitor();
    expression.accept(visitor);
    return visitor.hasComplexCalculation;
  }

  BusinessLogicComplexity _calculateBusinessLogicComplexity(
    BlockFunctionBody body,
  ) {
    final visitor = _BusinessLogicComplexityVisitor();
    body.accept(visitor);
    return BusinessLogicComplexity(
      conditionalComplexity: visitor.ifCount,
      loopComplexity: visitor.loopCount,
      methodCallComplexity: visitor.methodCallCount,
      hasComplexBusinessLogic: visitor.ifCount > 3 || visitor.loopCount > 1 || visitor.methodCallCount > 5,
    );
  }

  bool _hasValidationLogic(MethodDeclaration method) {
    final methodName = method.name.lexeme.toLowerCase();
    final validationPatterns = [
      'validate',
      'check',
      'verify',
      'ensure',
      'assert',
    ];

    // Check method name
    if (validationPatterns.any((pattern) => methodName.contains(pattern))) {
      return true;
    }

    // Check method body for validation patterns
    final visitor = _ValidationLogicVisitor();
    method.accept(visitor);
    return visitor.hasValidationLogic;
  }

  bool _hasCalculationLogic(MethodDeclaration method) {
    final methodName = method.name.lexeme.toLowerCase();
    final calculationPatterns = [
      'calculate',
      'compute',
      'sum',
      'total',
      'average',
      'count',
    ];

    if (calculationPatterns.any((pattern) => methodName.contains(pattern))) {
      return true;
    }

    final visitor = _CalculationLogicVisitor();
    method.accept(visitor);
    return visitor.hasCalculationLogic;
  }

  bool _hasDataTransformation(MethodDeclaration method) {
    final methodName = method.name.lexeme.toLowerCase();
    final transformationPatterns = [
      'transform',
      'convert',
      'map',
      'parse',
      'format',
      'serialize',
    ];

    if (transformationPatterns.any((pattern) => methodName.contains(pattern))) {
      return true;
    }

    final visitor = _DataTransformationVisitor();
    method.accept(visitor);
    return visitor.hasDataTransformation;
  }

  bool _hasComplexStateLogic(MethodDeclaration method) {
    final visitor = _StateLogicVisitor();
    method.accept(visitor);
    return visitor.hasComplexStateLogic;
  }
}

/// Analysis result for UI component structure
class UIComponentAnalysis {
  final String className;
  final List<MethodDeclaration> methods;
  final List<FieldDeclaration> fields;

  const UIComponentAnalysis({
    required this.className,
    required this.methods,
    required this.fields,
  });
}

/// Business logic complexity analysis
class BusinessLogicComplexity {
  final int conditionalComplexity;
  final int loopComplexity;
  final int methodCallComplexity;
  final bool hasComplexBusinessLogic;

  const BusinessLogicComplexity({
    required this.conditionalComplexity,
    required this.loopComplexity,
    required this.methodCallComplexity,
    required this.hasComplexBusinessLogic,
  });
}

// Visitor classes for different types of analysis
class _BusinessLogicComplexityVisitor extends RecursiveAstVisitor<void> {
  int ifCount = 0;
  int loopCount = 0;
  int methodCallCount = 0;

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

  @override
  void visitMethodInvocation(MethodInvocation node) {
    methodCallCount++;
    super.visitMethodInvocation(node);
  }
}

class _ValidationLogicVisitor extends RecursiveAstVisitor<void> {
  bool hasValidationLogic = false;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final methodName = node.methodName.name.toLowerCase();
    final validationMethods = [
      'isvalid',
      'validate',
      'check',
      'verify',
      'ensure',
    ];

    if (validationMethods.any((method) => methodName.contains(method))) {
      hasValidationLogic = true;
    }

    super.visitMethodInvocation(node);
  }

  @override
  void visitIfStatement(IfStatement node) {
    // Check for validation patterns in conditions
    final condition = node.expression.toString().toLowerCase();
    if (condition.contains('valid') || condition.contains('check')) {
      hasValidationLogic = true;
    }
    super.visitIfStatement(node);
  }
}

class _CalculationLogicVisitor extends RecursiveAstVisitor<void> {
  bool hasCalculationLogic = false;

  @override
  void visitBinaryExpression(BinaryExpression node) {
    // Check for arithmetic operations
    final operator = node.operator.lexeme;
    if (['+', '-', '*', '/', '%'].contains(operator)) {
      hasCalculationLogic = true;
    }
    super.visitBinaryExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final methodName = node.methodName.name.toLowerCase();
    final calculationMethods = [
      'sum',
      'total',
      'average',
      'calculate',
      'compute',
    ];

    if (calculationMethods.any((method) => methodName.contains(method))) {
      hasCalculationLogic = true;
    }

    super.visitMethodInvocation(node);
  }
}

class _DataTransformationVisitor extends RecursiveAstVisitor<void> {
  bool hasDataTransformation = false;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final methodName = node.methodName.name.toLowerCase();
    final transformationMethods = [
      'map',
      'transform',
      'convert',
      'parse',
      'format',
      'serialize',
    ];

    if (transformationMethods.any((method) => methodName.contains(method))) {
      hasDataTransformation = true;
    }

    super.visitMethodInvocation(node);
  }
}

class _StateLogicVisitor extends RecursiveAstVisitor<void> {
  bool hasComplexStateLogic = false;
  int stateModificationCount = 0;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final methodName = node.methodName.name.toLowerCase();
    final stateModificationMethods = [
      'setstate',
      'notifylisteners',
      'emit',
      'add',
      'sink',
    ];

    if (stateModificationMethods.any((method) => methodName.contains(method))) {
      stateModificationCount++;
    }

    if (stateModificationCount > 2) {
      hasComplexStateLogic = true;
    }

    super.visitMethodInvocation(node);
  }
}

class _CalculationVisitor extends RecursiveAstVisitor<void> {
  bool hasComplexCalculation = false;
  int arithmeticOperationCount = 0;

  @override
  void visitBinaryExpression(BinaryExpression node) {
    final operator = node.operator.lexeme;
    if (['+', '-', '*', '/', '%'].contains(operator)) {
      arithmeticOperationCount++;
    }

    if (arithmeticOperationCount > 3) {
      hasComplexCalculation = true;
    }

    super.visitBinaryExpression(node);
  }
}
