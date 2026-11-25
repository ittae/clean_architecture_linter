import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../../clean_architecture_linter_base.dart';
import '../../utils/project_path.dart';

/// Enforces proper dependency direction between architectural layers.
///
/// The path filters and DI exceptions intentionally mirror the v1 custom-lint
/// rule so the v2 warning rule does not become noisier during migration.
class LayerDependencyRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'layer_dependency',
    'Layer dependency violation: {0}',
    correctionMessage:
        'Ensure dependencies flow inward: Presentation -> Domain <- Data.',
    severity: DiagnosticSeverity.WARNING,
    uniqueName: 'LintCode.layer_dependency',
  );

  LayerDependencyRule()
    : super(
        name: 'layer_dependency',
        description: 'Enforces Clean Architecture dependency direction.',
      );

  @override
  bool get canUseParsedResult => true;

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final visitor = _LayerDependencyVisitor(this, context);
    registry.addImportDirective(this, visitor);
    registry.addExportDirective(this, visitor);
  }
}

class _LayerDependencyVisitor extends SimpleAstVisitor<void> {
  _LayerDependencyVisitor(this.rule, this.context);

  final AnalysisRule rule;
  final RuleContext context;

  @override
  void visitImportDirective(ImportDirective node) {
    _checkNamespace(node, kind: 'import');
  }

  @override
  void visitExportDirective(ExportDirective node) {
    _checkNamespace(node, kind: 'export');
  }

  void _checkNamespace(NamespaceDirective node, {required String kind}) {
    final filePath = _currentPath();
    if (CleanArchitectureUtils.shouldExcludeFile(filePath)) return;

    final packageName = ProjectPaths.packageNameNear(filePath);
    for (final importUri in ProjectPaths.urisOf(node)) {
      if (_reportUri(
        node,
        filePath: filePath,
        importUri: importUri,
        packageName: packageName,
        kind: kind,
      )) {
        return;
      }
    }
  }

  bool _reportUri(
    NamespaceDirective node, {
    required String filePath,
    required String importUri,
    required String? packageName,
    required String kind,
  }) {
    final resolved = ProjectPaths.resolveProjectFile(
      uri: importUri,
      currentFile: filePath,
      packageName: packageName,
    );

    if (_isDependencyInjectionFile(filePath)) {
      if (_isDataModelImport(importUri, resolved, packageName)) {
        rule.reportAtNode(
          node,
          arguments: [
            'Data Models should not be imported even in DI/Provider files. '
                'Found $kind: $importUri',
          ],
        );
        return true;
      }
      return false;
    }

    final sourceLayer = _identifyLayer(filePath);
    if (sourceLayer == null || _isCrossCuttingConcern(importUri)) return false;

    for (final targetLayer in _targetLayers(importUri, resolved, packageName)) {
      final violation = _checkDependencyViolation(
        sourceLayer,
        targetLayer,
        importUri,
        kind,
      );
      if (violation != null) {
        rule.reportAtNode(node, arguments: [violation.message]);
        return true;
      }
    }
    return false;
  }

  List<ArchitectureLayer> _targetLayers(
    String importUri,
    String? resolved,
    String? packageName,
  ) {
    final layers = <ArchitectureLayer>[];
    void add(ArchitectureLayer? layer) {
      if (layer != null && !layers.contains(layer)) layers.add(layer);
    }

    if (resolved != null) {
      final direct = _identifyLayer(resolved);
      if (direct != null) {
        add(direct);
      } else {
        final reach = ProjectPaths.exportReach(
          dartFile: resolved,
          packageName: packageName,
        );
        for (final file in reach.files) {
          add(_identifyLayer(file));
        }
        for (final uri in reach.uris) {
          add(_identifyLayer(uri));
        }
      }
    }
    add(_identifyLayer(importUri));
    return layers;
  }

  String _currentPath() {
    return context.currentUnit?.file.path ?? context.definingUnit.file.path;
  }

  bool _isDataModelImport(
    String importUri,
    String? resolved,
    String? packageName,
  ) {
    if (_looksLikeDataModel(importUri)) return true;
    if (resolved != null &&
        _looksLikeDataModel(ProjectPaths.scopeToPackageLib(resolved))) {
      return true;
    }
    if (resolved == null) return false;
    final reach = ProjectPaths.exportReach(
      dartFile: resolved,
      packageName: packageName,
    );
    for (final file in reach.files) {
      if (_looksLikeDataModel(ProjectPaths.scopeToPackageLib(file))) {
        return true;
      }
    }
    return false;
  }

  bool _looksLikeDataModel(String path) {
    final normalizedPath = path.replaceAll('\\', '/').toLowerCase();
    return normalizedPath.contains('/data/models/') ||
        normalizedPath.contains('/models/') &&
            normalizedPath.contains('/data/');
  }

  LayerViolation? _checkDependencyViolation(
    ArchitectureLayer source,
    ArchitectureLayer target,
    String importPath,
    String kind,
  ) {
    switch (source) {
      case ArchitectureLayer.domain:
        if (target == ArchitectureLayer.data) {
          return LayerViolation(
            'Domain layer cannot depend on Data layer. Found $kind: $importPath',
          );
        }
        if (target == ArchitectureLayer.presentation) {
          return LayerViolation(
            'Domain layer cannot depend on Presentation layer. Found $kind: $importPath',
          );
        }
        if (target == ArchitectureLayer.infrastructure) {
          return LayerViolation(
            'Domain layer cannot depend on Infrastructure. Found $kind: $importPath',
          );
        }
        break;

      case ArchitectureLayer.data:
        if (target == ArchitectureLayer.presentation) {
          return LayerViolation(
            'Data layer cannot depend on Presentation layer. Found $kind: $importPath',
          );
        }
        if (target == ArchitectureLayer.infrastructure &&
            !_isAllowedInfrastructureImport(importPath)) {
          return LayerViolation(
            'Data layer has suspicious Infrastructure dependency: $importPath',
          );
        }
        break;

      case ArchitectureLayer.presentation:
        if (target == ArchitectureLayer.data) {
          return LayerViolation(
            'Presentation layer should not directly depend on Data layer. Found $kind: $importPath',
          );
        }
        if (target == ArchitectureLayer.infrastructure &&
            !_isAllowedPresentationInfrastructure(importPath)) {
          return LayerViolation(
            'Presentation layer has improper Infrastructure dependency: $importPath',
          );
        }
        break;

      case ArchitectureLayer.infrastructure:
        if (target == ArchitectureLayer.presentation) {
          return LayerViolation(
            'Infrastructure cannot depend on Presentation layer. Found $kind: $importPath',
          );
        }
        break;

      case ArchitectureLayer.application:
        if (target == ArchitectureLayer.data ||
            target == ArchitectureLayer.presentation ||
            target == ArchitectureLayer.infrastructure) {
          return LayerViolation(
            'Application layer cannot depend on outer layers. Found $kind: $importPath',
          );
        }
        break;
    }

    return null;
  }

  ArchitectureLayer? _identifyLayer(String path) {
    final normalizedPath = ProjectPaths.scopeToPackageLib(path).toLowerCase();

    if (normalizedPath.contains('/domain/')) {
      if (normalizedPath.contains('/domain/usecases/') ||
          normalizedPath.contains('/domain/use_cases/')) {
        return ArchitectureLayer.application;
      }
      return ArchitectureLayer.domain;
    }

    if (normalizedPath.contains('/data/')) {
      return ArchitectureLayer.data;
    }

    if (normalizedPath.contains('/presentation/') ||
        normalizedPath.contains('/ui/') ||
        normalizedPath.contains('/widgets/') ||
        normalizedPath.contains('/screens/') ||
        normalizedPath.contains('/pages/') ||
        normalizedPath.contains('/views/')) {
      return ArchitectureLayer.presentation;
    }

    if (normalizedPath.contains('/infrastructure/') ||
        normalizedPath.contains('/services/') ||
        normalizedPath.contains('/external/')) {
      return ArchitectureLayer.infrastructure;
    }

    if (_isInfrastructurePackage(normalizedPath)) {
      return ArchitectureLayer.infrastructure;
    }

    return null;
  }

  bool _isInfrastructurePackage(String path) {
    const infraPackages = [
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

    return infraPackages.any(path.startsWith);
  }

  bool _isAllowedInfrastructureImport(String path) {
    const allowedForData = [
      'package:http/',
      'package:dio/',
      'package:sqflite/',
      'package:hive/',
      'package:shared_preferences/',
      'package:drift/',
      'package:firebase_',
      'package:cloud_',
      'package:supabase_',
      'package:isar/',
      'package:objectbox/',
      'package:realm/',
      'dart:convert',
      'dart:async',
    ];

    return allowedForData.any(path.startsWith);
  }

  bool _isAllowedPresentationInfrastructure(String path) {
    const allowedForPresentation = [
      'package:flutter/',
      'package:provider/',
      'package:riverpod/',
      'package:bloc/',
      'package:get/',
      'package:mobx/',
      'dart:async',
    ];

    return allowedForPresentation.any(path.startsWith);
  }

  bool _isDependencyInjectionFile(String filePath) {
    final normalizedPath = ProjectPaths.scopeToPackageLib(
      filePath,
    ).toLowerCase();

    // Match the entrypoint file name exactly. A bare `main.dart` substring
    // also matches `remain.dart` and `domain_main.dart` (`endsWith` /
    // `contains`), which then skip layer checks.
    final fileName = normalizedPath.split('/').last;
    if (fileName == 'main.dart') return true;

    const diPatterns = [
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
    ];

    return diPatterns.any(
      (pattern) =>
          normalizedPath.endsWith(pattern) || normalizedPath.contains(pattern),
    );
  }

  bool _isCrossCuttingConcern(String importUri) {
    const crossCuttingPatterns = [
      '/core/utils/',
      '/shared/utils/',
      '/common/utils/',
      '/utils/',
      'package:logger/',
      'package:logging/',
      '/core/config/',
      '/shared/config/',
      '/core/constants/',
      '/shared/constants/',
      'dart:',
    ];

    return crossCuttingPatterns.any(importUri.contains);
  }
}

enum ArchitectureLayer {
  domain,
  application,
  data,
  presentation,
  infrastructure,
}

class LayerViolation {
  const LayerViolation(this.message);

  final String message;
}
