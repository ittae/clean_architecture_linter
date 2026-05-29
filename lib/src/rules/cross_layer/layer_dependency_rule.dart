import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

/// Enforces proper dependency direction between architectural layers.
///
/// The path filters and DI exceptions intentionally mirror the v1 custom-lint
/// rule so the v2 warning rule does not become noisier during migration.
class LayerDependencyRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'layer_dependency',
    'Improper dependency between architectural layers detected.',
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
    registry.addImportDirective(this, _LayerDependencyVisitor(this, context));
  }
}

class _LayerDependencyVisitor extends SimpleAstVisitor<void> {
  _LayerDependencyVisitor(this.rule, this.context);

  final AnalysisRule rule;
  final RuleContext context;

  @override
  void visitImportDirective(ImportDirective node) {
    final filePath = _currentPath();
    final importUri = node.uri.stringValue;
    if (importUri == null) return;

    if (_isDependencyInjectionFile(filePath)) {
      if (_isDataModelImport(importUri)) {
        rule.reportAtNode(node);
      }
      return;
    }

    final sourceLayer = _identifyLayer(filePath);
    final targetLayer = _identifyLayer(importUri);

    if (sourceLayer == null || targetLayer == null) return;

    final hasViolation = _hasDependencyViolation(
      sourceLayer,
      targetLayer,
      importUri,
    );

    if (hasViolation) {
      rule.reportAtNode(node);
    }
  }

  String _currentPath() {
    return context.currentUnit?.file.path ?? context.definingUnit.file.path;
  }

  bool _isDataModelImport(String importUri) {
    final normalizedPath = importUri.replaceAll('\\', '/').toLowerCase();
    return normalizedPath.contains('/data/models/') ||
        normalizedPath.contains('/models/') &&
            normalizedPath.contains('/data/');
  }

  bool _hasDependencyViolation(
    ArchitectureLayer source,
    ArchitectureLayer target,
    String importPath,
  ) {
    if (_isCrossCuttingConcern(importPath)) {
      return false;
    }

    switch (source) {
      case ArchitectureLayer.domain:
        if (target == ArchitectureLayer.data) {
          return true;
        }
        if (target == ArchitectureLayer.presentation) {
          return true;
        }
        if (target == ArchitectureLayer.infrastructure) {
          return true;
        }
        break;

      case ArchitectureLayer.data:
        if (target == ArchitectureLayer.presentation) {
          return true;
        }
        if (target == ArchitectureLayer.infrastructure &&
            !_isAllowedInfrastructureImport(importPath)) {
          return true;
        }
        break;

      case ArchitectureLayer.presentation:
        if (target == ArchitectureLayer.data) {
          return true;
        }
        if (target == ArchitectureLayer.infrastructure &&
            !_isAllowedPresentationInfrastructure(importPath)) {
          return true;
        }
        break;

      case ArchitectureLayer.infrastructure:
        if (target == ArchitectureLayer.presentation) {
          return true;
        }
        break;

      case ArchitectureLayer.application:
        if (target == ArchitectureLayer.data ||
            target == ArchitectureLayer.presentation ||
            target == ArchitectureLayer.infrastructure) {
          return true;
        }
        break;
    }

    return false;
  }

  ArchitectureLayer? _identifyLayer(String path) {
    final normalizedPath = path.replaceAll('\\', '/').toLowerCase();

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
    final normalizedPath = filePath.replaceAll('\\', '/').toLowerCase();

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
      'main.dart',
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
