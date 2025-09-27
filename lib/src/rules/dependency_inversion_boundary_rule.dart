import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Enforces the Dependency Inversion Principle at architectural boundaries.
///
/// Uncle Bob: "We arrange interfaces and inheritance relationships such that
/// the source code dependencies oppose the flow of control at just the right
/// points across the boundary."
///
/// This rule ensures:
/// - High-level modules don't depend on low-level modules
/// - Both depend on abstractions (interfaces/abstract classes)
/// - Abstractions don't depend on details
/// - Details depend on abstractions
/// - Control flow and dependency direction are properly inverted
///
/// Specific patterns enforced:
/// - Use Case calls Output Port (interface) ← Presenter implements
/// - Controller depends on Use Case Interface ← Use Case implements
/// - Domain defines Repository Interface ← Infrastructure implements
/// - Gateway Interface ← External Service Adapter implements
class DependencyInversionBoundaryRule extends DartLintRule {
  const DependencyInversionBoundaryRule() : super(code: _code);

  static const _code = LintCode(
    name: 'dependency_inversion_boundary',
    problemMessage: 'Dependency Inversion violation at boundary: {0}',
    correctionMessage: 'Create interface in high-level module and implement in low-level module.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((node) {
      _analyzeClassDependencyInversion(node, reporter, resolver);
    });

    context.registry.addImportDirective((node) {
      _analyzeImportDependencyInversion(node, reporter, resolver);
    });

    context.registry.addMethodInvocation((node) {
      _analyzeMethodInvocationInversion(node, reporter, resolver);
    });
  }

  void _analyzeClassDependencyInversion(
    ClassDeclaration node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    final className = node.name.lexeme;
    final layer = _detectLayer(filePath);

    if (layer == null) return;

    // Analyze constructor dependencies
    _analyzeConstructorInversion(node, reporter, layer, className);

    // Analyze field dependencies
    _analyzeFieldInversion(node, reporter, layer, className);

    // Check if class properly inverts dependencies
    _validateClassInversionPattern(node, reporter, layer, className);
  }

  void _analyzeImportDependencyInversion(
    ImportDirective node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    final importUri = node.uri.stringValue;
    if (importUri == null) return;

    final currentLayer = _detectLayer(filePath);
    final importedLayer = _detectLayerFromImport(importUri);

    if (currentLayer != null && importedLayer != null) {
      _validateImportInversion(
        node,
        reporter,
        currentLayer,
        importedLayer,
        importUri,
      );
    }
  }

  void _analyzeMethodInvocationInversion(
    MethodInvocation node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    final layer = _detectLayer(filePath);
    if (layer == null) return;

    final methodName = node.methodName.name;
    _validateMethodCallInversion(node, reporter, layer, methodName);
  }

  void _analyzeConstructorInversion(
    ClassDeclaration node,
    ErrorReporter reporter,
    ArchitecturalLayer layer,
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
                _validateConstructorParameterInversion(
                  param,
                  reporter,
                  layer,
                  dependencyLayer,
                  className,
                  typeName,
                );
              }
            }
          }
        }
      }
    }
  }

  void _analyzeFieldInversion(
    ClassDeclaration node,
    ErrorReporter reporter,
    ArchitecturalLayer layer,
    String className,
  ) {
    for (final member in node.members) {
      if (member is FieldDeclaration) {
        final type = member.fields.type;
        if (type is NamedType) {
          final typeName = type.name2.lexeme;
          final dependencyLayer = _inferLayerFromType(typeName);

          if (dependencyLayer != null) {
            _validateFieldInversion(
              member,
              reporter,
              layer,
              dependencyLayer,
              className,
              typeName,
            );
          }
        }
      }
    }
  }

  void _validateClassInversionPattern(
    ClassDeclaration node,
    ErrorReporter reporter,
    ArchitecturalLayer layer,
    String className,
  ) {
    switch (layer.name) {
      case 'use_case':
        _validateUseCaseInversionPattern(node, reporter, className);
        break;
      case 'controller':
        _validateControllerInversionPattern(node, reporter, className);
        break;
      case 'presenter':
        _validatePresenterInversionPattern(node, reporter, className);
        break;
      case 'repository_impl':
        _validateRepositoryImplInversionPattern(node, reporter, className);
        break;
      case 'gateway':
        _validateGatewayInversionPattern(node, reporter, className);
        break;
    }
  }

  void _validateUseCaseInversionPattern(
    ClassDeclaration node,
    ErrorReporter reporter,
    String className,
  ) {
    var hasOutputPortDependency = false;
    var hasDirectPresenterDependency = false;
    var hasConcreteRepositoryDependency = false;

    for (final member in node.members) {
      if (member is FieldDeclaration) {
        final type = member.fields.type;
        if (type is NamedType) {
          final typeName = type.name2.lexeme;

          if (_isOutputPortInterface(typeName)) {
            hasOutputPortDependency = true;
          } else if (_isPresenterImplementation(typeName)) {
            hasDirectPresenterDependency = true;
          }

          if (_isRepositoryImplementation(typeName)) {
            hasConcreteRepositoryDependency = true;
          }
        }
      }
    }

    // Use case should depend on interfaces, not implementations
    if (hasDirectPresenterDependency) {
      final code = LintCode(
        name: 'dependency_inversion_boundary',
        problemMessage: 'Use case $className directly depends on presenter implementation',
        correctionMessage: 'Define output port interface in use case layer, implement in presenter.',
      );
      reporter.atNode(node, code);
    }

    if (hasConcreteRepositoryDependency) {
      final code = LintCode(
        name: 'dependency_inversion_boundary',
        problemMessage: 'Use case $className depends on concrete repository implementation',
        correctionMessage: 'Define repository interface in domain layer, implement in infrastructure.',
      );
      reporter.atNode(node, code);
    }

    // Suggest proper inversion if missing
    if (!hasOutputPortDependency && _needsOutputPort(node)) {
      final code = LintCode(
        name: 'dependency_inversion_boundary',
        problemMessage: 'Use case $className should define output port for dependency inversion',
        correctionMessage: 'Create output port interface to invert dependency on presenter.',
      );
      reporter.atNode(node, code);
    }
  }

  void _validateControllerInversionPattern(
    ClassDeclaration node,
    ErrorReporter reporter,
    String className,
  ) {
    var hasUseCaseInterface = false;
    var hasConcreteUseCaseDependency = false;

    for (final member in node.members) {
      if (member is FieldDeclaration) {
        final type = member.fields.type;
        if (type is NamedType) {
          final typeName = type.name2.lexeme;

          if (_isUseCaseInterface(typeName)) {
            hasUseCaseInterface = true;
          } else if (_isUseCaseImplementation(typeName)) {
            hasConcreteUseCaseDependency = true;
          }
        }
      }
    }

    if (hasConcreteUseCaseDependency && !hasUseCaseInterface) {
      final code = LintCode(
        name: 'dependency_inversion_boundary',
        problemMessage: 'Controller $className depends on concrete use case implementation',
        correctionMessage: 'Define use case interface and depend on abstraction.',
      );
      reporter.atNode(node, code);
    }
  }

  void _validatePresenterInversionPattern(
    ClassDeclaration node,
    ErrorReporter reporter,
    String className,
  ) {
    var implementsOutputPort = false;

    // Check if presenter implements output port (correct inversion)
    final implementsClause = node.implementsClause;
    if (implementsClause != null) {
      for (final interface in implementsClause.interfaces) {
        final interfaceName = interface.name2.lexeme;
        if (_isOutputPortInterface(interfaceName)) {
          implementsOutputPort = true;
          break;
        }
      }
    }

    if (!implementsOutputPort && _isPresenterClass(className)) {
      final code = LintCode(
        name: 'dependency_inversion_boundary',
        problemMessage: 'Presenter $className should implement output port interface',
        correctionMessage: 'Implement output port interface defined in use case layer.',
      );
      reporter.atNode(node, code);
    }
  }

  void _validateRepositoryImplInversionPattern(
    ClassDeclaration node,
    ErrorReporter reporter,
    String className,
  ) {
    var implementsRepositoryInterface = false;

    final implementsClause = node.implementsClause;
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
        name: 'dependency_inversion_boundary',
        problemMessage: 'Repository implementation $className should implement domain repository interface',
        correctionMessage: 'Implement repository interface defined in domain layer.',
      );
      reporter.atNode(node, code);
    }
  }

  void _validateGatewayInversionPattern(
    ClassDeclaration node,
    ErrorReporter reporter,
    String className,
  ) {
    var implementsGatewayInterface = false;

    final implementsClause = node.implementsClause;
    if (implementsClause != null) {
      for (final interface in implementsClause.interfaces) {
        final interfaceName = interface.name2.lexeme;
        if (_isGatewayInterface(interfaceName)) {
          implementsGatewayInterface = true;
          break;
        }
      }
    }

    if (!implementsGatewayInterface && _isGatewayImplementation(className)) {
      final code = LintCode(
        name: 'dependency_inversion_boundary',
        problemMessage: 'Gateway implementation $className should implement gateway interface',
        correctionMessage: 'Implement gateway interface defined in domain/application layer.',
      );
      reporter.atNode(node, code);
    }
  }

  void _validateConstructorParameterInversion(
    SimpleFormalParameter param,
    ErrorReporter reporter,
    ArchitecturalLayer currentLayer,
    ArchitecturalLayer dependencyLayer,
    String className,
    String typeName,
  ) {
    // High-level modules should not depend on low-level modules
    if (_isHighLevelLayer(currentLayer) && _isLowLevelLayer(dependencyLayer)) {
      if (!_isAbstraction(typeName)) {
        final code = LintCode(
          name: 'dependency_inversion_boundary',
          problemMessage: 'High-level $className depends on low-level concrete type: $typeName',
          correctionMessage: 'Define interface in high-level layer and implement in low-level layer.',
        );
        reporter.atNode(param, code);
      }
    }
  }

  void _validateFieldInversion(
    FieldDeclaration field,
    ErrorReporter reporter,
    ArchitecturalLayer currentLayer,
    ArchitecturalLayer dependencyLayer,
    String className,
    String typeName,
  ) {
    if (_isHighLevelLayer(currentLayer) && _isLowLevelLayer(dependencyLayer)) {
      if (!_isAbstraction(typeName)) {
        final code = LintCode(
          name: 'dependency_inversion_boundary',
          problemMessage: 'High-level $className has field dependency on low-level concrete type: $typeName',
          correctionMessage: 'Use interface/abstract class to invert the dependency.',
        );
        reporter.atNode(field, code);
      }
    }
  }

  void _validateImportInversion(
    ImportDirective node,
    ErrorReporter reporter,
    ArchitecturalLayer currentLayer,
    ArchitecturalLayer importedLayer,
    String importUri,
  ) {
    // Check for specific inversion violations
    if (_isHighLevelLayer(currentLayer) && _isLowLevelLayer(importedLayer)) {
      // High-level importing low-level (potential violation)
      if (_isConcreteImplementationImport(importUri)) {
        final code = LintCode(
          name: 'dependency_inversion_boundary',
          problemMessage: 'High-level ${currentLayer.name} imports low-level concrete implementation: $importUri',
          correctionMessage: 'Import interface/abstraction instead of implementation.',
        );
        reporter.atNode(node, code);
      }
    }

    // Domain importing infrastructure (clear violation)
    if (currentLayer.name == 'domain' && importedLayer.name == 'infrastructure') {
      final code = LintCode(
        name: 'dependency_inversion_boundary',
        problemMessage: 'Domain layer imports infrastructure: $importUri',
        correctionMessage: 'Define interface in domain, implement in infrastructure.',
      );
      reporter.atNode(node, code);
    }

    // Use case importing presenter (should use output port)
    if (currentLayer.name == 'use_case' && importedLayer.name == 'presenter') {
      final code = LintCode(
        name: 'dependency_inversion_boundary',
        problemMessage: 'Use case imports presenter: $importUri',
        correctionMessage: 'Create output port interface in use case, implement in presenter.',
      );
      reporter.atNode(node, code);
    }
  }

  void _validateMethodCallInversion(
    MethodInvocation node,
    ErrorReporter reporter,
    ArchitecturalLayer layer,
    String methodName,
  ) {
    final target = node.target?.toString() ?? '';

    // Check for calls that violate dependency inversion
    if (layer.name == 'use_case' && _isPresenterMethod(target, methodName)) {
      final code = LintCode(
        name: 'dependency_inversion_boundary',
        problemMessage: 'Use case directly calls presenter method: $methodName',
        correctionMessage: 'Call through output port interface instead.',
      );
      reporter.atNode(node, code);
    }

    if (layer.name == 'domain' && _isInfrastructureMethod(target, methodName)) {
      final code = LintCode(
        name: 'dependency_inversion_boundary',
        problemMessage: 'Domain directly calls infrastructure method: $methodName',
        correctionMessage: 'Define interface in domain and call through abstraction.',
      );
      reporter.atNode(node, code);
    }
  }

  // Layer and type classification methods
  ArchitecturalLayer? _detectLayer(String filePath) {
    if (filePath.contains('/domain/')) return ArchitecturalLayer('domain', 4, true);
    if (filePath.contains('/usecases/')) return ArchitecturalLayer('use_case', 3, true);
    if (filePath.contains('/controllers/')) return ArchitecturalLayer('controller', 2, false);
    if (filePath.contains('/presenters/')) return ArchitecturalLayer('presenter', 2, false);
    if (filePath.contains('/repositories/') && filePath.contains('/impl')) {
      return ArchitecturalLayer('repository_impl', 1, false);
    }
    if (filePath.contains('/gateways/')) return ArchitecturalLayer('gateway', 1, false);
    if (filePath.contains('/infrastructure/')) return ArchitecturalLayer('infrastructure', 1, false);
    return null;
  }

  ArchitecturalLayer? _detectLayerFromImport(String importUri) {
    if (importUri.contains('/domain/')) return ArchitecturalLayer('domain', 4, true);
    if (importUri.contains('/usecases/')) return ArchitecturalLayer('use_case', 3, true);
    if (importUri.contains('/controllers/')) return ArchitecturalLayer('controller', 2, false);
    if (importUri.contains('/presenters/')) return ArchitecturalLayer('presenter', 2, false);
    if (importUri.contains('/infrastructure/')) return ArchitecturalLayer('infrastructure', 1, false);
    return null;
  }

  ArchitecturalLayer? _inferLayerFromType(String typeName) {
    if (_isDomainType(typeName)) return ArchitecturalLayer('domain', 4, true);
    if (_isUseCaseType(typeName)) return ArchitecturalLayer('use_case', 3, true);
    if (_isControllerType(typeName)) return ArchitecturalLayer('controller', 2, false);
    if (_isPresenterType(typeName)) return ArchitecturalLayer('presenter', 2, false);
    if (_isRepositoryType(typeName)) return ArchitecturalLayer('repository_impl', 1, false);
    if (_isInfrastructureType(typeName)) return ArchitecturalLayer('infrastructure', 1, false);
    return null;
  }

  bool _isHighLevelLayer(ArchitecturalLayer layer) {
    return layer.isHighLevel;
  }

  bool _isLowLevelLayer(ArchitecturalLayer layer) {
    return !layer.isHighLevel;
  }

  bool _isAbstraction(String typeName) {
    return _isInterface(typeName) || _isAbstractClass(typeName);
  }

  bool _isInterface(String typeName) {
    return typeName.startsWith('I') && typeName.length > 1 ||
        typeName.contains('Interface') ||
        typeName.contains('Contract') ||
        typeName.contains('Port');
  }

  bool _isAbstractClass(String typeName) {
    return typeName.startsWith('Abstract') || typeName.contains('Base');
  }

  // Specific pattern detection methods
  bool _isOutputPortInterface(String typeName) {
    return typeName.contains('OutputPort') ||
        typeName.contains('Output') && _isInterface(typeName) ||
        typeName.contains('Port') && _isInterface(typeName);
  }

  bool _isRepositoryInterface(String typeName) {
    return typeName.contains('Repository') && _isInterface(typeName);
  }

  bool _isRepositoryImplementation(String typeName) {
    return typeName.contains('Repository') && (typeName.contains('Impl') || !_isInterface(typeName));
  }

  bool _isGatewayInterface(String typeName) {
    return typeName.contains('Gateway') && _isInterface(typeName);
  }

  bool _isGatewayImplementation(String typeName) {
    return typeName.contains('Gateway') && !_isInterface(typeName);
  }

  bool _isUseCaseInterface(String typeName) {
    return typeName.contains('UseCase') && _isInterface(typeName);
  }

  bool _isUseCaseImplementation(String typeName) {
    return typeName.contains('UseCase') && !_isInterface(typeName);
  }

  bool _isPresenterImplementation(String typeName) {
    return typeName.contains('Presenter') && !_isInterface(typeName);
  }

  bool _isPresenterClass(String className) {
    return className.contains('Presenter');
  }

  bool _needsOutputPort(ClassDeclaration node) {
    // Check if use case has methods that would benefit from output port
    return node.members.any((member) {
      if (member is MethodDeclaration) {
        final methodName = member.name.lexeme;
        return methodName.contains('present') || methodName.contains('display') || methodName.contains('show');
      }
      return false;
    });
  }

  bool _isConcreteImplementationImport(String importUri) {
    return importUri.contains('/impl/') || importUri.contains('/implementations/') || importUri.contains('_impl.dart');
  }

  // Type classification helpers
  bool _isDomainType(String typeName) {
    return typeName.contains('Entity') ||
        typeName.contains('ValueObject') ||
        typeName.contains('Policy') ||
        typeName.contains('Rule');
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

  bool _isInfrastructureType(String typeName) {
    return typeName.contains('Database') ||
        typeName.contains('Http') ||
        typeName.contains('File') ||
        typeName.contains('Network') ||
        typeName.contains('Driver');
  }

  bool _isPresenterMethod(String target, String methodName) {
    return target.contains('presenter') ||
        target.contains('view') ||
        methodName.contains('display') ||
        methodName.contains('show');
  }

  bool _isInfrastructureMethod(String target, String methodName) {
    return target.contains('database') ||
        target.contains('http') ||
        target.contains('file') ||
        methodName.contains('save') ||
        methodName.contains('load');
  }
}

class ArchitecturalLayer {
  final String name;
  final int level;
  final bool isHighLevel;

  ArchitecturalLayer(this.name, this.level, this.isHighLevel);
}
