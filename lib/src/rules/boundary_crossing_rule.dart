import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Enforces proper boundary crossing patterns in Clean Architecture.
///
/// Uncle Bob: "We usually resolve this apparent contradiction by using the
/// Dependency Inversion Principle. We arrange interfaces and inheritance
/// relationships such that the source code dependencies oppose the flow of
/// control at just the right points across the boundary."
///
/// This rule validates:
/// - Use cases call interfaces (Output Ports) not concrete presenters
/// - Controllers depend on use case interfaces, not implementations
/// - Source code dependencies oppose control flow direction
/// - Dynamic polymorphism is used to invert dependencies
/// - No direct calls from inner to outer layers
/// - All boundary crossings use abstraction
///
/// Key patterns enforced:
/// - Controller → Use Case Interface → Use Case Implementation
/// - Use Case → Output Port Interface ← Presenter Implementation
/// - Repository Interface ← Repository Implementation
/// - Gateway Interface ← External Service Adapter
class BoundaryCrossingRule extends DartLintRule {
  const BoundaryCrossingRule() : super(code: _code);

  static const _code = LintCode(
    name: 'boundary_crossing',
    problemMessage: 'Boundary crossing violation: {0}',
    correctionMessage: 'Use Dependency Inversion Principle to cross architectural boundaries properly.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((node) {
      _analyzeBoundaryCrossing(node, reporter, resolver);
    });

    context.registry.addMethodDeclaration((node) {
      _analyzeMethodBoundaryCalls(node, reporter, resolver);
    });

    context.registry.addMethodInvocation((node) {
      _analyzeMethodInvocation(node, reporter, resolver);
    });
  }

  void _analyzeBoundaryCrossing(
    ClassDeclaration node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    final className = node.name.lexeme;
    final currentLayer = _detectLayer(filePath);

    if (currentLayer == null) return;

    // Check constructor dependencies for proper boundary crossing
    _validateConstructorBoundaries(node, reporter, currentLayer, className);

    // Check field dependencies
    _validateFieldBoundaries(node, reporter, currentLayer, className);

    // Check if class properly implements boundary interfaces
    _validateBoundaryImplementation(node, reporter, currentLayer, className);
  }

  void _validateConstructorBoundaries(
    ClassDeclaration node,
    ErrorReporter reporter,
    ArchitecturalLayer currentLayer,
    String className,
  ) {
    for (final member in node.members) {
      if (member is ConstructorDeclaration) {
        final parameters = member.parameters.parameters;

        for (final param in parameters) {
          if (param is SimpleFormalParameter) {
            final type = param.type;
            if (type is NamedType) {
              final typeName = type.name2.lexeme;
              final dependencyLayer = _inferLayerFromType(typeName);

              if (dependencyLayer != null) {
                _validateDependencyBoundary(
                  param,
                  reporter,
                  currentLayer,
                  dependencyLayer,
                  className,
                  typeName,
                  'constructor parameter',
                );
              }
            }
          }
        }
      }
    }
  }

  void _validateFieldBoundaries(
    ClassDeclaration node,
    ErrorReporter reporter,
    ArchitecturalLayer currentLayer,
    String className,
  ) {
    for (final member in node.members) {
      if (member is FieldDeclaration) {
        final type = member.fields.type;
        if (type is NamedType) {
          final typeName = type.name2.lexeme;
          final dependencyLayer = _inferLayerFromType(typeName);

          if (dependencyLayer != null) {
            _validateDependencyBoundary(
              member,
              reporter,
              currentLayer,
              dependencyLayer,
              className,
              typeName,
              'field',
            );
          }
        }
      }
    }
  }

  void _validateBoundaryImplementation(
    ClassDeclaration node,
    ErrorReporter reporter,
    ArchitecturalLayer currentLayer,
    String className,
  ) {
    // Check if class implements proper boundary interfaces
    final implementsClause = node.implementsClause;
    if (implementsClause != null) {
      for (final interface in implementsClause.interfaces) {
        final interfaceName = interface.name2.lexeme;
        _validateInterfaceImplementation(
          interface,
          reporter,
          currentLayer,
          className,
          interfaceName,
        );
      }
    }

    // Check for boundary pattern violations
    _checkBoundaryPatternViolations(node, reporter, currentLayer, className);
  }

  void _analyzeMethodBoundaryCalls(
    MethodDeclaration method,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    final currentLayer = _detectLayer(filePath);
    if (currentLayer == null) return;

    final methodName = method.name.lexeme;

    // Check method parameters for boundary crossing
    final parameters = method.parameters?.parameters ?? [];
    for (final param in parameters) {
      if (param is SimpleFormalParameter) {
        final type = param.type;
        if (type is NamedType) {
          final typeName = type.name2.lexeme;
          final dependencyLayer = _inferLayerFromType(typeName);

          if (dependencyLayer != null) {
            _validateMethodParameterBoundary(
              param,
              reporter,
              currentLayer,
              dependencyLayer,
              methodName,
              typeName,
            );
          }
        }
      }
    }
  }

  void _analyzeMethodInvocation(
    MethodInvocation node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    final currentLayer = _detectLayer(filePath);
    if (currentLayer == null) return;

    // Check if method invocation crosses boundaries properly
    final target = node.target;
    if (target != null) {
      final methodName = node.methodName.name;
      _validateMethodInvocationBoundary(
        node,
        reporter,
        currentLayer,
        methodName,
      );
    }
  }

  void _validateDependencyBoundary(
    AstNode node,
    ErrorReporter reporter,
    ArchitecturalLayer currentLayer,
    ArchitecturalLayer dependencyLayer,
    String className,
    String typeName,
    String dependencyType,
  ) {
    // Check if dependency direction violates boundary rules
    if (_isInvalidBoundaryDependency(currentLayer, dependencyLayer)) {
      if (_isConcreteType(typeName)) {
        final code = LintCode(
          name: 'boundary_crossing',
          problemMessage:
              '${currentLayer.name} class $className has concrete $dependencyType dependency on ${dependencyLayer.name} layer: $typeName',
          correctionMessage:
              'Use an interface/abstract class instead. Define interface in ${currentLayer.name} layer and implement in ${dependencyLayer.name} layer.',
        );
        reporter.atNode(node, code);
      }
    }

    // Check for specific boundary crossing patterns
    _validateSpecificBoundaryPatterns(
      node,
      reporter,
      currentLayer,
      dependencyLayer,
      className,
      typeName,
    );
  }

  void _validateInterfaceImplementation(
    NamedType interface,
    ErrorReporter reporter,
    ArchitecturalLayer currentLayer,
    String className,
    String interfaceName,
  ) {
    final interfaceLayer = _inferLayerFromType(interfaceName);

    if (interfaceLayer != null) {
      // Validate that interface is from inner layer (Dependency Inversion)
      if (currentLayer.level >= interfaceLayer.level) {
        // This is correct - outer layer implementing inner layer interface
        if (!_isValidBoundaryInterface(interfaceName, currentLayer, interfaceLayer)) {
          final code = LintCode(
            name: 'boundary_crossing',
            problemMessage: '$className implements inappropriate interface for boundary crossing: $interfaceName',
            correctionMessage:
                'Ensure interface represents proper boundary abstraction (e.g., OutputPort, Repository, Gateway).',
          );
          reporter.atNode(interface, code);
        }
      }
    }
  }

  void _checkBoundaryPatternViolations(
    ClassDeclaration node,
    ErrorReporter reporter,
    ArchitecturalLayer currentLayer,
    String className,
  ) {
    switch (currentLayer.name) {
      case 'use_case':
        _checkUseCaseBoundaryPatterns(node, reporter, className);
        break;
      case 'controller':
        _checkControllerBoundaryPatterns(node, reporter, className);
        break;
      case 'presenter':
        _checkPresenterBoundaryPatterns(node, reporter, className);
        break;
      case 'repository':
        _checkRepositoryBoundaryPatterns(node, reporter, className);
        break;
    }
  }

  void _checkUseCaseBoundaryPatterns(
    ClassDeclaration node,
    ErrorReporter reporter,
    String className,
  ) {
    var hasOutputPort = false;
    var hasDirectPresenterDependency = false;

    for (final member in node.members) {
      if (member is FieldDeclaration) {
        final type = member.fields.type;
        if (type is NamedType) {
          final typeName = type.name2.lexeme;

          if (_isOutputPort(typeName)) {
            hasOutputPort = true;
          }

          if (_isPresenterType(typeName) && !_isInterface(typeName)) {
            hasDirectPresenterDependency = true;
          }
        }
      }
    }

    // Use case should use output ports, not direct presenter dependencies
    if (hasDirectPresenterDependency && !hasOutputPort) {
      final code = LintCode(
        name: 'boundary_crossing',
        problemMessage: 'Use case $className has direct presenter dependency instead of output port',
        correctionMessage: 'Define an output port interface in use case layer and have presenter implement it.',
      );
      reporter.atNode(node, code);
    }
  }

  void _checkControllerBoundaryPatterns(
    ClassDeclaration node,
    ErrorReporter reporter,
    String className,
  ) {
    var hasUseCaseInterface = false;
    var hasDirectUseCaseImplementation = false;

    for (final member in node.members) {
      if (member is FieldDeclaration) {
        final type = member.fields.type;
        if (type is NamedType) {
          final typeName = type.name2.lexeme;

          if (_isUseCaseType(typeName)) {
            if (_isInterface(typeName)) {
              hasUseCaseInterface = true;
            } else {
              hasDirectUseCaseImplementation = true;
            }
          }
        }
      }
    }

    if (hasDirectUseCaseImplementation && !hasUseCaseInterface) {
      final code = LintCode(
        name: 'boundary_crossing',
        problemMessage: 'Controller $className depends on concrete use case instead of interface',
        correctionMessage: 'Define use case interface and depend on abstraction, not implementation.',
      );
      reporter.atNode(node, code);
    }
  }

  void _checkPresenterBoundaryPatterns(
    ClassDeclaration node,
    ErrorReporter reporter,
    String className,
  ) {
    // Check if presenter properly implements output port
    final implementsClause = node.implementsClause;
    var implementsOutputPort = false;

    if (implementsClause != null) {
      for (final interface in implementsClause.interfaces) {
        final interfaceName = interface.name2.lexeme;
        if (_isOutputPort(interfaceName)) {
          implementsOutputPort = true;
          break;
        }
      }
    }

    if (!implementsOutputPort && _isPresenterClass(className)) {
      final code = LintCode(
        name: 'boundary_crossing',
        problemMessage: 'Presenter $className should implement an output port interface',
        correctionMessage: 'Implement the appropriate output port interface to enable proper boundary crossing.',
      );
      reporter.atNode(node, code);
    }
  }

  void _checkRepositoryBoundaryPatterns(
    ClassDeclaration node,
    ErrorReporter reporter,
    String className,
  ) {
    // Repository implementation should implement repository interface
    final implementsClause = node.implementsClause;
    var implementsRepositoryInterface = false;

    if (implementsClause != null) {
      for (final interface in implementsClause.interfaces) {
        final interfaceName = interface.name2.lexeme;
        if (_isRepositoryInterface(interfaceName)) {
          implementsRepositoryInterface = true;
          break;
        }
      }
    }

    if (!implementsRepositoryInterface && _isRepositoryImplementation(className)) {
      final code = LintCode(
        name: 'boundary_crossing',
        problemMessage: 'Repository implementation $className should implement repository interface',
        correctionMessage: 'Implement the repository interface defined in the domain layer.',
      );
      reporter.atNode(node, code);
    }
  }

  void _validateMethodParameterBoundary(
    SimpleFormalParameter param,
    ErrorReporter reporter,
    ArchitecturalLayer currentLayer,
    ArchitecturalLayer dependencyLayer,
    String methodName,
    String typeName,
  ) {
    if (_isInvalidBoundaryDependency(currentLayer, dependencyLayer)) {
      if (_isConcreteType(typeName)) {
        final code = LintCode(
          name: 'boundary_crossing',
          problemMessage:
              'Method $methodName in ${currentLayer.name} layer accepts concrete type from ${dependencyLayer.name} layer: $typeName',
          correctionMessage: 'Accept interface/abstract type instead to maintain boundary separation.',
        );
        reporter.atNode(param, code);
      }
    }
  }

  void _validateMethodInvocationBoundary(
    MethodInvocation node,
    ErrorReporter reporter,
    ArchitecturalLayer currentLayer,
    String methodName,
  ) {
    // Check for specific anti-patterns in method invocations
    final target = node.target.toString();

    // Use case directly calling presenter
    if (currentLayer.name == 'use_case' && _isPresenterTarget(target)) {
      final code = LintCode(
        name: 'boundary_crossing',
        problemMessage: 'Use case directly calls presenter method: $methodName',
        correctionMessage: 'Use output port interface instead of direct presenter call.',
      );
      reporter.atNode(node, code);
    }

    // Domain directly calling infrastructure
    if (currentLayer.name == 'domain' && _isInfrastructureTarget(target)) {
      final code = LintCode(
        name: 'boundary_crossing',
        problemMessage: 'Domain layer directly calls infrastructure: $methodName',
        correctionMessage: 'Define interface in domain layer and implement in infrastructure.',
      );
      reporter.atNode(node, code);
    }
  }

  void _validateSpecificBoundaryPatterns(
    AstNode node,
    ErrorReporter reporter,
    ArchitecturalLayer currentLayer,
    ArchitecturalLayer dependencyLayer,
    String className,
    String typeName,
  ) {
    // Controller → Use Case boundary
    if (currentLayer.name == 'controller' && dependencyLayer.name == 'use_case') {
      if (!_isInterface(typeName) && !_isAbstractClass(typeName)) {
        final code = LintCode(
          name: 'boundary_crossing',
          problemMessage: 'Controller $className depends on concrete use case: $typeName',
          correctionMessage: 'Define use case interface for dependency inversion.',
        );
        reporter.atNode(node, code);
      }
    }

    // Use Case → Repository boundary
    if (currentLayer.name == 'use_case' && dependencyLayer.name == 'repository') {
      if (!_isInterface(typeName)) {
        final code = LintCode(
          name: 'boundary_crossing',
          problemMessage: 'Use case $className depends on concrete repository: $typeName',
          correctionMessage: 'Use repository interface defined in domain layer.',
        );
        reporter.atNode(node, code);
      }
    }

    // Use Case → Presenter boundary (should use output port)
    if (currentLayer.name == 'use_case' && dependencyLayer.name == 'presenter') {
      final code = LintCode(
        name: 'boundary_crossing',
        problemMessage: 'Use case $className directly depends on presenter: $typeName',
        correctionMessage: 'Define output port interface and have presenter implement it.',
      );
      reporter.atNode(node, code);
    }
  }

  // Layer detection and classification methods
  ArchitecturalLayer? _detectLayer(String filePath) {
    if (filePath.contains('/usecases/') || filePath.contains('/use_cases/')) {
      return ArchitecturalLayer('use_case', 3);
    }
    if (filePath.contains('/controllers/')) {
      return ArchitecturalLayer('controller', 2);
    }
    if (filePath.contains('/presenters/')) {
      return ArchitecturalLayer('presenter', 2);
    }
    if (filePath.contains('/repositories/')) {
      return ArchitecturalLayer('repository', 1);
    }
    if (filePath.contains('/domain/')) {
      return ArchitecturalLayer('domain', 4);
    }
    if (filePath.contains('/adapters/')) {
      return ArchitecturalLayer('adapter', 2);
    }
    if (filePath.contains('/infrastructure/')) {
      return ArchitecturalLayer('infrastructure', 1);
    }
    return null;
  }

  ArchitecturalLayer? _inferLayerFromType(String typeName) {
    if (_isUseCaseType(typeName)) return ArchitecturalLayer('use_case', 3);
    if (_isControllerType(typeName)) return ArchitecturalLayer('controller', 2);
    if (_isPresenterType(typeName)) return ArchitecturalLayer('presenter', 2);
    if (_isRepositoryType(typeName)) return ArchitecturalLayer('repository', 1);
    if (_isDomainType(typeName)) return ArchitecturalLayer('domain', 4);
    if (_isInfrastructureType(typeName)) return ArchitecturalLayer('infrastructure', 1);
    return null;
  }

  bool _isInvalidBoundaryDependency(ArchitecturalLayer current, ArchitecturalLayer dependency) {
    // Inner layers cannot depend on outer layers (except through interfaces)
    return current.level > dependency.level;
  }

  bool _isValidBoundaryInterface(String interfaceName, ArchitecturalLayer current, ArchitecturalLayer interfaceLayer) {
    // Check if interface represents proper boundary abstraction
    final boundaryInterfaces = ['OutputPort', 'Repository', 'Gateway', 'Port', 'Interface', 'Contract', 'Boundary'];

    return boundaryInterfaces.any((pattern) => interfaceName.contains(pattern));
  }

  // Type classification methods
  bool _isConcreteType(String typeName) {
    final concreteIndicators = [
      'Implementation',
      'Impl',
      'Concrete',
      'Adapter',
      'Service',
      'Manager',
      'Handler',
      'Client'
    ];
    return concreteIndicators.any((indicator) => typeName.contains(indicator)) && !_isInterface(typeName);
  }

  bool _isInterface(String typeName) {
    return typeName.startsWith('I') ||
        typeName.contains('Interface') ||
        typeName.contains('Contract') ||
        typeName.contains('Port');
  }

  bool _isAbstractClass(String typeName) {
    return typeName.startsWith('Abstract') || typeName.contains('Base');
  }

  bool _isOutputPort(String typeName) {
    return typeName.contains('OutputPort') || typeName.contains('Output') || typeName.contains('Port');
  }

  bool _isUseCaseType(String typeName) {
    return typeName.contains('UseCase') || typeName.contains('Interactor') || typeName.contains('Service');
  }

  bool _isControllerType(String typeName) {
    return typeName.contains('Controller');
  }

  bool _isPresenterType(String typeName) {
    return typeName.contains('Presenter') || typeName.contains('ViewModel');
  }

  bool _isRepositoryType(String typeName) {
    return typeName.contains('Repository');
  }

  bool _isDomainType(String typeName) {
    return typeName.contains('Entity') || typeName.contains('ValueObject') || typeName.contains('Policy');
  }

  bool _isInfrastructureType(String typeName) {
    return typeName.contains('Database') ||
        typeName.contains('Http') ||
        typeName.contains('File') ||
        typeName.contains('Network');
  }

  bool _isPresenterClass(String className) {
    return className.contains('Presenter') || className.contains('ViewModel');
  }

  bool _isRepositoryInterface(String interfaceName) {
    return interfaceName.contains('Repository') && _isInterface(interfaceName);
  }

  bool _isRepositoryImplementation(String className) {
    return className.contains('Repository') && !_isInterface(className);
  }

  bool _isPresenterTarget(String target) {
    return target.contains('presenter') || target.contains('view') || target.contains('ui');
  }

  bool _isInfrastructureTarget(String target) {
    return target.contains('database') ||
        target.contains('http') ||
        target.contains('file') ||
        target.contains('network');
  }
}

class ArchitecturalLayer {
  final String name;
  final int level; // Higher = more inner/abstract

  ArchitecturalLayer(this.name, this.level);
}
