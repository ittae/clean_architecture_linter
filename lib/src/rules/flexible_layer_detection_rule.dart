import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../clean_architecture_linter_base.dart';

/// Flexible layer detection that adapts to custom Clean Architecture implementations.
///
/// This rule recognizes that projects may have:
/// - More than 4 layers
/// - Different naming conventions
/// - Custom architectural patterns
/// - Hexagonal, Onion, or other Clean Architecture variants
///
/// Key principles enforced:
/// - Dependencies always point inward (The Dependency Rule)
/// - Inner layers are more abstract than outer layers
/// - Layer responsibilities remain distinct
/// - Custom configurations can define layer hierarchies
class FlexibleLayerDetectionRule extends CleanArchitectureLintRule {
  const FlexibleLayerDetectionRule() : super(code: _code);

  static const _code = LintCode(
    name: 'flexible_layer_detection',
    problemMessage: 'Custom architecture layer violation: {0}',
    correctionMessage: 'Ensure dependencies point inward and maintain proper layer separation.',
  );

  @override
  void runRule(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addImportDirective((node) {
      _checkLayerDependency(node, reporter, resolver);
    });

    context.registry.addClassDeclaration((node) {
      _checkLayerResponsibility(node, reporter, resolver);
    });
  }

  void _checkLayerDependency(
    ImportDirective node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    final importUri = node.uri.stringValue;
    if (importUri == null) return;

    final currentLayer = _detectCustomLayer(filePath);
    final importedLayer = _detectCustomLayerFromImport(importUri);

    if (currentLayer != null && importedLayer != null) {
      if (!_isValidDependencyDirection(currentLayer, importedLayer)) {
        final code = LintCode(
          name: 'flexible_layer_detection',
          problemMessage:
              'Invalid dependency: ${currentLayer.name} → ${importedLayer.name}. Dependencies must point inward.',
          correctionMessage:
              'Restructure to make ${importedLayer.name} depend on ${currentLayer.name} through abstractions.',
        );
        reporter.atNode(node, code);
      }
    }
  }

  void _checkLayerResponsibility(
    ClassDeclaration node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    final layer = _detectCustomLayer(filePath);
    if (layer == null) return;

    final violations = _checkLayerResponsibilityViolations(node, layer);
    for (final violation in violations) {
      reporter.atNode(node, violation);
    }
  }

  CustomLayer? _detectCustomLayer(String filePath) {
    // Try to detect common Clean Architecture patterns

    // Hexagonal Architecture (Ports & Adapters)
    if (_isHexagonalPattern(filePath)) {
      return _detectHexagonalLayer(filePath);
    }

    // Onion Architecture
    if (_isOnionPattern(filePath)) {
      return _detectOnionLayer(filePath);
    }

    // Traditional Clean Architecture
    if (_isTraditionalCleanPattern(filePath)) {
      return _detectTraditionalLayer(filePath);
    }

    // Custom patterns based on common indicators
    return _detectByCommonIndicators(filePath);
  }

  CustomLayer? _detectCustomLayerFromImport(String importUri) {
    // External packages (outermost)
    if (_isExternalPackage(importUri)) {
      return CustomLayer(
        name: 'external',
        level: 0,
        type: LayerType.infrastructure,
        responsibilities: ['External dependencies', 'Third-party frameworks'],
      );
    }

    // Detect from path patterns
    if (importUri.startsWith('package:')) return null;

    return _detectCustomLayer(importUri);
  }

  bool _isHexagonalPattern(String filePath) {
    final hexagonalIndicators = ['/ports/', '/adapters/', '/hexagon/', '/application/core'];
    return hexagonalIndicators.any((indicator) => filePath.contains(indicator));
  }

  bool _isOnionPattern(String filePath) {
    final onionIndicators = ['/core/', '/application/services/', '/infrastructure/services', '/domain/services'];
    return onionIndicators.any((indicator) => filePath.contains(indicator));
  }

  bool _isTraditionalCleanPattern(String filePath) {
    final traditionalIndicators = ['/entities/', '/use_cases/', '/interface_adapters/', '/frameworks'];
    return traditionalIndicators.any((indicator) => filePath.contains(indicator));
  }

  CustomLayer? _detectHexagonalLayer(String filePath) {
    if (filePath.contains('/ports/')) {
      return CustomLayer(
        name: 'ports',
        level: 3,
        type: LayerType.domain,
        responsibilities: ['Define interfaces', 'Abstract boundaries'],
      );
    }

    if (filePath.contains('/adapters/primary/')) {
      return CustomLayer(
        name: 'primary_adapters',
        level: 2,
        type: LayerType.adapter,
        responsibilities: ['UI', 'Controllers', 'API endpoints'],
      );
    }

    if (filePath.contains('/adapters/secondary/')) {
      return CustomLayer(
        name: 'secondary_adapters',
        level: 1,
        type: LayerType.infrastructure,
        responsibilities: ['Database', 'External services', 'File system'],
      );
    }

    if (filePath.contains('/application/core') || filePath.contains('/hexagon/')) {
      return CustomLayer(
        name: 'application_core',
        level: 4,
        type: LayerType.application,
        responsibilities: ['Business logic', 'Use cases', 'Services'],
      );
    }

    return null;
  }

  CustomLayer? _detectOnionLayer(String filePath) {
    if (filePath.contains('/domain/entities') || filePath.contains('/core/entities')) {
      return CustomLayer(
        name: 'domain_entities',
        level: 5,
        type: LayerType.domain,
        responsibilities: ['Enterprise business rules', 'Core entities'],
      );
    }

    if (filePath.contains('/domain/services') || filePath.contains('/core/services')) {
      return CustomLayer(
        name: 'domain_services',
        level: 4,
        type: LayerType.domain,
        responsibilities: ['Domain services', 'Business logic coordination'],
      );
    }

    if (filePath.contains('/application/services')) {
      return CustomLayer(
        name: 'application_services',
        level: 3,
        type: LayerType.application,
        responsibilities: ['Application use cases', 'Workflow orchestration'],
      );
    }

    if (filePath.contains('/infrastructure/services')) {
      return CustomLayer(
        name: 'infrastructure_services',
        level: 1,
        type: LayerType.infrastructure,
        responsibilities: ['External service implementations', 'Technical details'],
      );
    }

    return null;
  }

  CustomLayer? _detectTraditionalLayer(String filePath) {
    if (filePath.contains('/entities/')) {
      return CustomLayer(
        name: 'entities',
        level: 4,
        type: LayerType.domain,
        responsibilities: ['Enterprise business rules'],
      );
    }

    if (filePath.contains('/use_cases/') || filePath.contains('/usecases/')) {
      return CustomLayer(
        name: 'use_cases',
        level: 3,
        type: LayerType.application,
        responsibilities: ['Application business rules'],
      );
    }

    if (filePath.contains('/interface_adapters/')) {
      return CustomLayer(
        name: 'interface_adapters',
        level: 2,
        type: LayerType.adapter,
        responsibilities: ['Data conversion', 'Protocol translation'],
      );
    }

    if (filePath.contains('/frameworks/') || filePath.contains('/drivers/')) {
      return CustomLayer(
        name: 'frameworks_drivers',
        level: 1,
        type: LayerType.infrastructure,
        responsibilities: ['Framework details', 'External interfaces'],
      );
    }

    return null;
  }

  CustomLayer? _detectByCommonIndicators(String filePath) {
    // Infrastructure layer indicators (outermost)
    final infrastructurePatterns = [
      '/infrastructure/',
      '/persistence/',
      '/database/',
      '/network/',
      '/http/',
      '/api/client/',
      '/external/',
      '/third_party/'
    ];

    for (final pattern in infrastructurePatterns) {
      if (filePath.contains(pattern)) {
        return CustomLayer(
          name: 'infrastructure',
          level: 1,
          type: LayerType.infrastructure,
          responsibilities: ['Technical implementation', 'External dependencies'],
        );
      }
    }

    // Adapter layer indicators
    final adapterPatterns = [
      '/adapters/',
      '/controllers/',
      '/presenters/',
      '/gateways/',
      '/ui/',
      '/web/',
      '/api/handlers/',
      '/cli/'
    ];

    for (final pattern in adapterPatterns) {
      if (filePath.contains(pattern)) {
        return CustomLayer(
          name: 'adapters',
          level: 2,
          type: LayerType.adapter,
          responsibilities: ['Interface adaptation', 'Data transformation'],
        );
      }
    }

    // Application layer indicators
    final applicationPatterns = [
      '/application/',
      '/use_cases/',
      '/usecases/',
      '/services/',
      '/workflows/',
      '/processes/',
      '/handlers/'
    ];

    for (final pattern in applicationPatterns) {
      if (filePath.contains(pattern)) {
        return CustomLayer(
          name: 'application',
          level: 3,
          type: LayerType.application,
          responsibilities: ['Application logic', 'Use case orchestration'],
        );
      }
    }

    // Domain layer indicators (innermost)
    final domainPatterns = ['/domain/', '/entities/', '/models/', '/core/', '/business/', '/rules/', '/policies/'];

    for (final pattern in domainPatterns) {
      if (filePath.contains(pattern)) {
        return CustomLayer(
          name: 'domain',
          level: 4,
          type: LayerType.domain,
          responsibilities: ['Business rules', 'Enterprise logic'],
        );
      }
    }

    return null;
  }

  bool _isValidDependencyDirection(CustomLayer from, CustomLayer to) {
    // Dependencies must point inward (toward higher levels)
    return from.level <= to.level;
  }

  List<LintCode> _checkLayerResponsibilityViolations(
    ClassDeclaration node,
    CustomLayer layer,
  ) {
    final violations = <LintCode>[];
    final className = node.name.lexeme;

    // Check if class responsibilities match layer expectations
    switch (layer.type) {
      case LayerType.infrastructure:
        violations.addAll(_checkInfrastructureViolations(node, className, layer));
        break;
      case LayerType.adapter:
        violations.addAll(_checkAdapterViolations(node, className, layer));
        break;
      case LayerType.application:
        violations.addAll(_checkApplicationViolations(node, className, layer));
        break;
      case LayerType.domain:
        violations.addAll(_checkDomainViolations(node, className, layer));
        break;
    }

    return violations;
  }

  List<LintCode> _checkInfrastructureViolations(
    ClassDeclaration node,
    String className,
    CustomLayer layer,
  ) {
    final violations = <LintCode>[];

    // Infrastructure should not contain business logic
    if (_containsBusinessLogic(node)) {
      violations.add(LintCode(
        name: 'flexible_layer_detection',
        problemMessage: '${layer.name} layer contains business logic: $className',
        correctionMessage: 'Move business logic to application or domain layers.',
      ));
    }

    return violations;
  }

  List<LintCode> _checkAdapterViolations(
    ClassDeclaration node,
    String className,
    CustomLayer layer,
  ) {
    final violations = <LintCode>[];

    // Adapters should focus on conversion
    if (_lackConversionFocus(node)) {
      violations.add(LintCode(
        name: 'flexible_layer_detection',
        problemMessage: '${layer.name} layer class lacks clear conversion responsibility: $className',
        correctionMessage: 'Focus adapter on data/protocol conversion between layers.',
      ));
    }

    return violations;
  }

  List<LintCode> _checkApplicationViolations(
    ClassDeclaration node,
    String className,
    CustomLayer layer,
  ) {
    final violations = <LintCode>[];

    // Application layer should orchestrate, not implement details
    if (_containsImplementationDetails(node)) {
      violations.add(LintCode(
        name: 'flexible_layer_detection',
        problemMessage: '${layer.name} layer contains implementation details: $className',
        correctionMessage: 'Move implementation details to infrastructure layer.',
      ));
    }

    return violations;
  }

  List<LintCode> _checkDomainViolations(
    ClassDeclaration node,
    String className,
    CustomLayer layer,
  ) {
    final violations = <LintCode>[];

    // Domain should be pure business logic
    if (_containsInfrastructureConcerns(node)) {
      violations.add(LintCode(
        name: 'flexible_layer_detection',
        problemMessage: '${layer.name} layer contains infrastructure concerns: $className',
        correctionMessage: 'Keep domain layer pure - remove infrastructure dependencies.',
      ));
    }

    return violations;
  }

  bool _isExternalPackage(String importUri) {
    if (!importUri.startsWith('package:')) {
      return false;
    }

    // Flutter and Dart packages are not external
    if (importUri.startsWith('package:flutter/') ||
        importUri.startsWith('package:dart')) {
      return false;
    }

    // Internal project packages (same project name) are not external
    // Extract project name from import URI: package:project_name/...
    final packageNameMatch = RegExp(r'package:([^/]+)/').firstMatch(importUri);
    if (packageNameMatch != null) {
      final packageName = packageNameMatch.group(1);
      // Common internal project names that should not be treated as external
      final internalPackages = ['ittae', 'app', 'core', 'shared', 'common'];
      if (internalPackages.contains(packageName)) {
        return false;
      }
    }

    return true;
  }

  bool _containsBusinessLogic(ClassDeclaration node) {
    final businessPatterns = ['validate', 'calculate', 'process', 'apply', 'business', 'rule', 'policy', 'workflow'];

    return node.members.any((member) {
      if (member is MethodDeclaration) {
        final methodName = member.name.lexeme.toLowerCase();
        return businessPatterns.any((pattern) => methodName.contains(pattern));
      }
      return false;
    });
  }

  bool _lackConversionFocus(ClassDeclaration node) {
    final conversionPatterns = ['convert', 'transform', 'adapt', 'map', 'to', 'from', 'parse', 'serialize'];

    final hasConversionMethods = node.members.any((member) {
      if (member is MethodDeclaration) {
        final methodName = member.name.lexeme.toLowerCase();
        return conversionPatterns.any((pattern) => methodName.contains(pattern));
      }
      return false;
    });

    return !hasConversionMethods;
  }

  bool _containsImplementationDetails(ClassDeclaration node) {
    final detailPatterns = ['http', 'sql', 'file', 'network', 'database', 'connection', 'socket', 'stream'];

    return node.members.any((member) {
      if (member is MethodDeclaration) {
        final methodName = member.name.lexeme.toLowerCase();
        return detailPatterns.any((pattern) => methodName.contains(pattern));
      }
      return false;
    });
  }

  bool _containsInfrastructureConcerns(ClassDeclaration node) {
    final infrastructurePatterns = [
      'database',
      'http',
      'file',
      'cache',
      'logger',
      'configuration',
      'environment',
      'system'
    ];

    return node.members.any((member) {
      if (member is FieldDeclaration) {
        final type = member.fields.type;
        if (type is NamedType) {
          final typeName = type.name2.lexeme.toLowerCase();
          return infrastructurePatterns.any((pattern) => typeName.contains(pattern));
        }
      }
      return false;
    });
  }
}

class CustomLayer {
  final String name;
  final int level; // Higher level = more inner (abstract)
  final LayerType type;
  final List<String> responsibilities;

  const CustomLayer({
    required this.name,
    required this.level,
    required this.type,
    required this.responsibilities,
  });
}

enum LayerType {
  infrastructure, // Framework details, external dependencies
  adapter, // Interface adapters, controllers, presenters
  application, // Use cases, application services
  domain, // Entities, business rules
}
