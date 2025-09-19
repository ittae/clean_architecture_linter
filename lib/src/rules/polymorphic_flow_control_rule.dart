import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Validates polymorphic patterns for flow control inversion.
///
/// Uncle Bob: "We take advantage of dynamic polymorphism to create source code
/// dependencies that oppose the flow of control so that we can conform to The
/// Dependency Rule no matter what direction the flow of control is going in."
///
/// This rule ensures:
/// - Dynamic polymorphism is used to invert control flow
/// - Source code dependencies oppose the flow of control
/// - Abstract base classes and interfaces enable inversion
/// - Concrete implementations are injected, not directly instantiated
/// - Factory patterns are used where appropriate
/// - Strategy pattern enables flexible control flow
///
/// Key patterns validated:
/// - Use Case → Output Port Interface ← Presenter (polymorphic call)
/// - Controller → Use Case Interface ← Use Case Implementation
/// - Domain → Repository Interface ← Repository Implementation
/// - Abstract Factory patterns for object creation
class PolymorphicFlowControlRule extends DartLintRule {
  const PolymorphicFlowControlRule() : super(code: _code);

  static const _code = LintCode(
    name: 'polymorphic_flow_control',
    problemMessage:
        'Polymorphic flow control violation: {0}',
    correctionMessage:
        'Use dynamic polymorphism to invert source code dependencies.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((node) {
      _analyzePolymorphicCall(node, reporter, resolver);
    });

    context.registry.addInstanceCreationExpression((node) {
      _analyzeObjectCreation(node, reporter, resolver);
    });

    context.registry.addClassDeclaration((node) {
      _analyzePolymorphicDesign(node, reporter, resolver);
    });

    context.registry.addMethodDeclaration((node) {
      _analyzeMethodPolymorphism(node, reporter, resolver);
    });
  }

  void _analyzePolymorphicCall(
    MethodInvocation node,
    DiagnosticReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    final layer = _detectLayer(filePath);
    if (layer == null) return;

    final methodName = node.methodName.name;
    final target = node.target;

    if (target != null) {
      _validatePolymorphicInvocation(node, reporter, layer, methodName, target);
    }
  }

  void _analyzeObjectCreation(
    InstanceCreationExpression node,
    DiagnosticReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    final layer = _detectLayer(filePath);
    if (layer == null) return;

    final typeName = node.constructorName.type.name.lexeme;
    _validateObjectCreationPattern(node, reporter, layer, typeName);
  }

  void _analyzePolymorphicDesign(
    ClassDeclaration node,
    DiagnosticReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    final className = node.name.lexeme;
    final layer = _detectLayer(filePath);

    if (layer == null) return;

    _validateClassPolymorphicCapabilities(node, reporter, layer, className);
    _validateInversionOpportunities(node, reporter, layer, className);
  }

  void _analyzeMethodPolymorphism(
    MethodDeclaration method,
    DiagnosticReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    final layer = _detectLayer(filePath);
    if (layer == null) return;

    final methodName = method.name.lexeme;
    _validateMethodPolymorphicPattern(method, reporter, layer, methodName);
  }

  void _validatePolymorphicInvocation(
    MethodInvocation node,
    DiagnosticReporter reporter,
    ArchitecturalLayer layer,
    String methodName,
    Expression target,
  ) {
    final targetString = target.toString();

    // Check for direct concrete class method calls that should be polymorphic
    if (_isDirectConcreteCall(targetString, layer)) {
      final code = LintCode(
        name: 'polymorphic_flow_control',
        problemMessage:
            'Direct call to concrete class instead of polymorphic interface: $methodName on $targetString',
        correctionMessage:
            'Call through interface or abstract base class to enable polymorphism.',
      );
      reporter.atNode(node, code);
    }

    // Validate boundary crossing patterns
    _validateBoundaryPolymorphism(node, reporter, layer, methodName, targetString);

    // Check for missing polymorphic opportunities
    _checkMissedPolymorphicOpportunities(node, reporter, layer, methodName, targetString);
  }

  void _validateObjectCreationPattern(
    InstanceCreationExpression node,
    DiagnosticReporter reporter,
    ArchitecturalLayer layer,
    String typeName,
  ) {
    // Check for direct instantiation where factory should be used
    if (_shouldUseFactory(layer, typeName)) {
      final code = LintCode(
        name: 'polymorphic_flow_control',
        problemMessage:
            'Direct instantiation of $typeName in ${layer.name} layer should use factory pattern',
        correctionMessage:
            'Use abstract factory or factory method to enable polymorphic object creation.',
      );
      reporter.atNode(node, code);
    }

    // Check for boundary violations in object creation
    _validateCreationBoundary(node, reporter, layer, typeName);

    // Check for strategy pattern opportunities
    _checkStrategyPatternOpportunity(node, reporter, layer, typeName);
  }

  void _validateClassPolymorphicCapabilities(
    ClassDeclaration node,
    DiagnosticReporter reporter,
    ArchitecturalLayer layer,
    String className,
  ) {
    // Check if class should be abstract for polymorphism
    if (_shouldBeAbstractForPolymorphism(node, layer, className)) {
      final code = LintCode(
        name: 'polymorphic_flow_control',
        problemMessage:
            'Class $className should be abstract to enable proper polymorphism',
        correctionMessage:
            'Make class abstract and define interface for implementations.',
      );
      reporter.atNode(node, code);
    }

    // Check for missing virtual methods
    _validateVirtualMethods(node, reporter, className);

    // Check inheritance hierarchy for inversion
    _validateInheritanceInversion(node, reporter, layer, className);
  }

  void _validateInversionOpportunities(
    ClassDeclaration node,
    DiagnosticReporter reporter,
    ArchitecturalLayer layer,
    String className,
  ) {
    // Look for methods that could benefit from inversion
    for (final member in node.members) {
      if (member is MethodDeclaration) {
        _checkMethodInversionOpportunity(member, reporter, layer, className);
      }
    }

    // Check for dependency injection opportunities
    _checkDependencyInjectionOpportunities(node, reporter, layer, className);
  }

  void _validateMethodPolymorphicPattern(
    MethodDeclaration method,
    DiagnosticReporter reporter,
    ArchitecturalLayer layer,
    String methodName,
  ) {
    // Check for type checking instead of polymorphism
    _checkTypeCheckingAntiPattern(method, reporter, methodName);

    // Check for switch statements that could be polymorphic
    _checkSwitchStatementOpportunity(method, reporter, methodName);

    // Validate parameter polymorphism
    _validateParameterPolymorphism(method, reporter, layer, methodName);
  }

  void _validateBoundaryPolymorphism(
    MethodInvocation node,
    DiagnosticReporter reporter,
    ArchitecturalLayer layer,
    String methodName,
    String targetString,
  ) {
    switch (layer.name) {
      case 'use_case':
        _validateUseCasePolymorphism(node, reporter, methodName, targetString);
        break;
      case 'controller':
        _validateControllerPolymorphism(node, reporter, methodName, targetString);
        break;
      case 'domain':
        _validateDomainPolymorphism(node, reporter, methodName, targetString);
        break;
    }
  }

  void _validateUseCasePolymorphism(
    MethodInvocation node,
    DiagnosticReporter reporter,
    String methodName,
    String targetString,
  ) {
    // Use case calling presenter directly instead of through output port
    if (_isDirectPresenterCall(targetString)) {
      final code = LintCode(
        name: 'polymorphic_flow_control',
        problemMessage:
            'Use case directly calls presenter method $methodName instead of using polymorphic output port',
        correctionMessage:
            'Define output port interface and call polymorphically.',
      );
      reporter.atNode(node, code);
    }

    // Use case calling repository implementation instead of interface
    if (_isDirectRepositoryCall(targetString)) {
      final code = LintCode(
        name: 'polymorphic_flow_control',
        problemMessage:
            'Use case directly calls repository implementation instead of interface',
        correctionMessage:
            'Call through repository interface for polymorphic behavior.',
      );
      reporter.atNode(node, code);
    }
  }

  void _validateControllerPolymorphism(
    MethodInvocation node,
    DiagnosticReporter reporter,
    String methodName,
    String targetString,
  ) {
    // Controller calling use case implementation instead of interface
    if (_isDirectUseCaseCall(targetString)) {
      final code = LintCode(
        name: 'polymorphic_flow_control',
        problemMessage:
            'Controller directly calls use case implementation instead of interface',
        correctionMessage:
            'Define use case interface for polymorphic invocation.',
      );
      reporter.atNode(node, code);
    }
  }

  void _validateDomainPolymorphism(
    MethodInvocation node,
    DiagnosticReporter reporter,
    String methodName,
    String targetString,
  ) {
    // Domain calling infrastructure directly
    if (_isInfrastructureCall(targetString)) {
      final code = LintCode(
        name: 'polymorphic_flow_control',
        problemMessage:
            'Domain layer directly calls infrastructure instead of using polymorphic interface',
        correctionMessage:
            'Define interface in domain and call polymorphically.',
      );
      reporter.atNode(node, code);
    }
  }

  void _validateCreationBoundary(
    InstanceCreationExpression node,
    DiagnosticReporter reporter,
    ArchitecturalLayer layer,
    String typeName,
  ) {
    final targetLayer = _inferLayerFromType(typeName);

    if (targetLayer != null && _violatesCreationBoundary(layer, targetLayer)) {
      final code = LintCode(
        name: 'polymorphic_flow_control',
        problemMessage:
            '${layer.name} layer directly instantiates ${targetLayer.name} layer class: $typeName',
        correctionMessage:
            'Use factory or dependency injection to maintain boundary separation.',
      );
      reporter.atNode(node, code);
    }
  }

  void _checkStrategyPatternOpportunity(
    InstanceCreationExpression node,
    DiagnosticReporter reporter,
    ArchitecturalLayer layer,
    String typeName,
  ) {
    // Check if creation indicates strategy pattern opportunity
    if (_indicatesStrategyPattern(typeName) && !_usesStrategyPattern(node)) {
      final code = LintCode(
        name: 'polymorphic_flow_control',
        problemMessage:
            'Direct instantiation of $typeName suggests strategy pattern opportunity',
        correctionMessage:
            'Consider using strategy pattern for polymorphic behavior.',
      );
      reporter.atNode(node, code);
    }
  }

  void _validateVirtualMethods(
    ClassDeclaration node,
    DiagnosticReporter reporter,
    String className,
  ) {
    // Check for methods that should be virtual (overridable)
    final methods = node.members.whereType<MethodDeclaration>();

    for (final method in methods) {
      if (_shouldBeVirtual(method) && !_isVirtual(method)) {
        final code = LintCode(
          name: 'polymorphic_flow_control',
          problemMessage:
              'Method ${method.name.lexeme} in $className should be virtual for polymorphism',
          correctionMessage:
              'Make method abstract or overridable to enable polymorphic behavior.',
        );
        reporter.atNode(method, code);
      }
    }
  }

  void _validateInheritanceInversion(
    ClassDeclaration node,
    DiagnosticReporter reporter,
    ArchitecturalLayer layer,
    String className,
  ) {
    final extendsClause = node.extendsClause;
    if (extendsClause != null) {
      final superClassName = extendsClause.superclass.name.lexeme;
      final superLayer = _inferLayerFromType(superClassName);

      if (superLayer != null && !_isValidInheritanceDirection(layer, superLayer)) {
        final code = LintCode(
          name: 'polymorphic_flow_control',
          problemMessage:
              '$className extends class from wrong layer: $superClassName',
          correctionMessage:
              'Inheritance should follow dependency rule - inner extends outer abstractions.',
        );
        reporter.atNode(extendsClause, code);
      }
    }
  }

  void _checkMethodInversionOpportunity(
    MethodDeclaration method,
    DiagnosticReporter reporter,
    ArchitecturalLayer layer,
    String className,
  ) {
    final methodName = method.name.lexeme;

    // Check for callback opportunities
    if (_couldUseCallback(method) && !_usesCallback(method)) {
      final code = LintCode(
        name: 'polymorphic_flow_control',
        problemMessage:
            'Method $methodName in $className could use callback for inversion of control',
        correctionMessage:
            'Consider using callback or strategy parameter to invert control flow.',
      );
      reporter.atNode(method, code);
    }
  }

  void _checkDependencyInjectionOpportunities(
    ClassDeclaration node,
    DiagnosticReporter reporter,
    ArchitecturalLayer layer,
    String className,
  ) {
    // Check for hard-coded dependencies that should be injected
    for (final member in node.members) {
      if (member is MethodDeclaration) {
        _checkMethodDependencyInjection(member, reporter, className);
      }
    }
  }

  void _checkTypeCheckingAntiPattern(
    MethodDeclaration method,
    DiagnosticReporter reporter,
    String methodName,
  ) {
    final body = method.body;
    final bodyString = body.toString();

    // Check for type checking patterns
    if (_containsTypeChecking(bodyString)) {
      final code = LintCode(
        name: 'polymorphic_flow_control',
        problemMessage:
            'Method $methodName uses type checking instead of polymorphism',
        correctionMessage:
            'Replace type checking with polymorphic method calls.',
      );
      reporter.atNode(method, code);
    }
  }

  void _checkSwitchStatementOpportunity(
    MethodDeclaration method,
    DiagnosticReporter reporter,
    String methodName,
  ) {
    final body = method.body;
    // Look for switch statements that could be replaced with polymorphism
    body.visitChildren(SwitchStatementVisitor(reporter, methodName));
  }

  void _validateParameterPolymorphism(
    MethodDeclaration method,
    DiagnosticReporter reporter,
    ArchitecturalLayer layer,
    String methodName,
  ) {
    final parameters = method.parameters?.parameters ?? [];

    for (final param in parameters) {
      if (param is SimpleFormalParameter) {
        final type = param.type;
        if (type is NamedType) {
          final typeName = type.name.lexeme;

          if (_isConcreteType(typeName) && _shouldBeAbstract(typeName, layer)) {
            final code = LintCode(
              name: 'polymorphic_flow_control',
              problemMessage:
                  'Method $methodName parameter should accept abstract type instead of concrete $typeName',
              correctionMessage:
                  'Use interface or abstract base class for polymorphic parameter.',
            );
            reporter.atNode(param, code);
          }
        }
      }
    }
  }

  void _checkMethodDependencyInjection(
    MethodDeclaration method,
    DiagnosticReporter reporter,
    String className,
  ) {
    final body = method.body;
    final bodyString = body.toString();

    // Check for new keyword indicating hard-coded dependencies
    if (_containsHardCodedDependencies(bodyString)) {
      final code = LintCode(
        name: 'polymorphic_flow_control',
        problemMessage:
            'Method ${method.name.lexeme} in $className has hard-coded dependencies',
        correctionMessage:
            'Use dependency injection to enable polymorphic substitution.',
      );
      reporter.atNode(method, code);
    }
  }

  // Helper methods for pattern detection
  ArchitecturalLayer? _detectLayer(String filePath) {
    if (filePath.contains('/domain/')) return ArchitecturalLayer('domain', 4);
    if (filePath.contains('/usecases/')) return ArchitecturalLayer('use_case', 3);
    if (filePath.contains('/controllers/')) return ArchitecturalLayer('controller', 2);
    if (filePath.contains('/presenters/')) return ArchitecturalLayer('presenter', 2);
    if (filePath.contains('/infrastructure/')) return ArchitecturalLayer('infrastructure', 1);
    return null;
  }

  ArchitecturalLayer? _inferLayerFromType(String typeName) {
    if (_isDomainType(typeName)) return ArchitecturalLayer('domain', 4);
    if (_isUseCaseType(typeName)) return ArchitecturalLayer('use_case', 3);
    if (_isControllerType(typeName)) return ArchitecturalLayer('controller', 2);
    if (_isPresenterType(typeName)) return ArchitecturalLayer('presenter', 2);
    if (_isInfrastructureType(typeName)) return ArchitecturalLayer('infrastructure', 1);
    return null;
  }

  bool _isDirectConcreteCall(String targetString, ArchitecturalLayer layer) {
    return targetString.contains('Impl') ||
           targetString.contains('Concrete') ||
           (targetString.contains('Repository') && !targetString.startsWith('I'));
  }

  bool _shouldUseFactory(ArchitecturalLayer layer, String typeName) {
    // Inner layers should not directly instantiate outer layer types
    final targetLayer = _inferLayerFromType(typeName);
    return targetLayer != null && layer.level > targetLayer.level;
  }

  bool _shouldBeAbstractForPolymorphism(ClassDeclaration node, ArchitecturalLayer layer, String className) {
    // Check if class has multiple implementations or serves as base
    return _hasMultipleSubclasses(className) ||
           _servesAsInterface(node) ||
           _isStrategyBase(className);
  }

  bool _violatesCreationBoundary(ArchitecturalLayer creator, ArchitecturalLayer created) {
    return creator.level > created.level;
  }

  bool _indicatesStrategyPattern(String typeName) {
    final strategyIndicators = [
      'Strategy', 'Algorithm', 'Handler', 'Processor', 'Calculator'
    ];
    return strategyIndicators.any((indicator) => typeName.contains(indicator));
  }

  bool _usesStrategyPattern(InstanceCreationExpression node) {
    // Simple heuristic: check if parent context suggests strategy pattern
    AstNode? parent = node.parent;
    while (parent != null) {
      if (parent is VariableDeclaration) {
        final type = parent.parent;
        if (type is VariableDeclarationList) {
          final typeName = type.type?.toString() ?? '';
          return _isAbstractType(typeName);
        }
      }
      parent = parent.parent;
    }
    return false;
  }

  bool _shouldBeVirtual(MethodDeclaration method) {
    final methodName = method.name.lexeme;
    final virtualCandidates = [
      'process', 'handle', 'execute', 'calculate', 'validate'
    ];
    return virtualCandidates.any((candidate) => methodName.toLowerCase().contains(candidate));
  }

  bool _isVirtual(MethodDeclaration method) {
    return method.isAbstract ||
           method.parent is ClassDeclaration && (method.parent as ClassDeclaration).abstractKeyword != null;
  }

  bool _isValidInheritanceDirection(ArchitecturalLayer child, ArchitecturalLayer parent) {
    // Child layer level should be <= parent layer level (inner can extend outer abstractions)
    return child.level <= parent.level;
  }

  bool _couldUseCallback(MethodDeclaration method) {
    final methodName = method.name.lexeme;
    return methodName.contains('process') || methodName.contains('handle');
  }

  bool _usesCallback(MethodDeclaration method) {
    final parameters = method.parameters?.parameters ?? [];
    return parameters.any((param) {
      if (param is SimpleFormalParameter) {
        final type = param.type;
        return type.toString().contains('Function') || type.toString().contains('Callback');
      }
      return false;
    });
  }

  bool _containsTypeChecking(String bodyString) {
    final typeCheckPatterns = [
      'is ', 'as ', 'runtimeType', 'type ==', 'instanceof'
    ];
    return typeCheckPatterns.any((pattern) => bodyString.contains(pattern));
  }

  bool _isConcreteType(String typeName) {
    return !_isAbstractType(typeName);
  }

  bool _isAbstractType(String typeName) {
    return typeName.startsWith('I') ||
           typeName.contains('Interface') ||
           typeName.contains('Abstract') ||
           typeName.contains('Base');
  }

  bool _shouldBeAbstract(String typeName, ArchitecturalLayer layer) {
    return layer.level > 2 && !_isAbstractType(typeName);
  }

  bool _containsHardCodedDependencies(String bodyString) {
    return bodyString.contains('new ') && !bodyString.contains('List(') && !bodyString.contains('Map(');
  }

  // Type classification helpers
  bool _isDomainType(String typeName) {
    return typeName.contains('Entity') || typeName.contains('ValueObject');
  }

  bool _isUseCaseType(String typeName) {
    return typeName.contains('UseCase') || typeName.contains('Interactor');
  }

  bool _isControllerType(String typeName) {
    return typeName.contains('Controller');
  }

  bool _isPresenterType(String typeName) {
    return typeName.contains('Presenter');
  }

  bool _isInfrastructureType(String typeName) {
    return typeName.contains('Repository') && typeName.contains('Impl') ||
           typeName.contains('Database') ||
           typeName.contains('Http');
  }

  bool _isDirectPresenterCall(String target) {
    return target.contains('presenter') && !target.contains('I');
  }

  bool _isDirectRepositoryCall(String target) {
    return target.contains('repository') && target.contains('Impl');
  }

  bool _isDirectUseCaseCall(String target) {
    return target.contains('useCase') && !target.contains('I');
  }

  bool _isInfrastructureCall(String target) {
    return target.contains('database') || target.contains('http');
  }

  // Additional helper methods
  bool _hasMultipleSubclasses(String className) {
    // This would require cross-file analysis
    return false; // Simplified for now
  }

  bool _servesAsInterface(ClassDeclaration node) {
    return node.abstractKeyword != null;
  }

  bool _isStrategyBase(String className) {
    return className.contains('Strategy') || className.contains('Algorithm');
  }

  void _checkMissedPolymorphicOpportunities(
    MethodInvocation node,
    DiagnosticReporter reporter,
    ArchitecturalLayer layer,
    String methodName,
    String targetString,
  ) {
    // Check for missed opportunities to use polymorphism
    if (_couldBenefitFromPolymorphism(targetString, methodName)) {
      final code = LintCode(
        name: 'polymorphic_flow_control',
        problemMessage:
            'Method call $methodName could benefit from polymorphic design',
        correctionMessage:
            'Consider using polymorphic interface instead of direct method call.',
      );
      reporter.atNode(node, code);
    }
  }

  bool _couldBenefitFromPolymorphism(String target, String methodName) {
    // Simple heuristic for polymorphism opportunities
    return target.contains('Impl') ||
           target.contains('Concrete') ||
           methodName.contains('switch') ||
           methodName.contains('if');
  }
}

class SwitchStatementVisitor extends RecursiveAstVisitor<void> {
  final DiagnosticReporter reporter;
  final String methodName;

  SwitchStatementVisitor(this.reporter, this.methodName);

  @override
  void visitSwitchStatement(SwitchStatement node) {
    final code = LintCode(
      name: 'polymorphic_flow_control',
      problemMessage:
          'Switch statement in $methodName could be replaced with polymorphism',
      correctionMessage:
          'Consider using polymorphic method dispatch instead of switch statement.',
    );
    reporter.atNode(node, code);
    super.visitSwitchStatement(node);
  }
}

class ArchitecturalLayer {
  final String name;
  final int level;

  ArchitecturalLayer(this.name, this.level);
}