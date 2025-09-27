import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Validates proper interface usage at architectural boundaries.
///
/// This rule ensures that:
/// - Interfaces are defined at the correct architectural level
/// - Implementations properly implement boundary interfaces
/// - Interface contracts are stable and well-defined
/// - Boundary interfaces follow naming conventions
/// - Output ports, repository interfaces, and gateways are properly structured
///
/// Key boundary interface patterns:
/// - Output Ports: Defined in use case layer, implemented by presenters
/// - Repository Interfaces: Defined in domain layer, implemented in infrastructure
/// - Gateway Interfaces: Defined in application layer, implemented in infrastructure
/// - Controller Interfaces: For testability and flexibility
class InterfaceBoundaryRule extends DartLintRule {
  const InterfaceBoundaryRule() : super(code: _code);

  static const _code = LintCode(
    name: 'interface_boundary',
    problemMessage: 'Interface boundary violation: {0}',
    correctionMessage: 'Ensure interfaces are properly defined and implemented at architectural boundaries.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((node) {
      _analyzeInterfaceBoundary(node, reporter, resolver);
    });

    context.registry.addMethodDeclaration((node) {
      _analyzeInterfaceMethod(node, reporter, resolver);
    });
  }

  void _analyzeInterfaceBoundary(
    ClassDeclaration node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    final className = node.name.lexeme;
    final layer = _detectLayer(filePath);

    if (layer == null) return;

    // Check if this is an interface
    if (_isInterface(node, className)) {
      _validateInterfaceDefinition(node, reporter, layer, className);
      _validateInterfaceLocation(node, reporter, layer, className);
      _validateInterfaceContract(node, reporter, className);
    }

    // Check if this implements boundary interfaces
    if (_implementsBoundaryInterface(node)) {
      _validateBoundaryImplementation(node, reporter, layer, className);
    }

    // Check for missing interfaces at boundaries
    _checkMissingBoundaryInterfaces(node, reporter, layer, className);
  }

  void _analyzeInterfaceMethod(
    MethodDeclaration method,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    final layer = _detectLayer(filePath);
    if (layer == null) return;

    // Find parent class
    AstNode? parent = method.parent;
    while (parent != null && parent is! ClassDeclaration) {
      parent = parent.parent;
    }

    if (parent is ClassDeclaration) {
      final className = parent.name.lexeme;

      if (_isInterface(parent, className)) {
        _validateInterfaceMethodSignature(method, reporter, layer, className);
      }
    }
  }

  void _validateInterfaceDefinition(
    ClassDeclaration node,
    ErrorReporter reporter,
    ArchitecturalLayer layer,
    String className,
  ) {
    // Check interface naming conventions
    _validateInterfaceNaming(node, reporter, layer, className);

    // Check interface completeness
    _validateInterfaceCompleteness(node, reporter, className);

    // Check for implementation details in interface
    _validateInterfacePurity(node, reporter, className);
  }

  void _validateInterfaceLocation(
    ClassDeclaration node,
    ErrorReporter reporter,
    ArchitecturalLayer layer,
    String className,
  ) {
    final interfaceType = _classifyInterface(className);

    switch (interfaceType) {
      case InterfaceType.outputPort:
        if (layer.name != 'use_case' && layer.name != 'application') {
          final code = LintCode(
            name: 'interface_boundary',
            problemMessage: 'Output port interface $className should be defined in use case layer, not ${layer.name}',
            correctionMessage: 'Move output port interface to use case or application layer.',
          );
          reporter.atNode(node, code);
        }
        break;

      case InterfaceType.repository:
        if (layer.name != 'domain') {
          final code = LintCode(
            name: 'interface_boundary',
            problemMessage: 'Repository interface $className should be defined in domain layer, not ${layer.name}',
            correctionMessage: 'Move repository interface to domain layer.',
          );
          reporter.atNode(node, code);
        }
        break;

      case InterfaceType.gateway:
        if (layer.name != 'application' && layer.name != 'domain') {
          final code = LintCode(
            name: 'interface_boundary',
            problemMessage:
                'Gateway interface $className should be defined in application or domain layer, not ${layer.name}',
            correctionMessage: 'Move gateway interface to application or domain layer.',
          );
          reporter.atNode(node, code);
        }
        break;

      case InterfaceType.useCase:
        if (layer.name != 'application' && layer.name != 'use_case') {
          final code = LintCode(
            name: 'interface_boundary',
            problemMessage: 'Use case interface $className should be defined in application layer, not ${layer.name}',
            correctionMessage: 'Move use case interface to application layer.',
          );
          reporter.atNode(node, code);
        }
        break;

      case InterfaceType.other:
        // No specific location requirements
        break;
    }
  }

  void _validateInterfaceContract(
    ClassDeclaration node,
    ErrorReporter reporter,
    String className,
  ) {
    final methods = node.members.whereType<MethodDeclaration>();

    // Check for proper method signatures
    for (final method in methods) {
      _validateInterfaceMethodContract(method, reporter, className);
    }

    // Check for cohesion
    _validateInterfaceCohesion(node, reporter, className);
  }

  void _validateBoundaryImplementation(
    ClassDeclaration node,
    ErrorReporter reporter,
    ArchitecturalLayer layer,
    String className,
  ) {
    final implementsClause = node.implementsClause;
    if (implementsClause == null) return;

    for (final interface in implementsClause.interfaces) {
      final interfaceName = interface.name2.lexeme;
      final interfaceType = _classifyInterface(interfaceName);

      _validateImplementationLocation(
        interface,
        reporter,
        layer,
        className,
        interfaceName,
        interfaceType,
      );

      _validateImplementationCompleteness(
        node,
        reporter,
        className,
        interfaceName,
        interfaceType,
      );
    }
  }

  void _validateImplementationLocation(
    NamedType interface,
    ErrorReporter reporter,
    ArchitecturalLayer layer,
    String className,
    String interfaceName,
    InterfaceType interfaceType,
  ) {
    switch (interfaceType) {
      case InterfaceType.outputPort:
        if (layer.name != 'presenter' && layer.name != 'adapter') {
          final code = LintCode(
            name: 'interface_boundary',
            problemMessage:
                'Output port $interfaceName should be implemented by presenter, not ${layer.name} class $className',
            correctionMessage: 'Move implementation to presenter layer.',
          );
          reporter.atNode(interface, code);
        }
        break;

      case InterfaceType.repository:
        if (layer.name != 'infrastructure' && layer.name != 'data') {
          final code = LintCode(
            name: 'interface_boundary',
            problemMessage:
                'Repository interface $interfaceName should be implemented in infrastructure layer, not ${layer.name}',
            correctionMessage: 'Move repository implementation to infrastructure layer.',
          );
          reporter.atNode(interface, code);
        }
        break;

      case InterfaceType.gateway:
        if (layer.name != 'infrastructure' && layer.name != 'adapter') {
          final code = LintCode(
            name: 'interface_boundary',
            problemMessage:
                'Gateway interface $interfaceName should be implemented in infrastructure layer, not ${layer.name}',
            correctionMessage: 'Move gateway implementation to infrastructure layer.',
          );
          reporter.atNode(interface, code);
        }
        break;

      case InterfaceType.useCase:
        if (layer.name != 'use_case' && layer.name != 'application') {
          final code = LintCode(
            name: 'interface_boundary',
            problemMessage:
                'Use case interface $interfaceName should be implemented in use case layer, not ${layer.name}',
            correctionMessage: 'Move use case implementation to use case layer.',
          );
          reporter.atNode(interface, code);
        }
        break;

      case InterfaceType.other:
        // No specific requirements
        break;
    }
  }

  void _checkMissingBoundaryInterfaces(
    ClassDeclaration node,
    ErrorReporter reporter,
    ArchitecturalLayer layer,
    String className,
  ) {
    switch (layer.name) {
      case 'use_case':
        _checkMissingOutputPort(node, reporter, className);
        break;
      case 'presenter':
        _checkMissingOutputPortImplementation(node, reporter, className);
        break;
      case 'infrastructure':
        _checkMissingRepositoryImplementation(node, reporter, className);
        break;
      case 'controller':
        _checkControllerInterfaceUsage(node, reporter, className);
        break;
    }
  }

  void _validateInterfaceNaming(
    ClassDeclaration node,
    ErrorReporter reporter,
    ArchitecturalLayer layer,
    String className,
  ) {
    final interfaceType = _classifyInterface(className);

    // Check naming conventions
    if (!_hasProperInterfaceNaming(className, interfaceType)) {
      final code = LintCode(
        name: 'interface_boundary',
        problemMessage: 'Interface $className does not follow naming conventions for ${interfaceType.name}',
        correctionMessage: _getInterfaceNamingAdvice(interfaceType),
      );
      reporter.atNode(node, code);
    }
  }

  void _validateInterfaceCompleteness(
    ClassDeclaration node,
    ErrorReporter reporter,
    String className,
  ) {
    final methods = node.members.whereType<MethodDeclaration>();

    if (methods.isEmpty) {
      final code = LintCode(
        name: 'interface_boundary',
        problemMessage: 'Interface $className is empty - should define contract methods',
        correctionMessage: 'Add abstract methods to define the interface contract.',
      );
      reporter.atNode(node, code);
    }

    // Check for meaningful method names
    final meaningfulMethods = methods.where((method) => _isMeaningfulMethodName(method.name.lexeme));

    if (meaningfulMethods.length < methods.length * 0.8) {
      final code = LintCode(
        name: 'interface_boundary',
        problemMessage: 'Interface $className has unclear method names',
        correctionMessage: 'Use clear, intention-revealing method names in interface.',
      );
      reporter.atNode(node, code);
    }
  }

  void _validateInterfacePurity(
    ClassDeclaration node,
    ErrorReporter reporter,
    String className,
  ) {
    // Check for implementation details in interface
    for (final member in node.members) {
      if (member is MethodDeclaration && !member.isAbstract) {
        final code = LintCode(
          name: 'interface_boundary',
          problemMessage: 'Interface $className contains implementation details',
          correctionMessage: 'Interfaces should only declare abstract methods.',
        );
        reporter.atNode(member, code);
      }

      if (member is FieldDeclaration) {
        final code = LintCode(
          name: 'interface_boundary',
          problemMessage: 'Interface $className contains fields - should only have methods',
          correctionMessage: 'Remove fields from interface, use abstract methods instead.',
        );
        reporter.atNode(member, code);
      }
    }
  }

  void _validateInterfaceMethodSignature(
    MethodDeclaration method,
    ErrorReporter reporter,
    ArchitecturalLayer layer,
    String className,
  ) {
    final methodName = method.name.lexeme;

    // Check return types for boundary methods
    final returnType = method.returnType;
    if (returnType != null) {
      _validateBoundaryReturnType(method, reporter, returnType, className, methodName);
    }

    // Check parameter types
    final parameters = method.parameters?.parameters ?? [];
    for (final param in parameters) {
      _validateBoundaryParameterType(param, reporter, className, methodName);
    }
  }

  void _validateInterfaceMethodContract(
    MethodDeclaration method,
    ErrorReporter reporter,
    String className,
  ) {
    final methodName = method.name.lexeme;

    // Check for proper async handling in boundary methods
    if (_shouldBeAsync(methodName) && !_isAsyncMethod(method)) {
      final code = LintCode(
        name: 'interface_boundary',
        problemMessage: 'Boundary method $methodName in $className should be async',
        correctionMessage: 'Make method async and return Future for boundary operations.',
      );
      reporter.atNode(method, code);
    }

    // Check for error handling patterns
    if (_requiresErrorHandling(methodName)) {
      _validateErrorHandlingPattern(method, reporter, className, methodName);
    }
  }

  void _validateInterfaceCohesion(
    ClassDeclaration node,
    ErrorReporter reporter,
    String className,
  ) {
    final methods = node.members.whereType<MethodDeclaration>();
    final methodNames = methods.map((m) => m.name.lexeme).toList();

    // Check if methods belong together (cohesion)
    if (!_hasGoodCohesion(methodNames)) {
      final code = LintCode(
        name: 'interface_boundary',
        problemMessage: 'Interface $className may have low cohesion - unrelated methods',
        correctionMessage: 'Consider splitting into multiple focused interfaces.',
      );
      reporter.atNode(node, code);
    }
  }

  void _checkMissingOutputPort(
    ClassDeclaration node,
    ErrorReporter reporter,
    String className,
  ) {
    if (!_isUseCaseClass(className)) return;

    // Check if use case has presenter-related logic without output port
    final hasPresenterLogic = _hasPresenterLogic(node);
    final hasOutputPortDependency = _hasOutputPortDependency(node);

    if (hasPresenterLogic && !hasOutputPortDependency) {
      final code = LintCode(
        name: 'interface_boundary',
        problemMessage: 'Use case $className should define output port for presenter interaction',
        correctionMessage: 'Create output port interface to communicate with presenter.',
      );
      reporter.atNode(node, code);
    }
  }

  void _checkMissingOutputPortImplementation(
    ClassDeclaration node,
    ErrorReporter reporter,
    String className,
  ) {
    if (!_isPresenterClass(className)) return;

    final implementsOutputPort = _implementsOutputPort(node);

    if (!implementsOutputPort) {
      final code = LintCode(
        name: 'interface_boundary',
        problemMessage: 'Presenter $className should implement output port interface',
        correctionMessage: 'Implement the output port interface defined in use case layer.',
      );
      reporter.atNode(node, code);
    }
  }

  // Helper methods for classification and validation
  ArchitecturalLayer? _detectLayer(String filePath) {
    if (filePath.contains('/domain/')) return ArchitecturalLayer('domain', 4);
    if (filePath.contains('/usecases/') || filePath.contains('/use_cases/')) {
      return ArchitecturalLayer('use_case', 3);
    }
    if (filePath.contains('/application/')) return ArchitecturalLayer('application', 3);
    if (filePath.contains('/presenters/')) return ArchitecturalLayer('presenter', 2);
    if (filePath.contains('/controllers/')) return ArchitecturalLayer('controller', 2);
    if (filePath.contains('/adapters/')) return ArchitecturalLayer('adapter', 2);
    if (filePath.contains('/infrastructure/')) return ArchitecturalLayer('infrastructure', 1);
    if (filePath.contains('/data/')) return ArchitecturalLayer('data', 1);
    return null;
  }

  bool _isInterface(ClassDeclaration node, String className) {
    return node.abstractKeyword != null ||
        className.startsWith('I') && className.length > 1 ||
        className.contains('Interface') ||
        className.contains('Contract') ||
        className.contains('Port') ||
        _hasOnlyAbstractMethods(node);
  }

  bool _hasOnlyAbstractMethods(ClassDeclaration node) {
    final methods = node.members.whereType<MethodDeclaration>();
    if (methods.isEmpty) return true;

    return methods.every((method) => method.isAbstract || method.isGetter || method.isSetter);
  }

  InterfaceType _classifyInterface(String className) {
    if (className.contains('OutputPort') || className.contains('Output') && className.contains('Port')) {
      return InterfaceType.outputPort;
    }
    if (className.contains('Repository') && _isInterfaceName(className)) {
      return InterfaceType.repository;
    }
    if (className.contains('Gateway') && _isInterfaceName(className)) {
      return InterfaceType.gateway;
    }
    if (className.contains('UseCase') && _isInterfaceName(className)) {
      return InterfaceType.useCase;
    }
    return InterfaceType.other;
  }

  bool _isInterfaceName(String className) {
    return className.startsWith('I') || className.contains('Interface') || className.contains('Contract');
  }

  bool _implementsBoundaryInterface(ClassDeclaration node) {
    final implementsClause = node.implementsClause;
    if (implementsClause == null) return false;

    return implementsClause.interfaces.any((interface) {
      final interfaceName = interface.name2.lexeme;
      final interfaceType = _classifyInterface(interfaceName);
      return interfaceType != InterfaceType.other;
    });
  }

  bool _hasProperInterfaceNaming(String className, InterfaceType type) {
    switch (type) {
      case InterfaceType.outputPort:
        return className.contains('OutputPort') || className.contains('Port');
      case InterfaceType.repository:
        return className.contains('Repository') && _isInterfaceName(className);
      case InterfaceType.gateway:
        return className.contains('Gateway') && _isInterfaceName(className);
      case InterfaceType.useCase:
        return className.contains('UseCase') && _isInterfaceName(className);
      case InterfaceType.other:
        return true;
    }
  }

  String _getInterfaceNamingAdvice(InterfaceType type) {
    switch (type) {
      case InterfaceType.outputPort:
        return 'Use "OutputPort" suffix (e.g., UserOutputPort)';
      case InterfaceType.repository:
        return 'Use "I" prefix or "Interface" suffix (e.g., IUserRepository)';
      case InterfaceType.gateway:
        return 'Use "I" prefix or "Interface" suffix (e.g., IPaymentGateway)';
      case InterfaceType.useCase:
        return 'Use "I" prefix or "Interface" suffix (e.g., ICreateUserUseCase)';
      case InterfaceType.other:
        return 'Follow interface naming conventions';
    }
  }

  bool _isMeaningfulMethodName(String methodName) {
    // Check if method name is descriptive
    return methodName.length > 3 &&
        !methodName.startsWith('do') &&
        !methodName.startsWith('get') &&
        methodName.length <= 3;
  }

  bool _shouldBeAsync(String methodName) {
    final asyncPatterns = ['save', 'load', 'fetch', 'send', 'process', 'execute', 'handle', 'call', 'invoke'];
    return asyncPatterns.any((pattern) => methodName.toLowerCase().contains(pattern));
  }

  bool _isAsyncMethod(MethodDeclaration method) {
    final returnType = method.returnType;
    return returnType.toString().contains('Future') ||
        returnType.toString().contains('Stream') ||
        method.body.toString().contains('async');
  }

  bool _requiresErrorHandling(String methodName) {
    final errorPronePatterns = ['save', 'load', 'send', 'process', 'execute', 'call', 'invoke', 'validate', 'parse'];
    return errorPronePatterns.any((pattern) => methodName.toLowerCase().contains(pattern));
  }

  bool _hasGoodCohesion(List<String> methodNames) {
    if (methodNames.length <= 2) return true;

    // Simple heuristic: check if methods share common prefixes/suffixes
    final commonPrefixes = <String>[];
    final commonSuffixes = <String>[];

    for (final name in methodNames) {
      if (name.length > 3) {
        commonPrefixes.add(name.substring(0, 3));
        commonSuffixes.add(name.substring(name.length - 3));
      }
    }

    final uniquePrefixes = commonPrefixes.toSet().length;
    final uniqueSuffixes = commonSuffixes.toSet().length;

    return uniquePrefixes <= 2 || uniqueSuffixes <= 2;
  }

  // Additional helper methods
  void _validateBoundaryReturnType(
    MethodDeclaration method,
    ErrorReporter reporter,
    TypeAnnotation returnType,
    String className,
    String methodName,
  ) {
    // Implementation would check return type appropriateness
  }

  void _validateBoundaryParameterType(
    FormalParameter param,
    ErrorReporter reporter,
    String className,
    String methodName,
  ) {
    // Implementation would check parameter type appropriateness
  }

  void _validateErrorHandlingPattern(
    MethodDeclaration method,
    ErrorReporter reporter,
    String className,
    String methodName,
  ) {
    // Implementation would check for proper error handling patterns
  }

  void _validateImplementationCompleteness(
    ClassDeclaration node,
    ErrorReporter reporter,
    String className,
    String interfaceName,
    InterfaceType interfaceType,
  ) {
    // Implementation would verify all interface methods are implemented
  }

  void _checkMissingRepositoryImplementation(
    ClassDeclaration node,
    ErrorReporter reporter,
    String className,
  ) {
    // Implementation would check for repository interface implementation
  }

  void _checkControllerInterfaceUsage(
    ClassDeclaration node,
    ErrorReporter reporter,
    String className,
  ) {
    // Implementation would check controller interface patterns
  }

  bool _isUseCaseClass(String className) {
    return className.contains('UseCase') || className.contains('Interactor');
  }

  bool _isPresenterClass(String className) {
    return className.contains('Presenter') || className.contains('ViewModel');
  }

  bool _hasPresenterLogic(ClassDeclaration node) {
    return node.members.any((member) {
      if (member is MethodDeclaration) {
        final methodName = member.name.lexeme;
        return methodName.contains('present') || methodName.contains('display') || methodName.contains('show');
      }
      return false;
    });
  }

  bool _hasOutputPortDependency(ClassDeclaration node) {
    return node.members.any((member) {
      if (member is FieldDeclaration) {
        final type = member.fields.type;
        if (type is NamedType) {
          return (type.name2.lexeme.contains('OutputPort')) || (type.name2.lexeme.contains('Port'));
        }
      }
      return false;
    });
  }

  bool _implementsOutputPort(ClassDeclaration node) {
    final implementsClause = node.implementsClause;
    if (implementsClause == null) return false;

    return implementsClause.interfaces.any((interface) {
      final interfaceName = interface.name2.lexeme;
      return interfaceName.contains('OutputPort') || interfaceName.contains('Port');
    });
  }
}

class ArchitecturalLayer {
  final String name;
  final int level;

  ArchitecturalLayer(this.name, this.level);
}

enum InterfaceType {
  outputPort,
  repository,
  gateway,
  useCase,
  other,
}
