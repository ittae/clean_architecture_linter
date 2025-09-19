import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Enforces that entities contain only enterprise-wide business rules.
///
/// This rule ensures that entities follow Clean Architecture principles:
/// - Encapsulate the most general and high-level business rules
/// - Remain stable and independent of external changes
/// - Are application-agnostic and reusable across different applications
/// - Do not contain infrastructure, UI, or application-specific concerns
///
/// Entities should be the least likely to change when something external changes.
/// They should not be affected by changes to page navigation, security,
/// databases, web services, or any particular application concerns.
class EntityBusinessRulesRule extends DartLintRule {
  const EntityBusinessRulesRule() : super(code: _code);

  static const _code = LintCode(
    name: 'entity_business_rules',
    problemMessage:
        'Entities must contain only enterprise-wide business rules and remain application-agnostic.',
    correctionMessage:
        'Remove application-specific, infrastructure, or UI concerns from entity. Move them to appropriate layers.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((node) {
      _checkEntityBusinessRules(node, reporter, resolver);
    });

    context.registry.addImportDirective((node) {
      _checkEntityImports(node, reporter, resolver);
    });
  }

  void _checkEntityBusinessRules(
    ClassDeclaration node,
    DiagnosticReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;

    // Only check entity files
    if (!_isEntityFile(filePath)) return;

    final className = node.name.lexeme;

    // Check methods for business rule violations
    for (final member in node.members) {
      if (member is MethodDeclaration) {
        _checkMethodForBusinessRuleViolations(member, reporter, className);
      } else if (member is FieldDeclaration) {
        _checkFieldForBusinessRuleViolations(member, reporter, className);
      }
    }

    // Check inheritance for application-specific concerns
    _checkInheritanceForBusinessRules(node, reporter);
  }

  void _checkEntityImports(
    ImportDirective node,
    DiagnosticReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    if (!_isEntityFile(filePath)) return;

    final importUri = node.uri.stringValue;
    if (importUri == null) return;

    final violation = _checkImportForBusinessRuleViolation(importUri);
    if (violation != null) {
      final enhancedCode = LintCode(
        name: 'entity_business_rules',
        problemMessage: violation.message,
        correctionMessage: violation.suggestion,
      );
      reporter.atNode(node, enhancedCode);
    }
  }

  void _checkMethodForBusinessRuleViolations(
    MethodDeclaration method,
    DiagnosticReporter reporter,
    String className,
  ) {
    final methodName = method.name.lexeme;

    // Check for application-specific method names
    if (_isApplicationSpecificMethod(methodName)) {
      final code = LintCode(
        name: 'entity_business_rules',
        problemMessage:
            'Method "$methodName" appears application-specific in entity "$className"',
        correctionMessage:
            'Entities should contain only enterprise-wide business rules. Move application-specific logic to use cases or services.',
      );
      reporter.atNode(method, code);
    }

    // Check for infrastructure concerns in method names
    if (_isInfrastructureMethod(methodName)) {
      final code = LintCode(
        name: 'entity_business_rules',
        problemMessage:
            'Method "$methodName" contains infrastructure concerns in entity "$className"',
        correctionMessage:
            'Remove infrastructure concerns from entity. Use repository abstractions or move to data layer.',
      );
      reporter.atNode(method, code);
    }

    // Check for UI/presentation concerns
    if (_isUIMethod(methodName)) {
      final code = LintCode(
        name: 'entity_business_rules',
        problemMessage:
            'Method "$methodName" contains UI concerns in entity "$className"',
        correctionMessage:
            'Remove UI/presentation logic from entity. Move to presentation layer or use case.',
      );
      reporter.atNode(method, code);
    }

    // Check method body for violations (if accessible)
    final body = method.body;
    if (body is BlockFunctionBody) {
      _checkMethodBodyForViolations(body, reporter, methodName);
    }
  }

  void _checkFieldForBusinessRuleViolations(
    FieldDeclaration field,
    DiagnosticReporter reporter,
    String className,
  ) {
    final type = field.fields.type;
    if (type is NamedType) {
      final typeName = type.name.lexeme;

      // Check for application-specific types
      if (_isApplicationSpecificType(typeName)) {
        final code = LintCode(
          name: 'entity_business_rules',
          problemMessage:
              'Field type "$typeName" is application-specific in entity "$className"',
          correctionMessage:
              'Use domain-specific types instead of application-specific types in entities.',
        );
        reporter.atNode(type, code);
      }

      // Check for infrastructure types
      if (_isInfrastructureType(typeName)) {
        final code = LintCode(
          name: 'entity_business_rules',
          problemMessage:
              'Field type "$typeName" contains infrastructure concerns in entity "$className"',
          correctionMessage:
              'Remove infrastructure dependencies from entity. Use domain abstractions.',
        );
        reporter.atNode(type, code);
      }
    }
  }

  void _checkMethodBodyForViolations(
    BlockFunctionBody body,
    DiagnosticReporter reporter,
    String methodName,
  ) {
    // Simple check for infrastructure calls without visitor
    // This can be enhanced later if needed
    final bodyString = body.toString();
    final infraCalls = [
      'http', '.get(', '.post(', '.put(', '.delete(',
      'query(', 'execute(', 'insert(', 'update(',
      'writeFile(', 'readFile(', 'saveToFile(',
      'connectToDatabase(', 'openConnection(',
    ];

    for (final call in infraCalls) {
      if (bodyString.contains(call)) {
        final code = LintCode(
          name: 'entity_business_rules',
          problemMessage: 'Direct infrastructure call detected in entity method: $call',
          correctionMessage: 'Remove infrastructure calls from entity. Use domain services or repository abstractions.',
        );
        reporter.atNode(body, code);
        break; // Report only once per method
      }
    }
  }

  void _checkInheritanceForBusinessRules(
    ClassDeclaration node,
    DiagnosticReporter reporter,
  ) {
    // Check superclass
    final superclass = node.extendsClause?.superclass;
    if (superclass is NamedType) {
      final superTypeName = superclass.name.lexeme;
      if (_isApplicationSpecificType(superTypeName) ||
          _isInfrastructureType(superTypeName)) {
        final code = LintCode(
          name: 'entity_business_rules',
          problemMessage:
              'Entity extends application/infrastructure-specific class: $superTypeName',
          correctionMessage:
              'Entities should not inherit from application or infrastructure classes.',
        );
        reporter.atNode(superclass, code);
      }
    }

    // Check implemented interfaces
    final interfaces = node.implementsClause?.interfaces;
    if (interfaces != null) {
      for (final interface in interfaces) {
        final interfaceName = interface.name.lexeme;
        if (_isApplicationSpecificType(interfaceName) ||
            _isInfrastructureType(interfaceName)) {
          final code = LintCode(
            name: 'entity_business_rules',
            problemMessage:
                'Entity implements application/infrastructure-specific interface: $interfaceName',
            correctionMessage:
                'Entities should only implement domain-specific interfaces.',
          );
          reporter.atNode(interface, code);
        }
      }
    }
  }

  BusinessRuleViolation? _checkImportForBusinessRuleViolation(String importUri) {
    // Check for UI framework imports
    final uiFrameworks = [
      'package:flutter/',
      'dart:ui',
      'dart:html',
    ];
    for (final framework in uiFrameworks) {
      if (importUri.startsWith(framework)) {
        return BusinessRuleViolation(
          message: 'Entity imports UI framework: $importUri',
          suggestion:
              'Entities should not depend on UI frameworks. Remove UI dependencies.',
        );
      }
    }

    // Check for infrastructure imports
    final infrastructureLibs = [
      'package:http/',
      'package:dio/',
      'package:sqflite/',
      'package:shared_preferences/',
      'package:cloud_firestore/',
      'dart:io',
    ];
    for (final lib in infrastructureLibs) {
      if (importUri.startsWith(lib)) {
        return BusinessRuleViolation(
          message: 'Entity imports infrastructure library: $importUri',
          suggestion:
              'Entities should not depend on infrastructure. Use domain abstractions.',
        );
      }
    }

    // Check for application-specific imports
    if (importUri.contains('/application/') ||
        importUri.contains('/apps/') ||
        importUri.contains('/features/')) {
      return BusinessRuleViolation(
        message: 'Entity imports application-specific code: $importUri',
        suggestion:
            'Entities should be application-agnostic. Remove application-specific dependencies.',
      );
    }

    return null;
  }

  bool _isApplicationSpecificMethod(String methodName) {
    final appSpecificPatterns = [
      'navigate', 'route', 'screen', 'page',
      'login', 'logout', 'authenticate', 'authorize',
      'cache', 'store', 'load', 'fetch',
      'sync', 'upload', 'download',
      'notify', 'alert', 'toast', 'dialog',
      'refresh', 'reload',
    ];
    final lowerMethodName = methodName.toLowerCase();
    return appSpecificPatterns.any((pattern) => lowerMethodName.contains(pattern));
  }

  bool _isInfrastructureMethod(String methodName) {
    final infraPatterns = [
      'database', 'db', 'sql', 'query',
      'http', 'api', 'request', 'response',
      'file', 'storage', 'disk',
      'network', 'connection',
      'serialize', 'deserialize', 'json', 'xml',
    ];
    final lowerMethodName = methodName.toLowerCase();
    return infraPatterns.any((pattern) => lowerMethodName.contains(pattern));
  }

  bool _isUIMethod(String methodName) {
    final uiPatterns = [
      'render', 'draw', 'paint', 'widget',
      'click', 'tap', 'touch', 'gesture',
      'animation', 'transition',
      'theme', 'style', 'color',
      'layout', 'position', 'size',
    ];
    final lowerMethodName = methodName.toLowerCase();
    return uiPatterns.any((pattern) => lowerMethodName.contains(pattern));
  }

  bool _isApplicationSpecificType(String typeName) {
    final appSpecificTypes = [
      'Controller', 'Service', 'Manager', 'Handler',
      'Router', 'Navigator', 'Screen', 'Page',
      'Cache', 'Storage', 'Database',
      'HttpClient', 'ApiClient', 'NetworkClient',
      'Notifier', 'Broadcaster', 'EventBus',
    ];
    return appSpecificTypes.any((type) => typeName.contains(type));
  }

  bool _isInfrastructureType(String typeName) {
    final infraTypes = [
      'Database', 'SqlDatabase', 'NoSqlDatabase',
      'HttpClient', 'RestClient', 'ApiClient',
      'FileSystem', 'Storage', 'Cache',
      'NetworkAdapter', 'DataSource',
      'Repository', // Repository interfaces are OK, but implementations are not
    ];

    // Allow repository interfaces but not implementations
    if (typeName.contains('Repository')) {
      return typeName.contains('Impl') || typeName.contains('Implementation');
    }

    return infraTypes.contains(typeName);
  }

  bool _isEntityFile(String filePath) {
    return (filePath.contains('/domain/') || filePath.contains('\\domain\\')) &&
        (filePath.contains('/entities/') || filePath.contains('\\entities\\') ||
         filePath.endsWith('_entity.dart') || filePath.endsWith('entity.dart'));
  }
}


class BusinessRuleViolation {
  final String message;
  final String suggestion;

  const BusinessRuleViolation({
    required this.message,
    required this.suggestion,
  });
}