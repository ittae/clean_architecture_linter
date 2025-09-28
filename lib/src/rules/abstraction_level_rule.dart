import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../clean_architecture_linter_base.dart';

/// Enforces that abstraction levels increase as you move inward in the architecture.
///
/// This rule validates that:
/// - Outer layers contain concrete, low-level details
/// - Inner layers contain abstract, high-level policies
/// - Dependencies always point toward higher abstraction levels
/// - Each layer is more general than the layers outside it
///
/// Abstraction levels (from outer to inner):
/// 1. Framework/Infrastructure: Concrete implementations, external details
/// 2. Interface Adapters: Conversion logic, adapters, controllers
/// 3. Application/Use Cases: Application-specific business rules
/// 4. Domain/Entities: Enterprise-wide business rules, most abstract
class AbstractionLevelRule extends CleanArchitectureLintRule {
  const AbstractionLevelRule() : super(code: _code);

  static const _code = LintCode(
    name: 'abstraction_level',
    problemMessage:
        'Abstraction level violation: {0}',
    correctionMessage:
        'Move concrete details to outer layers and abstract policies to inner layers.',
  );

  @override
  void runRule(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addImportDirective((node) {
      _checkImportAbstractionLevel(node, reporter, resolver);
    });

    context.registry.addClassDeclaration((node) {
      _checkClassAbstractionLevel(node, reporter, resolver);
    });

    context.registry.addMethodDeclaration((node) {
      _checkMethodAbstractionLevel(node, reporter, resolver);
    });
  }

  void _checkImportAbstractionLevel(
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
      final currentLevel = _getAbstractionLevel(currentLayer);
      final importedLevel = _getAbstractionLevel(importedLayer);

      // Inner layers should not depend on outer layers
      if (currentLevel > importedLevel) {
        final code = LintCode(
          name: 'abstraction_level',
          problemMessage:
              'Higher abstraction layer ($currentLayer) depends on lower abstraction layer ($importedLayer): $importUri',
          correctionMessage:
              'Invert dependency: make $importedLayer depend on $currentLayer abstractions.',
        );
        reporter.atNode(node, code);
      }
    }
  }

  void _checkClassAbstractionLevel(
    ClassDeclaration node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    final layer = _detectLayer(filePath);
    if (layer == null) return;

    final className = node.name.lexeme;
    final expectedAbstraction = _getExpectedAbstractionForLayer(layer);
    final actualAbstraction = _analyzeClassAbstraction(node);

    if (!_isAbstractionAppropriate(actualAbstraction, expectedAbstraction, layer)) {
      final code = LintCode(
        name: 'abstraction_level',
        problemMessage:
            '$layer layer class has inappropriate abstraction level: $className',
        correctionMessage:
            _getAbstractionAdvice(layer, actualAbstraction, expectedAbstraction),
      );
      reporter.atNode(node, code);
    }
  }

  void _checkMethodAbstractionLevel(
    MethodDeclaration method,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    final layer = _detectLayer(filePath);
    if (layer == null) return;

    // Skip abstract methods and repository interface methods
    if (method.isAbstract || CleanArchitectureUtils.isRepositoryInterfaceMethod(method)) {
      return; // Repository interface methods are inherently appropriate for domain layer
    }

    final methodName = method.name.lexeme;
    final methodAbstraction = _analyzeMethodAbstraction(method);
    final expectedAbstraction = _getExpectedAbstractionForLayer(layer);

    if (!_isMethodAbstractionAppropriate(methodAbstraction, expectedAbstraction, layer)) {
      final code = LintCode(
        name: 'abstraction_level',
        problemMessage:
            'Method abstraction inappropriate for $layer layer: $methodName',
        correctionMessage:
            _getMethodAbstractionAdvice(layer, methodAbstraction),
      );
      reporter.atNode(method, code);
    }
  }

  ArchitectureLayer? _detectLayer(String filePath) {
    // Framework/Infrastructure (outermost, most concrete)
    if (_isFrameworkLayer(filePath)) return ArchitectureLayer.framework;

    // Interface Adapters
    if (_isAdapterLayer(filePath)) return ArchitectureLayer.adapter;

    // Application/Use Cases
    if (_isApplicationLayer(filePath)) return ArchitectureLayer.application;

    // Domain/Entities (innermost, most abstract)
    if (_isDomainLayer(filePath)) return ArchitectureLayer.domain;

    return null;
  }

  ArchitectureLayer? _detectLayerFromImport(String importUri) {
    if (_isFrameworkImport(importUri)) return ArchitectureLayer.framework;
    if (_isAdapterImport(importUri)) return ArchitectureLayer.adapter;
    if (_isApplicationImport(importUri)) return ArchitectureLayer.application;
    if (_isDomainImport(importUri)) return ArchitectureLayer.domain;
    return null;
  }

  int _getAbstractionLevel(ArchitectureLayer layer) {
    switch (layer) {
      case ArchitectureLayer.framework:
        return 1; // Lowest abstraction (concrete details)
      case ArchitectureLayer.adapter:
        return 2; // Low-medium abstraction (adapters, converters)
      case ArchitectureLayer.application:
        return 3; // Medium-high abstraction (use cases)
      case ArchitectureLayer.domain:
        return 4; // Highest abstraction (enterprise rules)
    }
  }

  AbstractionLevel _getExpectedAbstractionForLayer(ArchitectureLayer layer) {
    switch (layer) {
      case ArchitectureLayer.framework:
        return AbstractionLevel.concrete;
      case ArchitectureLayer.adapter:
        return AbstractionLevel.lowAbstract;
      case ArchitectureLayer.application:
        return AbstractionLevel.mediumAbstract;
      case ArchitectureLayer.domain:
        return AbstractionLevel.highAbstract;
    }
  }

  AbstractionLevel _analyzeClassAbstraction(ClassDeclaration node) {
    final className = node.name.lexeme;

    // Check for concrete indicators
    if (_hasConcreteIndicators(node, className)) {
      return AbstractionLevel.concrete;
    }

    // Check for abstract indicators
    if (_hasHighAbstractionIndicators(node, className)) {
      return AbstractionLevel.highAbstract;
    }

    // Check for medium abstraction
    if (_hasMediumAbstractionIndicators(node, className)) {
      return AbstractionLevel.mediumAbstract;
    }

    return AbstractionLevel.lowAbstract;
  }

  MethodAbstractionLevel _analyzeMethodAbstraction(MethodDeclaration method) {
    final methodName = method.name.lexeme;

    // Analyze method characteristics
    if (_isConcreteMethod(method, methodName)) {
      return MethodAbstractionLevel.concrete;
    }

    if (_isHighLevelPolicyMethod(method, methodName)) {
      return MethodAbstractionLevel.policy;
    }

    if (_isCoordinationMethod(method, methodName)) {
      return MethodAbstractionLevel.coordination;
    }

    return MethodAbstractionLevel.implementation;
  }

  bool _hasConcreteIndicators(ClassDeclaration node, String className) {
    final concreteIndicators = [
      'Database', 'Http', 'File', 'Network', 'Socket',
      'Driver', 'Adapter', 'Client', 'Server', 'Connection',
      'Implementation', 'Concrete', 'Specific'
    ];

    return concreteIndicators.any((indicator) =>
        className.contains(indicator));
  }

  bool _hasHighAbstractionIndicators(ClassDeclaration node, String className) {
    final abstractIndicators = [
      'Policy', 'Rule', 'Entity', 'ValueObject',
      'Specification', 'Strategy', 'Abstract', 'Interface'
    ];

    final hasAbstractName = abstractIndicators.any((indicator) =>
        className.contains(indicator));

    // Check if class is abstract or interface-like
    final isAbstractClass = node.abstractKeyword != null;
    final hasOnlyAbstractMethods = _hasOnlyAbstractMethods(node);

    return hasAbstractName || isAbstractClass || hasOnlyAbstractMethods;
  }

  bool _hasMediumAbstractionIndicators(ClassDeclaration node, String className) {
    final mediumIndicators = [
      'UseCase', 'Service', 'Interactor', 'Application',
      'Workflow', 'Process', 'Orchestrator'
    ];

    return mediumIndicators.any((indicator) =>
        className.contains(indicator));
  }

  bool _hasOnlyAbstractMethods(ClassDeclaration node) {
    final methods = node.members.whereType<MethodDeclaration>();
    if (methods.isEmpty) return false;

    return methods.every((method) =>
        method.isAbstract || _isGetterSetter(method));
  }

  bool _isGetterSetter(MethodDeclaration method) {
    return method.isGetter || method.isSetter;
  }

  bool _isConcreteMethod(MethodDeclaration method, String methodName) {
    final concretePatterns = [
      'connect', 'disconnect', 'read', 'write', 'save', 'load',
      'serialize', 'deserialize', 'parse', 'format', 'convert',
      'http', 'sql', 'file', 'network', 'database'
    ];

    final hasConcretePattern = concretePatterns.any((pattern) =>
        methodName.toLowerCase().contains(pattern));

    // Check method body for concrete operations
    final body = method.body;
    final bodyString = body.toString().toLowerCase();
    final concreteBodyPatterns = [
      'http.', 'file.', 'database.', 'connection.',
      'socket.', 'stream.', 'buffer.'
    ];

    final hasConcreteBody = concreteBodyPatterns.any((pattern) =>
        bodyString.contains(pattern));

    return hasConcretePattern || hasConcreteBody;
  }

  bool _isHighLevelPolicyMethod(MethodDeclaration method, String methodName) {
    final policyPatterns = [
      'validate', 'enforce', 'apply', 'check', 'verify',
      'authorize', 'authenticate', 'calculate', 'determine',
      'evaluate', 'assess', 'decide'
    ];

    return policyPatterns.any((pattern) =>
        methodName.toLowerCase().contains(pattern));
  }

  bool _isCoordinationMethod(MethodDeclaration method, String methodName) {
    final coordinationPatterns = [
      'execute', 'perform', 'handle', 'process', 'manage',
      'coordinate', 'orchestrate', 'delegate', 'invoke'
    ];

    return coordinationPatterns.any((pattern) =>
        methodName.toLowerCase().contains(pattern));
  }

  bool _isAbstractionAppropriate(
    AbstractionLevel actual,
    AbstractionLevel expected,
    ArchitectureLayer layer,
  ) {
    // Framework layer should be concrete
    if (layer == ArchitectureLayer.framework) {
      return actual == AbstractionLevel.concrete ||
             actual == AbstractionLevel.lowAbstract;
    }

    // Domain layer should be highly abstract
    if (layer == ArchitectureLayer.domain) {
      return actual == AbstractionLevel.highAbstract ||
             actual == AbstractionLevel.mediumAbstract;
    }

    // Other layers have some flexibility
    return true;
  }

  bool _isMethodAbstractionAppropriate(
    MethodAbstractionLevel actual,
    AbstractionLevel expectedClass,
    ArchitectureLayer layer,
  ) {
    switch (layer) {
      case ArchitectureLayer.framework:
        return actual == MethodAbstractionLevel.concrete ||
               actual == MethodAbstractionLevel.implementation;
      case ArchitectureLayer.adapter:
        return actual != MethodAbstractionLevel.policy;
      case ArchitectureLayer.application:
        return actual == MethodAbstractionLevel.coordination ||
               actual == MethodAbstractionLevel.implementation;
      case ArchitectureLayer.domain:
        return actual == MethodAbstractionLevel.policy ||
               actual == MethodAbstractionLevel.coordination;
    }
  }

  String _getAbstractionAdvice(
    ArchitectureLayer layer,
    AbstractionLevel actual,
    AbstractionLevel expected,
  ) {
    switch (layer) {
      case ArchitectureLayer.framework:
        return 'Framework layer should contain concrete implementations and low-level details.';
      case ArchitectureLayer.adapter:
        return 'Adapter layer should focus on conversion and adaptation logic.';
      case ArchitectureLayer.application:
        return 'Application layer should contain coordination and orchestration logic.';
      case ArchitectureLayer.domain:
        return 'Domain layer should contain abstract business rules and policies.';
    }
  }

  String _getMethodAbstractionAdvice(
    ArchitectureLayer layer,
    MethodAbstractionLevel actual,
  ) {
    switch (layer) {
      case ArchitectureLayer.framework:
        return 'Framework methods should handle concrete operations and technical details.';
      case ArchitectureLayer.adapter:
        return 'Adapter methods should focus on data conversion and protocol translation.';
      case ArchitectureLayer.application:
        return 'Application methods should coordinate entities and enforce application rules.';
      case ArchitectureLayer.domain:
        return 'Domain methods should implement business policies and enterprise rules.';
    }
  }

  // Layer detection methods
  bool _isFrameworkLayer(String filePath) {
    final frameworkPaths = [
      '/framework/', '/infrastructure/', '/web/', '/database/',
      '/http/', '/server/', '/api/', '/main.dart'
    ];
    return frameworkPaths.any((path) => filePath.contains(path));
  }

  bool _isAdapterLayer(String filePath) {
    final adapterPaths = [
      '/adapters/', '/interface_adapters/', '/controllers/',
      '/presenters/', '/gateways/', '/ui/', '/presentation/'
    ];
    return adapterPaths.any((path) => filePath.contains(path));
  }

  bool _isApplicationLayer(String filePath) {
    final applicationPaths = [
      '/usecases/', '/use_cases/', '/application/', '/interactors/'
    ];
    return applicationPaths.any((path) => filePath.contains(path));
  }

  bool _isDomainLayer(String filePath) {
    final domainPaths = [
      '/domain/', '/entities/', '/models/', '/core/'
    ];
    return domainPaths.any((path) => filePath.contains(path));
  }

  bool _isFrameworkImport(String importUri) {
    final frameworkImports = [
      'package:sqflite/', 'package:http/', 'package:dio/',
      'dart:io', 'dart:html'
    ];

    // Flutter UI imports are acceptable in presentation/adapter layer
    final flutterUIImports = [
      'package:flutter/material.dart',
      'package:flutter/widgets.dart',
      'package:flutter/cupertino.dart',
      'package:flutter/services.dart',
    ];

    // If it's a Flutter UI import, don't treat as framework violation
    if (flutterUIImports.any((import) => importUri == import)) {
      return false;
    }

    // Other Flutter imports (like foundation, painting, etc.) are framework-level
    if (importUri.startsWith('package:flutter/')) {
      final allowedFlutterPaths = [
        'package:flutter/material.dart',
        'package:flutter/widgets.dart',
        'package:flutter/cupertino.dart',
        'package:flutter/services.dart',
      ];
      return !allowedFlutterPaths.contains(importUri);
    }

    return frameworkImports.any((import) => importUri.startsWith(import));
  }

  bool _isAdapterImport(String importUri) {
    return importUri.contains('/adapters/') ||
           importUri.contains('/controllers/') ||
           importUri.contains('/presenters/');
  }

  bool _isApplicationImport(String importUri) {
    return importUri.contains('/usecases/') ||
           importUri.contains('/application/');
  }

  bool _isDomainImport(String importUri) {
    return importUri.contains('/domain/') ||
           importUri.contains('/entities/');
  }

}

enum ArchitectureLayer {
  framework,  // Outermost, most concrete
  adapter,    // Interface adapters
  application, // Use cases
  domain,     // Innermost, most abstract
}

enum AbstractionLevel {
  concrete,      // Framework implementations
  lowAbstract,   // Simple adapters
  mediumAbstract, // Use cases, services
  highAbstract,  // Domain entities, policies
}

enum MethodAbstractionLevel {
  concrete,      // Low-level operations
  implementation, // Specific implementations
  coordination,  // Orchestration logic
  policy,        // High-level rules
}