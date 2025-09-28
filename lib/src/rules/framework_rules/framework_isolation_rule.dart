import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../clean_architecture_linter_base.dart';

/// Enforces proper framework isolation in the outermost layer.
///
/// This rule ensures that frameworks and drivers remain in the outermost layer:
/// - Frameworks should not leak into inner layers
/// - Framework details should be contained to this layer
/// - Only "glue code" should exist in this layer
/// - No business logic should exist in framework layer
/// - Framework-specific concerns should not affect inner circles
///
/// Frameworks and Drivers layer should:
/// - Contain framework-specific implementations only
/// - Provide glue code to connect frameworks to adapters
/// - Keep all framework details isolated from business logic
/// - Be easily replaceable without affecting inner layers
class FrameworkIsolationRule extends CleanArchitectureLintRule {
  const FrameworkIsolationRule() : super(code: _code);

  static const _code = LintCode(
    name: 'framework_isolation',
    problemMessage: 'Framework details must be isolated to outermost layer and not leak into inner circles.',
    correctionMessage: 'Move framework-specific code to framework layer. Use abstractions in inner layers.',
  );

  @override
  void runRule(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addImportDirective((node) {
      _checkFrameworkImports(node, reporter, resolver);
    });

    context.registry.addClassDeclaration((node) {
      _checkFrameworkClass(node, reporter, resolver);
    });

    context.registry.addMethodDeclaration((node) {
      _checkFrameworkMethod(node, reporter, resolver);
    });
  }

  void _checkFrameworkImports(
    ImportDirective node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    final importUri = node.uri.stringValue;
    if (importUri == null) return;

    // Skip test files - they may need direct framework access
    if (CleanArchitectureUtils.shouldExcludeFile(filePath)) return;

    // Check if framework imports are leaking into inner layers
    if (_isFrameworkImport(importUri)) {
      if (_isInnerLayer(filePath)) {
        final layerType = _getLayerType(filePath);
        final code = LintCode(
          name: 'framework_isolation',
          problemMessage: 'Framework import detected in $layerType layer: $importUri',
          correctionMessage: 'Move framework dependencies to framework layer. Use abstractions in $layerType layer.',
        );
        reporter.atNode(node, code);
      }
    }

    // Check for specific framework violations
    final violation = _checkSpecificFrameworkViolation(importUri, filePath);
    if (violation != null) {
      final enhancedCode = LintCode(
        name: 'framework_isolation',
        problemMessage: violation.message,
        correctionMessage: violation.suggestion,
      );
      reporter.atNode(node, enhancedCode);
    }
  }

  void _checkFrameworkClass(
    ClassDeclaration node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;

    if (_isFrameworkLayer(filePath)) {
      // In framework layer - check for business logic leakage
      _checkFrameworkLayerClass(node, reporter);
    } else if (_isInnerLayer(filePath)) {
      // In inner layers - check for framework dependencies
      _checkInnerLayerFrameworkDependencies(node, reporter, filePath);
    }
  }

  void _checkFrameworkMethod(
    MethodDeclaration method,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    final methodName = method.name.lexeme;

    if (_isFrameworkLayer(filePath)) {
      // Check if framework layer contains business logic
      if (_containsBusinessLogic(method, methodName)) {
        final code = LintCode(
          name: 'framework_isolation',
          problemMessage: 'Framework layer contains business logic: $methodName',
          correctionMessage: 'Move business logic to appropriate inner layer (use case, entity, or adapter).',
        );
        reporter.atNode(method, code);
      }

      // Check if it's proper glue code
      if (!_isGlueCode(method, methodName)) {
        final code = LintCode(
          name: 'framework_isolation',
          problemMessage: 'Framework layer should contain only glue code: $methodName',
          correctionMessage: 'Framework layer should only connect frameworks to adapters with minimal glue code.',
        );
        reporter.atNode(method, code);
      }
    }
  }

  void _checkFrameworkLayerClass(
    ClassDeclaration node,
    ErrorReporter reporter,
  ) {
    final className = node.name.lexeme;

    // Check for business logic in framework layer
    for (final member in node.members) {
      if (member is MethodDeclaration) {
        final methodName = member.name.lexeme;

        if (_containsBusinessLogic(member, methodName)) {
          final code = LintCode(
            name: 'framework_isolation',
            problemMessage: 'Framework class contains business logic: $methodName in $className',
            correctionMessage: 'Move business logic to inner layers. Framework should only contain glue code.',
          );
          reporter.atNode(member, code);
        }

        if (_containsAdapterLogic(member, methodName)) {
          final code = LintCode(
            name: 'framework_isolation',
            problemMessage: 'Framework class contains adapter logic: $methodName in $className',
            correctionMessage:
                'Move adapter logic to adapter layer. Framework should only provide framework-specific implementation.',
          );
          reporter.atNode(member, code);
        }
      }
    }

    // Check for adapter dependencies in framework
    _checkFrameworkClassDependencies(node, reporter);
  }

  void _checkInnerLayerFrameworkDependencies(
    ClassDeclaration node,
    ErrorReporter reporter,
    String filePath,
  ) {
    final layerType = _getLayerType(filePath);

    // Check inheritance
    final extendsClause = node.extendsClause;
    if (extendsClause != null) {
      final superTypeName = extendsClause.superclass.name2.lexeme;
      if (_isFrameworkClass(superTypeName)) {
        final code = LintCode(
          name: 'framework_isolation',
          problemMessage: '$layerType class extends framework class: $superTypeName',
          correctionMessage: 'Use composition instead of inheritance. Create abstractions in $layerType layer.',
        );
        reporter.atNode(extendsClause, code);
      }
    }

    // Check field dependencies
    for (final member in node.members) {
      if (member is FieldDeclaration) {
        final type = member.fields.type;
        if (type is NamedType) {
          final typeName = type.name2.lexeme;
          if (_isFrameworkClass(typeName)) {
            final code = LintCode(
              name: 'framework_isolation',
              problemMessage: '$layerType layer depends on framework class: $typeName',
              correctionMessage: 'Use abstractions instead of direct framework dependencies in $layerType layer.',
            );
            reporter.atNode(type, code);
          }
        }
      }
    }
  }

  void _checkFrameworkClassDependencies(
    ClassDeclaration node,
    ErrorReporter reporter,
  ) {
    for (final member in node.members) {
      if (member is FieldDeclaration) {
        final type = member.fields.type;
        if (type is NamedType) {
          final typeName = type.name2.lexeme;

          // Framework should not depend on business logic
          if (_isBusinessLogicClass(typeName)) {
            final code = LintCode(
              name: 'framework_isolation',
              problemMessage: 'Framework layer depends on business logic: $typeName',
              correctionMessage: 'Framework should only depend on abstractions, not business logic classes.',
            );
            reporter.atNode(type, code);
          }
        }
      }
    }
  }

  FrameworkViolation? _checkSpecificFrameworkViolation(String importUri, String filePath) {
    // Database framework violations
    if (_isDatabaseFramework(importUri) && !_isFrameworkLayer(filePath)) {
      return FrameworkViolation(
        message: 'Database framework leaked into ${_getLayerType(filePath)} layer: $importUri',
        suggestion: 'Move database details to framework layer. Use repository abstractions.',
      );
    }

    // Web framework violations
    if (_isWebFramework(importUri) && !_isFrameworkLayer(filePath) && !_isPresentationLayer(filePath)) {
      return FrameworkViolation(
        message: 'Web framework leaked into ${_getLayerType(filePath)} layer: $importUri',
        suggestion: 'Keep web framework in outermost layer. Use abstractions for web concerns.',
      );
    }

    // UI framework violations (more strict)
    if (_isUIFramework(importUri) && _isDomainLayer(filePath) && !CleanArchitectureUtils.shouldExcludeFile(filePath)) {
      return FrameworkViolation(
        message: 'UI framework leaked into domain layer: $importUri',
        suggestion: 'Domain layer must be UI-independent. Remove UI framework dependencies.',
      );
    }

    // Flutter Web specific allowances
    if (_isFlutterWebImport(importUri) && _isFlutterWebContext(filePath)) {
      return null; // Allow Flutter Web imports in web-specific files
    }

    return null;
  }

  bool _containsBusinessLogic(MethodDeclaration method, String methodName) {
    final businessLogicPatterns = [
      'validate',
      'calculate',
      'process',
      'apply',
      'business',
      'rule',
      'policy',
      'logic',
      'usecase',
      'entity',
      'domain',
    ];

    final hasBusinessLogicName = businessLogicPatterns.any((pattern) => methodName.toLowerCase().contains(pattern));

    if (hasBusinessLogicName) return true;

    // Check method body for business logic
    final body = method.body;
    if (body is BlockFunctionBody) {
      final bodyString = body.toString();
      final businessPatterns = [
        'if (',
        'switch (',
        'for (',
        'while (',
        'validate',
        'calculate',
        'business',
      ];

      // Complex logic suggests business rules
      final complexityCount =
          businessPatterns.fold(0, (count, pattern) => count + bodyString.split(pattern).length - 1);

      return complexityCount > 3; // Threshold for business logic
    }

    return false;
  }

  bool _containsAdapterLogic(MethodDeclaration method, String methodName) {
    final adapterLogicPatterns = [
      'convert',
      'map',
      'transform',
      'adapt',
      'toDto',
      'fromDto',
      'serialize',
      'deserialize',
    ];

    return adapterLogicPatterns.any((pattern) => methodName.toLowerCase().contains(pattern));
  }

  bool _isGlueCode(MethodDeclaration method, String methodName) {
    final glueCodePatterns = [
      'configure', 'setup', 'initialize', 'connect',
      'wire', 'bind', 'register', 'create',
      'main', 'run', 'start', 'launch',
      // Flutter-specific glue code patterns
      'runapp', 'buildapp', 'createapp', 'setupapp',
      'configureapp', 'initializeapp', 'bootstrapapp',
    ];

    final isGlueCodeName = glueCodePatterns.any((pattern) => methodName.toLowerCase().contains(pattern));

    if (isGlueCodeName) return true;

    // Allow Flutter app setup methods
    if (_isFlutterAppSetupMethod(methodName)) return true;

    // Check if method is simple (minimal logic)
    final body = method.body;
    if (body is BlockFunctionBody) {
      final bodyString = body.toString();

      // Glue code should be simple - increased thresholds for practical use
      final statementCount = bodyString.split(';').length - 1;
      final lineCount = bodyString.split('\n').length;

      return statementCount <= 15 && lineCount <= 30; // More flexible for real projects
    }

    return false;
  }

  bool _isFlutterAppSetupMethod(String methodName) {
    final flutterAppMethods = ['runApp', 'main', 'createApp', 'buildApp', 'configureApp', 'setupApp', 'initializeApp'];
    return flutterAppMethods.any((method) => methodName == method);
  }

  bool _isFrameworkImport(String importUri) {
    final frameworkImports = [
      // UI Frameworks
      'package:flutter/',
      'package:angular/',
      'package:react/',

      // Web Frameworks
      'package:shelf/',
      'package:dart_frog/',
      'package:conduit/',

      // Database Frameworks
      'package:sqflite/',
      'package:drift/',
      'package:floor/',
      'package:hive/',
      'package:isar/',
      'package:realm/',
      'package:objectbox/',

      // HTTP Frameworks
      'package:http/',
      'package:dio/',
      'package:retrofit/',

      // Platform
      'dart:io',
      'dart:html',
      'dart:js',
      'dart:ui',
    ];

    return frameworkImports.any((framework) => importUri.startsWith(framework));
  }

  bool _isDatabaseFramework(String importUri) {
    final databaseFrameworks = [
      'package:sqflite/',
      'package:drift/',
      'package:floor/',
      'package:hive/',
      'package:isar/',
      'package:realm/',
      'package:objectbox/',
      'package:mongo_dart/',
      'package:mysql1/',
      'package:postgres/',
    ];

    return databaseFrameworks.any((db) => importUri.startsWith(db));
  }

  bool _isWebFramework(String importUri) {
    final webFrameworks = [
      'package:shelf/',
      'package:dart_frog/',
      'package:conduit/',
      'package:angel3/',
      'dart:html',
      'dart:js',
    ];

    return webFrameworks.any((web) => importUri.startsWith(web));
  }

  bool _isUIFramework(String importUri) {
    final uiFrameworks = [
      'package:flutter/',
      'package:angular/',
      'dart:ui',
    ];

    // Allow flutter_test in test files
    if (importUri.startsWith('package:flutter_test/')) {
      return false;
    }

    return uiFrameworks.any((ui) => importUri.startsWith(ui));
  }

  bool _isFrameworkClass(String className) {
    final frameworkClasses = [
      'Widget',
      'StatefulWidget',
      'StatelessWidget',
      'HttpServer',
      'HttpClient',
      'Request',
      'Response',
      'Database',
      'Transaction',
      'Connection',
      'Box',
      'IsarCollection',
      'RealmObject',
    ];

    return frameworkClasses.any((cls) => className.contains(cls));
  }

  bool _isBusinessLogicClass(String className) {
    final businessClasses = [
      'UseCase',
      'Service',
      'Entity',
      'Repository',
      'BusinessLogic',
      'DomainService',
      'Interactor',
    ];

    return businessClasses.any((cls) => className.contains(cls));
  }

  bool _isFrameworkLayer(String filePath) {
    final frameworkPaths = [
      '/framework/',
      '\\framework\\',
      '/frameworks/',
      '\\frameworks\\',
      '/infrastructure/',
      '\\infrastructure\\',
      '/external/',
      '\\external\\',
      '/drivers/',
      '\\drivers\\',
      '/main.dart',
      '\\main.dart',
      '/app.dart',
      '\\app.dart',
      '/bootstrap/',
      '\\bootstrap\\',
    ];

    return frameworkPaths.any((path) => filePath.contains(path));
  }


  bool _isFlutterWebImport(String importUri) {
    return importUri.startsWith('dart:html') || importUri.startsWith('dart:js') || importUri.startsWith('dart:js_util');
  }

  bool _isFlutterWebContext(String filePath) {
    return filePath.contains('/web/') ||
        filePath.contains('\\web\\') ||
        filePath.contains('web_') ||
        filePath.endsWith('_web.dart');
  }

  bool _isInnerLayer(String filePath) {
    return _isDomainLayer(filePath) || _isAdapterLayer(filePath) || _isDataLayer(filePath);
  }

  bool _isDomainLayer(String filePath) {
    return filePath.contains('/domain/') || filePath.contains('\\domain\\');
  }

  bool _isAdapterLayer(String filePath) {
    final adapterPaths = [
      '/adapters/',
      '\\adapters\\',
      '/interface_adapters/',
      '\\interface_adapters\\',
      '/controllers/',
      '\\controllers\\',
      '/presenters/',
      '\\presenters\\',
    ];

    return adapterPaths.any((path) => filePath.contains(path));
  }

  bool _isDataLayer(String filePath) {
    return filePath.contains('/data/') || filePath.contains('\\data\\');
  }

  bool _isPresentationLayer(String filePath) {
    final presentationPaths = [
      '/presentation/',
      '\\presentation\\',
      '/ui/',
      '\\ui\\',
      '/views/',
      '\\views\\',
    ];

    return presentationPaths.any((path) => filePath.contains(path));
  }

  String _getLayerType(String filePath) {
    if (_isDomainLayer(filePath)) return 'domain';
    if (_isAdapterLayer(filePath)) return 'adapter';
    if (_isDataLayer(filePath)) return 'data';
    if (_isPresentationLayer(filePath)) return 'presentation';
    return 'unknown';
  }
}

class FrameworkViolation {
  final String message;
  final String suggestion;

  const FrameworkViolation({
    required this.message,
    required this.suggestion,
  });
}
