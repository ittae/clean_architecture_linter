import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../clean_architecture_linter_base.dart';

/// The Core Dependency Rule - Uncle Bob's fundamental Clean Architecture principle.
///
/// "Source code dependencies always point inwards. As you move inwards the level
/// of abstraction increases. The outermost circle is low level concrete detail.
/// As you move inwards the software grows more abstract, and encapsulates higher
/// level policies. The inner most circle is the most general."
///
/// This rule enforces:
/// - Dependencies ALWAYS point inward (toward higher abstraction)
/// - Inner layers cannot know about outer layers
/// - Abstraction increases as you move inward
/// - Policy is separated from detail
/// - The Dependency Inversion Principle at architectural boundaries
class CoreDependencyRule extends DartLintRule {
  const CoreDependencyRule() : super(code: _code);

  static const _code = LintCode(
    name: 'core_dependency_rule',
    problemMessage: 'Dependency Rule violation: {0}',
    correctionMessage: 'Dependencies must always point inward. Use Dependency Inversion to correct the direction.',
  );

  // Dependency tracking for comprehensive analysis
  static final Map<String, Set<String>> _fileDependencies = {};
  static final Map<String, DependencyNode> _dependencyGraph = {};

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    final filePath = resolver.path;

    // Skip analysis for test files and generated files
    if (CleanArchitectureUtils.shouldExcludeFile(filePath)) {
      return;
    }

    context.registry.addImportDirective((node) {
      _trackDependency(node, filePath);
      _validateDependencyDirection(node, reporter, resolver);
    });

    context.registry.addClassDeclaration((node) {
      _validateClassDependencies(node, reporter, resolver);
    });

    // Analyze complete dependency graph after processing
    context.registry.addCompilationUnit((node) {
      _performGlobalDependencyAnalysis(reporter, resolver);
    });
  }

  void _trackDependency(ImportDirective node, String filePath) {
    final importUri = node.uri.stringValue;
    if (importUri == null) return;

    _fileDependencies.putIfAbsent(filePath, () => {}).add(importUri);

    // Build dependency nodes
    final currentNode = _dependencyGraph.putIfAbsent(
      filePath,
      () => DependencyNode(filePath, _detectAbstractionLevel(filePath)),
    );

    if (importUri.startsWith('./') || importUri.startsWith('../')) {
      final importedNode = _dependencyGraph.putIfAbsent(
        importUri,
        () => DependencyNode(importUri, _detectAbstractionLevel(importUri)),
      );
      currentNode.dependencies.add(importedNode);
    }
  }

  void _validateDependencyDirection(
    ImportDirective node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    final importUri = node.uri.stringValue;
    if (importUri == null) return;

    final currentAbstraction = _detectAbstractionLevel(filePath);
    final importedAbstraction = _detectAbstractionLevel(importUri);

    // Core rule: dependencies must point toward higher abstraction
    if (currentAbstraction > importedAbstraction) {
      _reportDependencyViolation(
        node,
        reporter,
        filePath,
        importUri,
        currentAbstraction,
        importedAbstraction,
      );
    }

    // Check for framework dependencies in inner layers
    if (_isFrameworkDependency(importUri)) {
      if (_isInnerLayer(filePath)) {
        _reportFrameworkLeakage(node, reporter, importUri, filePath);
      }
    }

    // Check for specific anti-patterns
    _checkSpecificAntiPatterns(node, reporter, filePath, importUri);
  }

  void _validateClassDependencies(
    ClassDeclaration node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    final className = node.name.lexeme;

    // Check constructor dependencies
    for (final member in node.members) {
      if (member is ConstructorDeclaration) {
        _validateConstructorDependencies(member, reporter, filePath, className);
      }

      if (member is FieldDeclaration) {
        _validateFieldDependencies(member, reporter, filePath, className);
      }

      if (member is MethodDeclaration) {
        _validateMethodDependencies(member, reporter, filePath, className);
      }
    }
  }

  void _validateConstructorDependencies(
    ConstructorDeclaration constructor,
    ErrorReporter reporter,
    String filePath,
    String className,
  ) {
    final parameters = constructor.parameters.parameters;
    final currentAbstraction = _detectAbstractionLevel(filePath);

    for (final param in parameters) {
      if (param is SimpleFormalParameter) {
        final type = param.type;
        if (type is NamedType) {
          final typeName = type.name2.lexeme;
          final dependencyAbstraction = _inferTypeAbstraction(typeName);

          if (currentAbstraction > dependencyAbstraction) {
            final code = LintCode(
              name: 'core_dependency_rule',
              problemMessage: 'Constructor dependency violation: $className depends on lower abstraction $typeName',
              correctionMessage: 'Use an interface or abstract class to invert the dependency.',
            );
            reporter.atNode(param, code);
          }
        }
      }
    }
  }

  void _validateFieldDependencies(
    FieldDeclaration field,
    ErrorReporter reporter,
    String filePath,
    String className,
  ) {
    final type = field.fields.type;
    if (type is NamedType) {
      final typeName = type.name2.lexeme;
      final currentAbstraction = _detectAbstractionLevel(filePath);
      final dependencyAbstraction = _inferTypeAbstraction(typeName);

      if (currentAbstraction > dependencyAbstraction) {
        final code = LintCode(
          name: 'core_dependency_rule',
          problemMessage: 'Field dependency violation: $className field depends on lower abstraction $typeName',
          correctionMessage: 'Use dependency injection with an abstraction.',
        );
        reporter.atNode(field, code);
      }
    }
  }

  void _validateMethodDependencies(
    MethodDeclaration method,
    ErrorReporter reporter,
    String filePath,
    String className,
  ) {
    final methodName = method.name.lexeme;
    final currentAbstraction = _detectAbstractionLevel(filePath);

    // Check method parameters
    final parameters = method.parameters?.parameters ?? [];
    for (final param in parameters) {
      if (param is SimpleFormalParameter) {
        final type = param.type;
        if (type is NamedType) {
          final typeName = type.name2.lexeme;
          final dependencyAbstraction = _inferTypeAbstraction(typeName);

          if (currentAbstraction > dependencyAbstraction) {
            final code = LintCode(
              name: 'core_dependency_rule',
              problemMessage:
                  'Method dependency violation: $className.$methodName depends on lower abstraction $typeName',
              correctionMessage: 'Pass abstractions as parameters instead of concrete types.',
            );
            reporter.atNode(param, code);
          }
        }
      }
    }

    // Check method body for concrete dependencies
    _validateMethodBody(method, reporter, filePath, className, methodName);
  }

  void _validateMethodBody(
    MethodDeclaration method,
    ErrorReporter reporter,
    String filePath,
    String className,
    String methodName,
  ) {
    final body = method.body;
    final bodyString = body.toString();
    final currentAbstraction = _detectAbstractionLevel(filePath);

    // Check for direct instantiation of concrete classes
    final concreteDependencies = _findConcreteInstantiations(bodyString);
    for (final concrete in concreteDependencies) {
      final dependencyAbstraction = _inferTypeAbstraction(concrete);

      if (currentAbstraction > dependencyAbstraction) {
        final code = LintCode(
          name: 'core_dependency_rule',
          problemMessage: 'Method creates concrete dependency: $className.$methodName instantiates $concrete',
          correctionMessage: 'Use dependency injection or factory pattern to avoid direct instantiation.',
        );
        reporter.atNode(method, code);
      }
    }
  }

  void _performGlobalDependencyAnalysis(
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    // Check for circular dependencies that violate The Dependency Rule
    final cycles = _findDependencyCycles();
    for (final cycle in cycles) {
      _reportCircularDependency(cycle, reporter);
    }

    // Check for abstraction level consistency
    _validateAbstractionHierarchy(reporter);
  }

  int _detectAbstractionLevel(String path) {
    // Higher numbers = more abstract/inner layers

    // Domain/Entities (highest abstraction)
    if (_isDomainLayer(path)) return 4;

    // Application/Use Cases
    if (_isApplicationLayer(path)) return 3;

    // Interface Adapters (including presentation layer)
    if (_isAdapterLayer(path)) return 2;

    // Framework/Infrastructure (lowest abstraction)
    if (_isFrameworkLayer(path)) return 1;

    // External packages (even lower) - but exclude internal project paths
    if (path.startsWith('package:') && !_isInternalPackage(path)) {
      // Check if it's an internal presentation layer reference
      if (_isInternalPresentationReference(path)) {
        return 2; // Same level as adapter/presentation
      }
      return 0;
    }

    return 2; // Default to adapter level
  }

  int _inferTypeAbstraction(String typeName) {
    // Analyze type name to infer abstraction level
    final abstractIndicators = [
      'Interface',
      'Abstract',
      'Policy',
      'Rule',
      'Entity',
      'ValueObject',
      'Service',
      'Repository',
      'UseCase'
    ];

    final concreteIndicators = [
      'Implementation',
      'Concrete',
      'Adapter',
      'Client',
      'Database',
      'Http',
      'File',
      'Network',
      'Driver'
    ];

    if (abstractIndicators.any((indicator) => typeName.contains(indicator))) {
      return 4; // High abstraction
    }

    if (concreteIndicators.any((indicator) => typeName.contains(indicator))) {
      return 1; // Low abstraction
    }

    return 2; // Medium abstraction
  }

  List<String> _findConcreteInstantiations(String bodyString) {
    final instantiations = <String>[];
    final newPattern = RegExp(r'new\s+(\w+)\s*\(');
    final matches = newPattern.allMatches(bodyString);

    for (final match in matches) {
      final typeName = match.group(1);
      if (typeName != null && _isConcreteType(typeName)) {
        instantiations.add(typeName);
      }
    }

    return instantiations;
  }

  bool _isConcreteType(String typeName) {
    final concretePatterns = [
      'Database',
      'Http',
      'File',
      'Network',
      'Socket',
      'Client',
      'Server',
      'Driver',
      'Adapter',
      'Implementation'
    ];

    return concretePatterns.any((pattern) => typeName.contains(pattern));
  }

  List<List<DependencyNode>> _findDependencyCycles() {
    final cycles = <List<DependencyNode>>[];
    final visited = <String>{};
    final recursionStack = <String>{};

    for (final node in _dependencyGraph.values) {
      if (!visited.contains(node.path)) {
        final cycle = _detectCycle(node, visited, recursionStack, []);
        if (cycle.isNotEmpty) {
          cycles.add(cycle);
        }
      }
    }

    return cycles;
  }

  List<DependencyNode> _detectCycle(
    DependencyNode node,
    Set<String> visited,
    Set<String> recursionStack,
    List<DependencyNode> path,
  ) {
    visited.add(node.path);
    recursionStack.add(node.path);
    path.add(node);

    for (final dependency in node.dependencies) {
      if (!visited.contains(dependency.path)) {
        final cycle = _detectCycle(dependency, visited, recursionStack, List.from(path));
        if (cycle.isNotEmpty) return cycle;
      } else if (recursionStack.contains(dependency.path)) {
        // Found cycle
        final cycleStart = path.indexWhere((n) => n.path == dependency.path);
        return path.sublist(cycleStart);
      }
    }

    recursionStack.remove(node.path);
    return [];
  }

  void _validateAbstractionHierarchy(ErrorReporter reporter) {
    // Check that abstraction levels are properly ordered
    for (final node in _dependencyGraph.values) {
      for (final dependency in node.dependencies) {
        if (node.abstractionLevel > dependency.abstractionLevel) {
          // This is a valid dependency (inner depends on outer through abstraction)
          // But we should verify it's actually going through an abstraction
        }
      }
    }
  }

  void _checkSpecificAntiPatterns(
    ImportDirective node,
    ErrorReporter reporter,
    String filePath,
    String importUri,
  ) {
    // Domain layer importing infrastructure
    if (_isDomainLayer(filePath) && _isInfrastructureImport(importUri)) {
      final code = LintCode(
        name: 'core_dependency_rule',
        problemMessage: 'Domain layer cannot import infrastructure: $importUri',
        correctionMessage: 'Define an interface in domain and implement it in infrastructure.',
      );
      reporter.atNode(node, code);
    }

    // Use cases importing adapters
    if (_isApplicationLayer(filePath) && _isAdapterImport(importUri)) {
      final code = LintCode(
        name: 'core_dependency_rule',
        problemMessage: 'Use cases cannot import adapters: $importUri',
        correctionMessage: 'Use repository interfaces instead of adapter implementations.',
      );
      reporter.atNode(node, code);
    }

    // Entities importing anything but other entities
    if (_isEntityFile(filePath) && !_isEntityImport(importUri) && !_isDartCore(importUri)) {
      final code = LintCode(
        name: 'core_dependency_rule',
        problemMessage: 'Entity imports non-entity dependency: $importUri',
        correctionMessage: 'Entities should only depend on other entities and value objects.',
      );
      reporter.atNode(node, code);
    }
  }

  void _reportDependencyViolation(
    ImportDirective node,
    ErrorReporter reporter,
    String filePath,
    String importUri,
    int currentAbstraction,
    int importedAbstraction,
  ) {
    final currentLayer = _getLayerName(currentAbstraction);
    final importedLayer = _getLayerName(importedAbstraction);

    final code = LintCode(
      name: 'core_dependency_rule',
      problemMessage: 'Dependency direction violation: $currentLayer → $importedLayer ($importUri)',
      correctionMessage:
          'Use Dependency Inversion: create an interface in $currentLayer and implement it in $importedLayer.',
    );
    reporter.atNode(node, code);
  }

  void _reportFrameworkLeakage(
    ImportDirective node,
    ErrorReporter reporter,
    String importUri,
    String filePath,
  ) {
    final code = LintCode(
      name: 'core_dependency_rule',
      problemMessage: 'Framework dependency leaked to inner layer: $importUri',
      correctionMessage: 'Isolate framework dependencies in outer layer and use abstractions.',
    );
    reporter.atNode(node, code);
  }

  void _reportCircularDependency(
    List<DependencyNode> cycle,
    ErrorReporter reporter,
  ) {
    // Note: We can't report on specific nodes here since we don't have them
    // This would need to be enhanced to track original AST nodes
    // For future reference, cycle description would be:
    // cycle.map((n) => _getLayerName(n.abstractionLevel)).join(' → ')
  }

  String _getLayerName(int abstractionLevel) {
    switch (abstractionLevel) {
      case 4:
        return 'Domain';
      case 3:
        return 'Application';
      case 2:
        return 'Adapter';
      case 1:
        return 'Framework';
      case 0:
        return 'External';
      default:
        return 'Unknown';
    }
  }

  // Layer detection methods
  bool _isDomainLayer(String path) {
    return path.contains('/domain/') || path.contains('/entities/');
  }

  bool _isApplicationLayer(String path) {
    return path.contains('/usecases/') || path.contains('/application/');
  }

  bool _isAdapterLayer(String path) {
    return path.contains('/adapters/') || path.contains('/controllers/') || path.contains('/presenters/') || path.contains('/presentation/');
  }

  bool _isFrameworkLayer(String path) {
    return path.contains('/framework/') || path.contains('/infrastructure/');
  }

  bool _isInnerLayer(String path) {
    return _isDomainLayer(path) || _isApplicationLayer(path);
  }

  bool _isEntityFile(String path) {
    return path.contains('/entities/') || path.endsWith('_entity.dart');
  }

  bool _isFrameworkDependency(String importUri) {
    final frameworkPackages = [
      'package:flutter/',
      'package:sqflite/',
      'package:http/',
      'package:dio/',
      'dart:io',
      'dart:html'
    ];
    return frameworkPackages.any((pkg) => importUri.startsWith(pkg));
  }

  bool _isInfrastructureImport(String importUri) {
    return importUri.contains('/infrastructure/') || importUri.contains('/framework/');
  }

  bool _isAdapterImport(String importUri) {
    return importUri.contains('/adapters/') || importUri.contains('/controllers/');
  }

  bool _isEntityImport(String importUri) {
    return importUri.contains('/entities/') || importUri.contains('/domain/');
  }

  bool _isDartCore(String importUri) {
    return importUri.startsWith('dart:core') || importUri.startsWith('dart:async');
  }

  bool _isInternalPackage(String importUri) {
    // Core Flutter and Dart packages are always allowed
    if (importUri.startsWith('package:flutter/') || importUri.startsWith('package:dart')) {
      return true;
    }

    // Check if it's clearly an infrastructure package that should be restricted
    if (_isInfrastructurePackage(importUri)) {
      return false; // Infrastructure packages are "external" for dependency rule
    }

    // Everything else (UI, state management, utilities) is considered "internal"
    return true;
  }

  bool _isInfrastructurePackage(String importUri) {
    // Infrastructure packages that should be restricted in inner layers
    final infrastructurePatterns = [
      // Network/HTTP clients
      '/http/', '/dio/', '/chopper/', '/retrofit/',
      // Databases
      '/sqflite/', '/hive/', '/isar/', '/drift/', '/floor/',
      // Cloud services
      '/firebase_', '/cloud_', '/aws_', '/supabase/',
      // File system
      '/path_provider/', '/file_picker/', '/open_file/',
      // Platform-specific
      '/device_info/', '/package_info/', '/platform/',
      // Background services
      '/workmanager/', '/background_', '/isolate/',
      // Security/Auth infrastructure
      '/crypto/', '/encrypt/', '/local_auth/', '/biometric/',
      // External APIs
      '/google_', '/facebook_', '/twitter_', '/oauth/',
    ];

    return infrastructurePatterns.any((pattern) => importUri.contains(pattern));
  }

  bool _isInternalPresentationReference(String importUri) {
    // Check if it's an internal project reference to presentation layer
    // Pattern: package:project_name/features/.../presentation/...
    return importUri.contains('/presentation/') ||
           importUri.contains('/features/') ||
           importUri.contains('_state.dart') ||
           importUri.contains('_notifier.dart') ||
           importUri.contains('_provider.dart');
  }
}

class DependencyNode {
  final String path;
  final int abstractionLevel;
  final Set<DependencyNode> dependencies = {};

  DependencyNode(this.path, this.abstractionLevel);
}
