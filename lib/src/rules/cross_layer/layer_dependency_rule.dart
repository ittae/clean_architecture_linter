import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show ErrorSeverity;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../clean_architecture_linter_base.dart';

/// Enforces proper dependency direction between architectural layers.
///
/// This rule ensures that dependencies only flow inward according to Clean Architecture:
/// - Presentation layer can depend on: Domain layer (not Data layer directly)
/// - Data layer can depend on: Domain layer
/// - Domain layer can depend on: Nothing (must remain pure)
///
/// The rule prevents:
/// - Presentation layer from directly accessing Data layer (must go through Domain)
/// - Data layer from accessing Presentation layer
/// - Domain layer from accessing Data or Presentation layers
/// - Circular dependencies between layers
class LayerDependencyRule extends CleanArchitectureLintRule {
  const LayerDependencyRule() : super(code: _code);

  static const _code = LintCode(
    name: 'layer_dependency',
    problemMessage:
        'Improper dependency between architectural layers detected.',
    correctionMessage:
        'Ensure dependencies flow inward: Presentation → Domain ← Data. Never skip layers or create circular dependencies.',
    errorSeverity: ErrorSeverity.ERROR,
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
  }

  void _checkLayerDependency(
    ImportDirective node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    final importUri = node.uri.stringValue;
    if (importUri == null) return;

    // Skip dependency checking for DI/provider files - they act as composition root
    if (_isDependencyInjectionFile(filePath)) {
      return;
    }

    final sourceLayer = _identifyLayer(filePath);
    final targetLayer = _identifyLayer(importUri);

    if (sourceLayer == null || targetLayer == null) return;

    final violation = _checkDependencyViolation(
      sourceLayer,
      targetLayer,
      importUri,
    );

    if (violation != null) {
      final enhancedCode = LintCode(
        name: 'layer_dependency',
        problemMessage: violation.message,
        correctionMessage: violation.suggestion,
        errorSeverity: ErrorSeverity.ERROR,
      );
      reporter.atNode(node, enhancedCode);
    }
  }

  LayerViolation? _checkDependencyViolation(
    ArchitectureLayer source,
    ArchitectureLayer target,
    String importPath,
  ) {
    // Allow cross-cutting concerns in all layers
    if (_isCrossCuttingConcern(importPath)) {
      return null;
    }

    switch (source) {
      case ArchitectureLayer.domain:
        if (target == ArchitectureLayer.data) {
          return LayerViolation(
            message:
                'Domain layer cannot depend on Data layer. Found import: $importPath',
            suggestion:
                'Domain layer must remain pure. Use dependency inversion - create abstractions in Domain that Data layer implements.',
          );
        }
        if (target == ArchitectureLayer.presentation) {
          return LayerViolation(
            message:
                'Domain layer cannot depend on Presentation layer. Found import: $importPath',
            suggestion:
                'Domain layer must remain independent of UI concerns. Move UI-specific logic to Presentation layer.',
          );
        }
        if (target == ArchitectureLayer.infrastructure) {
          return LayerViolation(
            message:
                'Domain layer cannot depend on Infrastructure. Found import: $importPath',
            suggestion:
                'Create domain abstractions (interfaces) and implement them in Infrastructure/Data layer.',
          );
        }
        break;

      case ArchitectureLayer.data:
        if (target == ArchitectureLayer.presentation) {
          return LayerViolation(
            message:
                'Data layer cannot depend on Presentation layer. Found import: $importPath',
            suggestion:
                'Data layer should only depend on Domain layer. Remove presentation dependencies.',
          );
        }
        if (target == ArchitectureLayer.infrastructure &&
            !_isAllowedInfrastructureImport(importPath)) {
          return LayerViolation(
            message:
                'Data layer has suspicious Infrastructure dependency: $importPath',
            suggestion:
                'Ensure this infrastructure dependency is appropriate for data layer responsibilities.',
          );
        }
        break;

      case ArchitectureLayer.presentation:
        if (target == ArchitectureLayer.data) {
          return LayerViolation(
            message:
                'Presentation layer should not directly depend on Data layer. Found import: $importPath',
            suggestion:
                'Presentation should interact with Domain layer (Use Cases) instead of Data layer directly. Apply Dependency Rule.',
          );
        }
        if (target == ArchitectureLayer.infrastructure &&
            !_isAllowedPresentationInfrastructure(importPath)) {
          return LayerViolation(
            message:
                'Presentation layer has improper Infrastructure dependency: $importPath',
            suggestion:
                'Use Domain abstractions instead of direct infrastructure dependencies in Presentation.',
          );
        }
        break;

      case ArchitectureLayer.infrastructure:
        if (target == ArchitectureLayer.presentation) {
          return LayerViolation(
            message:
                'Infrastructure cannot depend on Presentation layer. Found import: $importPath',
            suggestion:
                'Infrastructure should only provide services, not depend on UI.',
          );
        }
        break;

      case ArchitectureLayer.application:
        // Application/Use Case layer (part of Domain) follows same rules as Domain
        if (target == ArchitectureLayer.data ||
            target == ArchitectureLayer.presentation ||
            target == ArchitectureLayer.infrastructure) {
          return LayerViolation(
            message:
                'Application layer cannot depend on outer layers. Found import: $importPath',
            suggestion:
                'Application layer should only depend on Domain entities and abstractions.',
          );
        }
        break;
    }

    return null;
  }

  ArchitectureLayer? _identifyLayer(String path) {
    // Normalize path separators
    final normalizedPath = path.replaceAll('\\', '/').toLowerCase();

    // Check for domain layer and its sub-layers
    if (normalizedPath.contains('/domain/')) {
      if (normalizedPath.contains('/domain/usecases/') ||
          normalizedPath.contains('/domain/use_cases/')) {
        return ArchitectureLayer.application;
      }
      return ArchitectureLayer.domain;
    }

    // Check for data layer
    if (normalizedPath.contains('/data/')) {
      return ArchitectureLayer.data;
    }

    // Check for presentation layer
    if (normalizedPath.contains('/presentation/') ||
        normalizedPath.contains('/ui/') ||
        normalizedPath.contains('/widgets/') ||
        normalizedPath.contains('/screens/') ||
        normalizedPath.contains('/pages/') ||
        normalizedPath.contains('/views/')) {
      return ArchitectureLayer.presentation;
    }

    // Check for infrastructure layer
    if (normalizedPath.contains('/infrastructure/') ||
        normalizedPath.contains('/services/') ||
        normalizedPath.contains('/external/')) {
      return ArchitectureLayer.infrastructure;
    }

    // Check for common infrastructure packages
    if (_isInfrastructurePackage(normalizedPath)) {
      return ArchitectureLayer.infrastructure;
    }

    return null;
  }

  bool _isInfrastructurePackage(String path) {
    final infraPackages = [
      'package:http/',
      'package:dio/',
      'package:sqflite/',
      'package:hive/',
      'package:shared_preferences/',
      'package:cloud_firestore/',
      'package:firebase_',
      'package:drift/',
      'package:isar/',
      'package:objectbox/',
      'package:realm/',
    ];

    return infraPackages.any((pkg) => path.startsWith(pkg));
  }

  bool _isAllowedInfrastructureImport(String path) {
    // Data layer can use certain infrastructure for implementation
    final allowedForData = [
      'package:http/',
      'package:dio/',
      'package:sqflite/',
      'package:hive/',
      'package:shared_preferences/',
      'package:drift/',
      'package:firebase_', // Firebase packages
      'package:cloud_', // Cloud services
      'package:supabase_', // Supabase
      'package:isar/', // Database packages
      'dart:convert',
      'dart:async',
    ];

    return allowedForData.any((allowed) => path.startsWith(allowed));
  }

  bool _isAllowedPresentationInfrastructure(String path) {
    // Presentation can use certain UI-related infrastructure
    final allowedForPresentation = [
      'package:flutter/',
      'package:provider/',
      'package:riverpod/',
      'package:bloc/',
      'package:get/',
      'package:mobx/',
      'dart:async',
    ];

    return allowedForPresentation.any((allowed) => path.startsWith(allowed));
  }

  bool _isDependencyInjectionFile(String filePath) {
    // Normalize path separators
    final normalizedPath = filePath.replaceAll('\\', '/').toLowerCase();

    // Check for common DI/provider file patterns
    final diPatterns = [
      '/providers.dart',
      '/provider.dart',
      '/providers/',
      '/di.dart',
      '/di/',
      '/injection.dart',
      '/injection_container.dart',
      '/dependency_injection.dart',
      '/get_it.dart',
      '/locator.dart',
      '/service_locator.dart',
      'main.dart', // main.dart often contains DI setup
    ];

    return diPatterns.any(
      (pattern) =>
          normalizedPath.endsWith(pattern) || normalizedPath.contains(pattern),
    );
  }

  bool _isCrossCuttingConcern(String importUri) {
    // Cross-cutting concerns that can be used across all layers
    final crossCuttingPatterns = [
      // Utility packages
      '/core/utils/',
      '/shared/utils/',
      '/common/utils/',
      '/utils/',
      // Logging
      'package:logger/',
      'package:logging/',
      // Configuration
      '/core/config/',
      '/shared/config/',
      // Constants
      '/core/constants/',
      '/shared/constants/',
      // Dart core libraries
      'dart:',
    ];

    return crossCuttingPatterns.any((pattern) => importUri.contains(pattern));
  }
}

enum ArchitectureLayer {
  domain,
  application, // Use cases - part of domain but separated for clarity
  data,
  presentation,
  infrastructure,
}

class LayerViolation {
  final String message;
  final String suggestion;

  const LayerViolation({required this.message, required this.suggestion});
}
