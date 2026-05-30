import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../../clean_architecture_linter_base.dart';

/// Detects circular dependencies between files and architectural layers.
///
/// This preserves the v1 graph-based behavior while keeping graph state scoped
/// to the rule instance registered by the analysis server.
class CircularDependencyRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'circular_dependency',
    'Circular dependency detected: {0}',
    correctionMessage:
        'Refactor to remove circular dependency using dependency injection, interfaces, or shared modules.',
    severity: DiagnosticSeverity.ERROR,
    uniqueName: 'LintCode.circular_dependency',
  );

  CircularDependencyRule()
    : super(
        name: 'circular_dependency',
        description: 'Detects circular dependencies between files and layers.',
      );

  final Map<String, Set<String>> _dependencyGraph = {};
  final Map<String, String> _fileToLayer = {};

  @override
  bool get canUseParsedResult => true;

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addCompilationUnit(
      this,
      _CircularDependencyVisitor(this, context),
    );
  }
}

class _CircularDependencyVisitor extends SimpleAstVisitor<void> {
  _CircularDependencyVisitor(this.rule, this.context);

  final CircularDependencyRule rule;
  final RuleContext context;

  @override
  void visitCompilationUnit(CompilationUnit node) {
    final currentFile =
        (context.currentUnit?.file.path ?? context.definingUnit.file.path)
            .replaceAll('\\', '/');
    if (CleanArchitectureUtils.shouldExcludeFile(currentFile)) return;

    _buildDependencyGraph(node, currentFile);
    _checkForCircularDependencies(currentFile, node);
  }

  void _buildDependencyGraph(CompilationUnit node, String currentFile) {
    rule._dependencyGraph[currentFile] = {};

    final layer = _identifyLayer(currentFile);
    if (layer != null) {
      rule._fileToLayer[currentFile] = layer;
    }

    for (final directive in node.directives) {
      if (directive is! ImportDirective) continue;

      final importUri = directive.uri.stringValue;
      if (importUri == null) continue;

      final resolvedPath = _resolveImportPath(importUri, currentFile);
      if (resolvedPath != null) {
        rule._dependencyGraph[currentFile]!.add(resolvedPath);

        final importedLayer = _identifyLayer(resolvedPath);
        if (importedLayer != null) {
          rule._fileToLayer[resolvedPath] = importedLayer;
        }
      }
    }
  }

  void _checkForCircularDependencies(String currentFile, CompilationUnit node) {
    final visited = <String>{};
    final recursionStack = <String>[];

    final cycle = _findCycle(
      currentFile,
      visited,
      recursionStack,
      rule._dependencyGraph,
    );

    if (cycle != null) {
      for (final directive in node.directives) {
        if (directive is! ImportDirective) continue;

        final importUri = directive.uri.stringValue;
        if (importUri == null) continue;

        final resolvedPath = _resolveImportPath(importUri, currentFile);
        if (resolvedPath != null && cycle.contains(resolvedPath)) {
          rule.reportAtNode(directive, arguments: [_describeCycle(cycle)]);
        }
      }
      return;
    }

    _checkLayerCircularDependency(currentFile, node);
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
        final cycleStartIndex = recursionStack.indexOf(dependency);
        return recursionStack.sublist(cycleStartIndex).toList()
          ..add(dependency);
      }
    }

    recursionStack.removeLast();
    return null;
  }

  void _checkLayerCircularDependency(String currentFile, CompilationUnit node) {
    final currentLayer = rule._fileToLayer[currentFile];
    if (currentLayer == null) return;

    final layerGraph = <String, Set<String>>{};
    for (final entry in rule._dependencyGraph.entries) {
      final sourceLayer = rule._fileToLayer[entry.key];
      if (sourceLayer == null) continue;

      layerGraph[sourceLayer] ??= {};
      for (final dependency in entry.value) {
        final targetLayer = rule._fileToLayer[dependency];
        if (targetLayer != null && targetLayer != sourceLayer) {
          layerGraph[sourceLayer]!.add(targetLayer);
        }
      }
    }

    final layerVisited = <String>{};
    final layerStack = <String>[];
    final layerCycle = _findCycle(
      currentLayer,
      layerVisited,
      layerStack,
      layerGraph,
    );

    if (layerCycle != null && layerCycle.length > 2) {
      for (final directive in node.directives) {
        if (directive is! ImportDirective) continue;

        final importUri = directive.uri.stringValue;
        if (importUri == null) continue;

        final resolvedPath = _resolveImportPath(importUri, currentFile);
        if (resolvedPath != null) {
          final targetLayer = rule._fileToLayer[resolvedPath];
          if (targetLayer != null && layerCycle.contains(targetLayer)) {
            rule.reportAtNode(
              directive,
              arguments: ['Layer-level cycle: ${layerCycle.join(' -> ')}'],
            );
            break;
          }
        }
      }
    }
  }

  String? _resolveImportPath(String importUri, String currentFile) {
    if (importUri.startsWith('dart:')) {
      return null;
    }

    if (importUri.startsWith('../') ||
        importUri.startsWith('./') ||
        !importUri.contains(':')) {
      final separatorIndex = currentFile.lastIndexOf('/');
      if (separatorIndex == -1) return null;

      final currentDir = currentFile.substring(0, separatorIndex);
      return _normalizeRelativePath(currentDir, importUri);
    }

    if (importUri.startsWith('package:')) {
      final packagePath = importUri.substring('package:'.length);
      final parts = packagePath.split('/');
      if (parts.length > 1) {
        final libIndex = currentFile.indexOf('/lib/');
        if (libIndex != -1) {
          final projectRoot = currentFile.substring(0, libIndex);
          return '$projectRoot/lib/${parts.sublist(1).join('/')}';
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

    final path = normalized.join('/');
    return basePath.startsWith('/') ? '/$path' : path;
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

  String _describeCycle(List<String> cycle) {
    final simplifiedCycle = cycle.map((path) {
      final parts = path.split('/');
      return parts.length > 2
          ? '${parts[parts.length - 2]}/${parts[parts.length - 1]}'
          : path;
    }).toList();

    return simplifiedCycle.join(' -> ');
  }
}
