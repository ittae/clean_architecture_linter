import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../clean_architecture_linter_base.dart';

/// Enforces domain layer purity by preventing dependencies on external frameworks.
///
/// This rule ensures that the domain layer remains independent of:
/// - UI frameworks (Flutter)
/// - HTTP clients and networking libraries
/// - Database and storage libraries
/// - Platform-specific APIs
///
/// The domain layer should only depend on:
/// - Dart core libraries (with restrictions)
/// - Other domain layer code
/// - Pure business logic abstractions
class DomainPurityRule extends CleanArchitectureLintRule {
  const DomainPurityRule() : super(code: _code);

  static const _code = LintCode(
    name: 'domain_purity',
    problemMessage:
        'Domain layer must remain pure and not depend on external frameworks or infrastructure concerns.',
    correctionMessage:
        'Remove dependencies on UI frameworks, HTTP clients, databases, or platform-specific APIs. Use abstractions instead.',
  );

  @override
  void runRule(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    // Check import statements for external dependencies
    context.registry.addImportDirective((node) {
      _checkImportPurity(node, reporter, resolver);
    });

    // Check class declarations for inheritance/implementation violations
    context.registry.addClassDeclaration((node) {
      _checkClassDeclarations(node, reporter, resolver);
    });
  }

  void _checkImportPurity(
    ImportDirective node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;

    // Only check files in domain layer
    if (!CleanArchitectureUtils.isDomainFile(filePath)) return;

    final importUri = node.uri.stringValue;
    if (importUri == null) return;

    final violation = _checkForViolation(importUri);
    if (violation != null) {
      final enhancedCode = LintCode(
        name: 'domain_purity',
        problemMessage: 'Domain layer violation: ${violation.category}',
        correctionMessage: violation.suggestion,
      );
      reporter.atNode(node, enhancedCode);
    }
  }

  /// Checks for domain purity violations and returns detailed information
  DomainViolation? _checkForViolation(String importUri) {
    // UI Framework violations
    final uiFrameworks = [
      'package:flutter/',
      'package:ffi/',
      'dart:ui',
      'dart:html',
      'dart:js',
    ];
    for (final framework in uiFrameworks) {
      if (importUri.startsWith(framework)) {
        return DomainViolation(
          category: 'UI Framework dependency detected',
          suggestion:
              'Domain layer should not depend on UI frameworks. Use abstractions or move this logic to presentation layer.',
        );
      }
    }

    // Networking violations
    final networkingLibs = [
      'package:http/',
      'package:dio/',
      'package:connectivity_plus/',
      'dart:io',
    ];
    for (final lib in networkingLibs) {
      if (importUri.startsWith(lib)) {
        return DomainViolation(
          category: 'Networking dependency detected',
          suggestion:
              'Use repository abstractions instead of direct HTTP clients in domain layer.',
        );
      }
    }

    // Storage violations
    final storageLibs = [
      'package:sqflite/',
      'package:hive/',
      'package:shared_preferences/',
      'package:path_provider/',
      'package:cloud_firestore/',
      'package:firebase_database/',
    ];
    for (final lib in storageLibs) {
      if (importUri.startsWith(lib)) {
        return DomainViolation(
          category: 'Storage dependency detected',
          suggestion:
              'Use repository abstractions instead of direct storage dependencies in domain layer.',
        );
      }
    }

    // Platform-specific violations
    final platformLibs = [
      'package:device_info_plus/',
      'package:permission_handler/',
      'package:camera/',
      'package:location/',
      'package:geolocator/',
    ];
    for (final lib in platformLibs) {
      if (importUri.startsWith(lib)) {
        return DomainViolation(
          category: 'Platform-specific dependency detected',
          suggestion:
              'Use service abstractions instead of direct platform dependencies in domain layer.',
        );
      }
    }

    // State management violations (should be in presentation layer)
    final stateManagementLibs = [
      'package:provider/',
      'package:riverpod/',
      'package:bloc/',
      'package:get/',
      'package:mobx/',
    ];
    for (final lib in stateManagementLibs) {
      if (importUri.startsWith(lib)) {
        return DomainViolation(
          category: 'State management dependency detected',
          suggestion:
              'State management should be handled in presentation layer, not domain layer.',
        );
      }
    }

    return null;
  }

  /// Additional checks for code constructs within domain layer files
  void _checkClassDeclarations(
    ClassDeclaration node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    if (!CleanArchitectureUtils.isDomainFile(filePath)) return;

    // Check for inheritance from external framework classes
    final extendsClause = node.extendsClause;
    if (extendsClause != null) {
      final superTypeName = extendsClause.superclass.name2.lexeme;
      if (_isExternalFrameworkClass(superTypeName)) {
        final code = LintCode(
          name: 'domain_purity',
          problemMessage:
              'Domain entities should not extend external framework classes ($superTypeName)',
          correctionMessage:
              'Use composition instead of inheritance from external frameworks.',
        );
        reporter.atNode(extendsClause, code);
      }
    }

    // Check for implementation of external interfaces
    final implementsClause = node.implementsClause;
    if (implementsClause != null) {
      for (final interface in implementsClause.interfaces) {
        final interfaceName = interface.name2.lexeme;
        if (_isExternalFrameworkClass(interfaceName)) {
          final code = LintCode(
            name: 'domain_purity',
            problemMessage:
                'Domain classes should not implement external framework interfaces ($interfaceName)',
            correctionMessage:
                'Create domain-specific abstractions instead of implementing external interfaces.',
          );
          reporter.atNode(interface, code);
        }
      }
    }
  }

  bool _isExternalFrameworkClass(String className) {
    final externalClasses = [
      'Widget', 'StatelessWidget', 'StatefulWidget',
      'ChangeNotifier', 'ValueNotifier',
      'Stream', 'Future', // These might be acceptable in some cases
      'HttpClient', 'Response', 'Request',
    ];
    return externalClasses.contains(className);
  }
}

/// Represents a domain layer purity violation with detailed information
class DomainViolation {
  final String category;
  final String suggestion;

  const DomainViolation({required this.category, required this.suggestion});
}
