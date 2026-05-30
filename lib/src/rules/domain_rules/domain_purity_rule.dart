import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../../clean_architecture_linter_base.dart';

/// Enforces domain layer purity by preventing dependencies on external
/// frameworks and infrastructure concerns.
class DomainPurityRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'domain_purity',
    'Domain layer violation: {0}',
    correctionMessage:
        'Remove dependencies on UI frameworks, HTTP clients, databases, or platform-specific APIs. Use abstractions instead.',
    severity: DiagnosticSeverity.WARNING,
    uniqueName: 'LintCode.domain_purity',
  );

  DomainPurityRule()
    : super(
        name: 'domain_purity',
        description:
            'Prevents domain layer dependencies on frameworks and infrastructure.',
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
    final visitor = _DomainPurityVisitor(this, context);
    registry.addImportDirective(this, visitor);
    registry.addClassDeclaration(this, visitor);
  }
}

class _DomainPurityVisitor extends SimpleAstVisitor<void> {
  _DomainPurityVisitor(this.rule, this.context);

  final AnalysisRule rule;
  final RuleContext context;

  String get _filePath =>
      context.currentUnit?.file.path ?? context.definingUnit.file.path;

  @override
  void visitImportDirective(ImportDirective node) {
    final filePath = _filePath;
    if (CleanArchitectureUtils.shouldExcludeFile(filePath)) return;
    if (!CleanArchitectureUtils.isDomainFile(filePath)) return;

    final importUri = node.uri.stringValue;
    if (importUri == null) return;

    final violation = _checkForViolation(importUri);
    if (violation != null) {
      rule.reportAtNode(node, arguments: [violation.category]);
    }
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final filePath = _filePath;
    if (CleanArchitectureUtils.shouldExcludeFile(filePath)) return;
    if (!CleanArchitectureUtils.isDomainFile(filePath)) return;

    final extendsClause = node.extendsClause;
    if (extendsClause != null) {
      final superTypeName = extendsClause.superclass.name.lexeme;
      if (_isExternalFrameworkClass(superTypeName)) {
        rule.reportAtNode(
          extendsClause,
          arguments: [
            'Domain entities should not extend external framework classes ($superTypeName)',
          ],
        );
      }
    }

    final implementsClause = node.implementsClause;
    if (implementsClause != null) {
      for (final interface in implementsClause.interfaces) {
        final interfaceName = interface.name.lexeme;
        if (_isExternalFrameworkClass(interfaceName)) {
          rule.reportAtNode(
            interface,
            arguments: [
              'Domain classes should not implement external framework interfaces ($interfaceName)',
            ],
          );
        }
      }
    }
  }

  DomainViolation? _checkForViolation(String importUri) {
    const uiFrameworks = [
      'package:flutter/',
      'package:ffi/',
      'dart:ui',
      'dart:html',
      'dart:js',
    ];
    for (final framework in uiFrameworks) {
      if (importUri.startsWith(framework)) {
        return const DomainViolation(
          category: 'UI Framework dependency detected',
        );
      }
    }

    const networkingLibs = [
      'package:http/',
      'package:dio/',
      'package:connectivity_plus/',
    ];
    for (final lib in networkingLibs) {
      if (importUri.startsWith(lib)) {
        return const DomainViolation(
          category: 'Networking dependency detected',
        );
      }
    }

    const storageLibs = [
      'package:sqflite/',
      'package:hive/',
      'package:shared_preferences/',
      'package:path_provider/',
      'package:cloud_firestore/',
      'package:firebase_database/',
    ];
    for (final lib in storageLibs) {
      if (importUri.startsWith(lib)) {
        return const DomainViolation(category: 'Storage dependency detected');
      }
    }

    const platformLibs = [
      'package:device_info_plus/',
      'package:permission_handler/',
      'package:camera/',
      'package:location/',
      'package:geolocator/',
    ];
    for (final lib in platformLibs) {
      if (importUri.startsWith(lib)) {
        return const DomainViolation(
          category: 'Platform-specific dependency detected',
        );
      }
    }

    const stateManagementLibs = [
      'package:provider/',
      'package:riverpod/',
      'package:bloc/',
      'package:get/',
      'package:mobx/',
    ];
    for (final lib in stateManagementLibs) {
      if (importUri.startsWith(lib)) {
        return const DomainViolation(
          category: 'State management dependency detected',
        );
      }
    }

    return null;
  }

  bool _isExternalFrameworkClass(String className) {
    const externalClasses = [
      'Widget',
      'StatelessWidget',
      'StatefulWidget',
      'ChangeNotifier',
      'ValueNotifier',
      'Stream',
      'Future',
      'HttpClient',
      'Response',
      'Request',
    ];
    return externalClasses.contains(className);
  }
}

class DomainViolation {
  const DomainViolation({required this.category});

  final String category;
}
