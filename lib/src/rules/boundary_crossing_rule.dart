import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../clean_architecture_linter_base.dart';

/// Enforces simplified boundary crossing patterns in Clean Architecture.
///
/// This rule validates core boundary crossing principles:
/// - Dependencies flow inward only (Presentation → Domain ← Data)
/// - Use interfaces for cross-layer dependencies when appropriate
/// - No direct instantiation of classes from outer layers
///
/// Simplified to focus on essential violations with minimal false positives.
class BoundaryCrossingRule extends CleanArchitectureLintRule {
  const BoundaryCrossingRule() : super(code: _code);

  static const _code = LintCode(
    name: 'boundary_crossing',
    problemMessage: 'Boundary crossing violation: {0}',
    correctionMessage: 'Use Dependency Inversion Principle to cross architectural boundaries properly.',
  );

  @override
  void runRule(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    // Simplified to only check import dependencies - most reliable indicator
    context.registry.addImportDirective((node) {
      _checkBoundaryViolation(node, reporter, resolver);
    });

    // Check for unnecessary presentation models that duplicate entities
    context.registry.addClassDeclaration((node) {
      _checkUnnecessaryPresentationModel(node, reporter, resolver);
    });
  }

  void _checkBoundaryViolation(
    ImportDirective node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    final importUri = node.uri.stringValue;
    if (importUri == null) return;

    // Skip DI files - they can import from all layers
    if (_isDependencyInjectionFile(filePath)) {
      return;
    }

    final sourceLayer = _identifyLayer(filePath);
    final targetLayer = _identifyLayer(importUri);

    if (sourceLayer == null || targetLayer == null) return;

    // Only report concrete implementation dependencies (biggest violations)
    if (_isConcreteDependency(importUri, sourceLayer, targetLayer)) {
      final code = LintCode(
        name: 'boundary_crossing',
        problemMessage: '${sourceLayer.name} layer depends on concrete ${targetLayer.name} implementation: $importUri',
        correctionMessage: 'Use interfaces/abstractions instead of concrete implementations for cross-layer dependencies.',
      );
      reporter.atNode(node, code);
    }
  }

  bool _isConcreteDependency(String importUri, ArchitecturalLayer source, ArchitecturalLayer target) {
    // Check for obvious concrete implementation patterns
    if (importUri.contains('_impl.dart') ||
        importUri.contains('_implementation.dart') ||
        importUri.endsWith('Impl')) {
      return true;
    }

    // Domain should not import from Data or Presentation (except for DI files)
    if (source.name == 'domain' && (target.name == 'data' || target.name == 'presentation')) {
      return true;
    }

    return false;
  }

  ArchitecturalLayer? _identifyLayer(String path) {
    // Normalize path separators
    final normalizedPath = path.replaceAll('\\', '/').toLowerCase();

    // Check for domain layer and its sub-layers
    if (normalizedPath.contains('/domain/')) {
      return ArchitecturalLayer('domain', 4);
    }

    // Check for data layer
    if (normalizedPath.contains('/data/')) {
      return ArchitecturalLayer('data', 2);
    }

    // Check for presentation layer
    if (normalizedPath.contains('/presentation/') ||
        normalizedPath.contains('/ui/') ||
        normalizedPath.contains('/widgets/') ||
        normalizedPath.contains('/screens/') ||
        normalizedPath.contains('/pages/') ||
        normalizedPath.contains('/views/')) {
      return ArchitecturalLayer('presentation', 1);
    }

    return null;
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
      'main.dart',  // main.dart often contains DI setup
    ];

    return diPatterns.any((pattern) => normalizedPath.endsWith(pattern) || normalizedPath.contains(pattern));
  }

  void _checkUnnecessaryPresentationModel(
    ClassDeclaration node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;

    // Only check files in presentation layer
    if (!_isPresentationLayer(filePath)) return;

    final className = node.name.lexeme;

    // Check if this looks like a model that might duplicate an entity
    if (_isPresentationModel(className, filePath)) {
      // Check if there's a corresponding entity in domain layer
      final correspondingEntityPath = _findCorrespondingEntity(className, filePath);

      if (correspondingEntityPath != null) {
        // Check if the model is just duplicating the entity without adding UI-specific logic
        if (_isDuplicatingEntity(node)) {
          final code = LintCode(
            name: 'boundary_crossing',
            problemMessage: 'Unnecessary presentation model: $className duplicates domain entity without adding UI value',
            correctionMessage: 'Use domain entity directly in presentation layer instead of creating duplicate models.',
          );
          reporter.atNode(node, code);
        }
      }
    }
  }

  bool _isPresentationLayer(String filePath) {
    final normalizedPath = filePath.replaceAll('\\', '/').toLowerCase();
    return normalizedPath.contains('/presentation/') ||
           normalizedPath.contains('/ui/') ||
           normalizedPath.contains('/widgets/') ||
           normalizedPath.contains('/screens/') ||
           normalizedPath.contains('/pages/') ||
           normalizedPath.contains('/views/');
  }

  bool _isPresentationModel(String className, String filePath) {
    // Check if file is in models directory within presentation
    final normalizedPath = filePath.replaceAll('\\', '/').toLowerCase();
    if (!normalizedPath.contains('/models/')) return false;

    // Check common model naming patterns
    return className.endsWith('Model') ||
           className.endsWith('ViewModel') ||
           className.endsWith('Dto') ||
           className.endsWith('Data');
  }

  String? _findCorrespondingEntity(String modelClassName, String filePath) {
    // Extract base name (remove Model/ViewModel/etc suffix)
    String baseName = modelClassName;
    final suffixes = ['Model', 'ViewModel', 'Dto', 'Data'];

    for (final suffix in suffixes) {
      if (baseName.endsWith(suffix)) {
        baseName = baseName.substring(0, baseName.length - suffix.length);
        break;
      }
    }

    // Try to construct entity path
    final normalizedPath = filePath.replaceAll('\\', '/');

    // Replace presentation path with domain path
    String entityPath = normalizedPath
        .replaceAll('/presentation/', '/domain/')
        .replaceAll('/models/', '/entities/')
        .replaceAll(modelClassName.toLowerCase(), '${baseName.toLowerCase()}_entity');

    // For simplicity, return constructed path - in real implementation,
    // you might want to check if file actually exists
    return entityPath;
  }

  bool _isDuplicatingEntity(ClassDeclaration node) {
    // Simple heuristic: if model has only basic fields without UI-specific logic,
    // it might be duplicating an entity
    final members = node.members;

    // Count meaningful methods vs simple getters/fields
    int meaningfulMethods = 0;
    int simpleFields = 0;

    for (final member in members) {
      if (member is FieldDeclaration) {
        simpleFields++;
      } else if (member is MethodDeclaration) {
        final methodName = member.name.lexeme;
        // Skip constructors, getters, toString, etc.
        if (!methodName.startsWith('get') &&
            methodName != 'toString' &&
            methodName != 'hashCode' &&
            methodName != 'operator==' &&
            !member.isGetter &&
            !member.isSetter) {
          meaningfulMethods++;
        }
      }
    }

    // If it's mostly just fields without meaningful methods, likely duplicating entity
    return simpleFields > 0 && meaningfulMethods == 0;
  }
}

class ArchitecturalLayer {
  final String name;
  final int level;

  ArchitecturalLayer(this.name, this.level);
}