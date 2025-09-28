import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../clean_architecture_linter_base.dart';

/// Detects circular dependencies between files and architectural layers.
///
/// This rule prevents:
/// - Direct circular imports (A imports B, B imports A)
/// - Indirect circular imports (A → B → C → A)
/// - Layer-level circular dependencies
///
/// Circular dependencies violate Clean Architecture principles by:
/// - Creating tight coupling between components
/// - Making testing difficult
/// - Preventing clear separation of concerns
/// - Making the codebase harder to understand and maintain
class CircularDependencyRule extends CleanArchitectureLintRule {
  const CircularDependencyRule() : super(code: _code);

  static const _code = LintCode(
    name: 'circular_dependency',
    problemMessage: 'Circular dependency detected between files or layers.',
    correctionMessage:
        'Refactor to remove circular dependency. Consider using dependency injection, interfaces, or reorganizing code structure.',
  );

  // Static cache to store dependency graph across file analysis
  static final Map<String, Set<String>> _dependencyGraph = {};
  static final Map<String, String> _fileToLayer = {};

  @override
  void runRule(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    final currentFile = resolver.path;

    // Build dependency graph for current file
    context.registry.addCompilationUnit((node) {
      _buildDependencyGraph(node, currentFile, resolver);
      _checkForCircularDependencies(currentFile, reporter, node);
    });
  }

  void _buildDependencyGraph(
    CompilationUnit node,
    String currentFile,
    CustomLintResolver resolver,
  ) {
    // Initialize entry for current file
    _dependencyGraph[currentFile] ??= {};

    // Store layer information
    final layer = _identifyLayer(currentFile);
    if (layer != null) {
      _fileToLayer[currentFile] = layer;
    }

    // Process all imports
    for (final directive in node.directives) {
      if (directive is ImportDirective) {
        final importUri = directive.uri.stringValue;
        if (importUri == null) continue;

        // Resolve relative imports to absolute paths
        final resolvedPath = _resolveImportPath(importUri, currentFile);
        if (resolvedPath != null && !_isExternalPackage(resolvedPath)) {
          _dependencyGraph[currentFile]!.add(resolvedPath);

          // Store layer for imported file
          final importedLayer = _identifyLayer(resolvedPath);
          if (importedLayer != null) {
            _fileToLayer[resolvedPath] = importedLayer;
          }
        }
      }
    }
  }

  void _checkForCircularDependencies(
    String currentFile,
    ErrorReporter reporter,
    CompilationUnit node,
  ) {
    final visited = <String>{};
    final recursionStack = <String>[];

    // Check for circular dependencies starting from current file
    final cycle = _findCycle(
      currentFile,
      visited,
      recursionStack,
      _dependencyGraph,
    );

    if (cycle != null) {
      // Report circular dependency on import statements
      for (final directive in node.directives) {
        if (directive is ImportDirective) {
          final importUri = directive.uri.stringValue;
          if (importUri == null) continue;

          final resolvedPath = _resolveImportPath(importUri, currentFile);
          if (resolvedPath != null && cycle.contains(resolvedPath)) {
            final cycleDescription = _describeCycle(cycle, currentFile);
            final enhancedCode = LintCode(
              name: 'circular_dependency',
              problemMessage: 'Circular dependency detected: $cycleDescription',
              correctionMessage: _getSuggestion(cycle),
            );
            reporter.atNode(directive, enhancedCode);
          }
        }
      }
    }

    // Check for layer-level circular dependencies
    _checkLayerCircularDependency(currentFile, reporter, node);
  }

  List<String>? _findCycle(
    String node,
    Set<String> visited,
    List<String> recursionStack,
    Map<String, Set<String>> graph,
  ) {
    visited.add(node);
    recursionStack.add(node);

    final dependencies = graph[node] ?? {};
    for (final dependency in dependencies) {
      if (!visited.contains(dependency)) {
        final cycle = _findCycle(dependency, visited, recursionStack, graph);
        if (cycle != null) return cycle;
      } else if (recursionStack.contains(dependency)) {
        // Found a cycle
        final cycleStartIndex = recursionStack.indexOf(dependency);
        return recursionStack.sublist(cycleStartIndex).toList()..add(dependency);
      }
    }

    recursionStack.removeLast();
    return null;
  }

  void _checkLayerCircularDependency(
    String currentFile,
    ErrorReporter reporter,
    CompilationUnit node,
  ) {
    final currentLayer = _fileToLayer[currentFile];
    if (currentLayer == null) return;

    // Build layer-level dependency graph
    final layerGraph = <String, Set<String>>{};
    for (final entry in _dependencyGraph.entries) {
      final sourceLayer = _fileToLayer[entry.key];
      if (sourceLayer == null) continue;

      layerGraph[sourceLayer] ??= {};
      for (final dependency in entry.value) {
        final targetLayer = _fileToLayer[dependency];
        if (targetLayer != null && targetLayer != sourceLayer) {
          layerGraph[sourceLayer]!.add(targetLayer);
        }
      }
    }

    // Check for layer cycles
    final layerVisited = <String>{};
    final layerStack = <String>[];
    final layerCycle = _findCycle(
      currentLayer,
      layerVisited,
      layerStack,
      layerGraph,
    );

    if (layerCycle != null && layerCycle.length > 2) {
      // Only report if it's a non-trivial cycle (more than self-reference)
      for (final directive in node.directives) {
        if (directive is ImportDirective) {
          final importUri = directive.uri.stringValue;
          if (importUri == null) continue;

          final resolvedPath = _resolveImportPath(importUri, currentFile);
          if (resolvedPath != null) {
            final targetLayer = _fileToLayer[resolvedPath];
            if (targetLayer != null && layerCycle.contains(targetLayer)) {
              final enhancedCode = LintCode(
                name: 'circular_dependency',
                problemMessage:
                    'Layer-level circular dependency: ${layerCycle.join(' → ')}',
                correctionMessage:
                    'Architectural layers should have acyclic dependencies. Consider using dependency inversion.',
              );
              reporter.atNode(directive, enhancedCode);
              break; // Report once per file
            }
          }
        }
      }
    }
  }

  String _describeCycle(List<String> cycle, String currentFile) {
    final simplifiedCycle = cycle.map((path) {
      final parts = path.split('/');
      return parts.length > 2 ? '${parts[parts.length - 2]}/${parts[parts.length - 1]}' : path;
    }).toList();

    return simplifiedCycle.join(' → ');
  }

  String _getSuggestion(List<String> cycle) {
    final layers = cycle.map((f) => _fileToLayer[f]).whereType<String>().toSet();

    if (layers.length > 1) {
      return 'Break the cycle by using dependency inversion. Create abstractions in the inner layer that outer layers can implement.';
    }

    if (cycle.any((f) => f.contains('repository'))) {
      return 'Consider using repository interfaces in the domain layer instead of direct dependencies.';
    }

    if (cycle.any((f) => f.contains('usecase') || f.contains('use_case'))) {
      return 'Use cases should not depend on each other directly. Consider combining or restructuring them.';
    }

    return 'Extract shared functionality to a separate module or use dependency injection to break the cycle.';
  }

  String? _resolveImportPath(String importUri, String currentFile) {
    // Handle relative imports
    if (importUri.startsWith('../') || importUri.startsWith('./')) {
      final currentDir = currentFile.substring(0, currentFile.lastIndexOf('/'));
      return _normalizeRelativePath(currentDir, importUri);
    }

    // Handle package imports within the same project
    if (importUri.startsWith('package:')) {
      // Extract package name and path
      final packagePath = importUri.substring('package:'.length);
      final parts = packagePath.split('/');
      if (parts.isNotEmpty) {
        // Check if it's the same package (not external)
        if (currentFile.contains('/${parts[0]}/')) {
          // Convert to project-relative path
          final libIndex = currentFile.indexOf('/lib/');
          if (libIndex != -1) {
            final projectRoot = currentFile.substring(0, libIndex);
            return '$projectRoot/lib/${parts.sublist(1).join('/')}';
          }
        }
      }
    }

    return null;
  }

  String _normalizeRelativePath(String basePath, String relativePath) {
    final segments = basePath.split('/')..addAll(relativePath.split('/'));
    final normalized = <String>[];

    for (final segment in segments) {
      if (segment == '..') {
        if (normalized.isNotEmpty) {
          normalized.removeLast();
        }
      } else if (segment != '.' && segment.isNotEmpty) {
        normalized.add(segment);
      }
    }

    return normalized.join('/');
  }

  bool _isExternalPackage(String path) {
    // Check if it's a Dart/Flutter SDK or external package
    return path.startsWith('dart:') ||
        path.startsWith('package:flutter/') ||
        (!path.contains('/lib/') && path.startsWith('package:'));
  }

  String? _identifyLayer(String path) {
    final normalizedPath = path.replaceAll('\\', '/').toLowerCase();

    if (normalizedPath.contains('/domain/')) {
      return 'domain';
    } else if (normalizedPath.contains('/data/')) {
      return 'data';
    } else if (normalizedPath.contains('/presentation/') ||
        normalizedPath.contains('/ui/') ||
        normalizedPath.contains('/widgets/') ||
        normalizedPath.contains('/screens/') ||
        normalizedPath.contains('/pages/')) {
      return 'presentation';
    } else if (normalizedPath.contains('/infrastructure/')) {
      return 'infrastructure';
    } else if (normalizedPath.contains('/application/') ||
        normalizedPath.contains('/use_cases/') ||
        normalizedPath.contains('/usecases/')) {
      return 'application';
    }

    return null;
  }
}