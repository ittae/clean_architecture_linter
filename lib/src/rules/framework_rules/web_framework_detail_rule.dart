import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Enforces that web framework details remain isolated in the framework layer.
///
/// This rule ensures that web frameworks are treated as details:
/// - Web-specific code should only exist in framework layer
/// - HTTP concerns should be restricted to framework layer
/// - Request/Response handling should not leak to inner layers
/// - Web routing should be managed in framework layer
/// - Inner layers should use abstractions, never direct web access
///
/// Web as a detail means:
/// - No HTTP handling in business logic
/// - No web session management in inner layers
/// - No web routing knowledge in business logic
/// - Web framework can be replaced without affecting inner layers
class WebFrameworkDetailRule extends DartLintRule {
  const WebFrameworkDetailRule() : super(code: _code);

  static const _code = LintCode(
    name: 'web_framework_detail',
    problemMessage:
        'Web framework is a detail and must be isolated to framework layer.',
    correctionMessage:
        'Move web-specific code to framework layer. Use abstractions in inner layers.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addImportDirective((node) {
      _checkWebImports(node, reporter, resolver);
    });

    context.registry.addClassDeclaration((node) {
      _checkWebClass(node, reporter, resolver);
    });

    context.registry.addMethodDeclaration((node) {
      _checkWebMethod(node, reporter, resolver);
    });
  }

  void _checkWebImports(
    ImportDirective node,
    DiagnosticReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    final importUri = node.uri.stringValue;
    if (importUri == null) return;

    if (_isWebFrameworkImport(importUri)) {
      if (!_isFrameworkLayer(filePath)) {
        final layerType = _getLayerType(filePath);
        final code = LintCode(
          name: 'web_framework_detail',
          problemMessage: 'Web framework import leaked into $layerType layer: $importUri',
          correctionMessage:
              'Move web dependencies to framework layer. Use abstractions in $layerType layer.',
        );
        reporter.atNode(node, code);
      }
    }

    // Check for platform-specific web imports
    if (_isPlatformWebImport(importUri) && !_isFrameworkLayer(filePath)) {
      final layerType = _getLayerType(filePath);
      final code = LintCode(
        name: 'web_framework_detail',
        problemMessage: 'Platform web import found in $layerType layer: $importUri',
        correctionMessage:
            'Keep platform-specific web code in framework layer. Use platform-agnostic abstractions.',
      );
      reporter.atNode(node, code);
    }
  }

  void _checkWebClass(
    ClassDeclaration node,
    DiagnosticReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    if (_isFrameworkLayer(filePath)) {
      // In framework layer - check for business logic leakage
      _checkFrameworkWebClass(node, reporter);
    } else {
      // In inner layers - check for web details
      _checkInnerLayerWebClass(node, reporter, filePath);
    }
  }

  void _checkWebMethod(
    MethodDeclaration method,
    DiagnosticReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    final methodName = method.name.lexeme;

    if (!_isFrameworkLayer(filePath)) {
      // Check for HTTP operations in inner layers
      if (_containsHTTPOperation(method, methodName)) {
        final layerType = _getLayerType(filePath);
        final code = LintCode(
          name: 'web_framework_detail',
          problemMessage: 'HTTP operation found in $layerType layer: $methodName',
          correctionMessage:
              'Move HTTP operations to framework layer. Use service abstractions in $layerType layer.',
        );
        reporter.atNode(method, code);
      }

      // Check for web routing
      if (_containsWebRouting(method, methodName)) {
        final layerType = _getLayerType(filePath);
        final code = LintCode(
          name: 'web_framework_detail',
          problemMessage: 'Web routing found in $layerType layer: $methodName',
          correctionMessage:
              'Move web routing to framework layer. Use navigation abstractions in $layerType layer.',
        );
        reporter.atNode(method, code);
      }

      // Check for session management
      if (_containsSessionManagement(method, methodName)) {
        final layerType = _getLayerType(filePath);
        final code = LintCode(
          name: 'web_framework_detail',
          problemMessage: 'Session management found in $layerType layer: $methodName',
          correctionMessage:
              'Move session management to framework layer. Use user context abstractions.',
        );
        reporter.atNode(method, code);
      }

      // Check for request/response handling
      if (_containsRequestResponseHandling(method, methodName)) {
        final layerType = _getLayerType(filePath);
        final code = LintCode(
          name: 'web_framework_detail',
          problemMessage: 'Request/Response handling found in $layerType layer: $methodName',
          correctionMessage:
              'Move HTTP request/response handling to framework layer. Use data transfer objects.',
        );
        reporter.atNode(method, code);
      }
    } else {
      // In framework layer - check for business logic in web code
      if (_containsBusinessLogicInWeb(method, methodName)) {
        final code = LintCode(
          name: 'web_framework_detail',
          problemMessage: 'Business logic found in web framework code: $methodName',
          correctionMessage:
              'Move business logic to appropriate inner layer. Web code should only handle HTTP concerns.',
        );
        reporter.atNode(method, code);
      }
    }
  }

  void _checkFrameworkWebClass(
    ClassDeclaration node,
    DiagnosticReporter reporter,
  ) {
    final className = node.name.lexeme;

    // Check for business logic in web framework classes
    for (final member in node.members) {
      if (member is MethodDeclaration) {
        final methodName = member.name.lexeme;

        if (_containsBusinessLogicInWeb(member, methodName)) {
          final code = LintCode(
            name: 'web_framework_detail',
            problemMessage: 'Web class contains business logic: $methodName in $className',
            correctionMessage:
                'Move business logic to inner layers. Web should only handle HTTP concerns.',
          );
          reporter.atNode(member, code);
        }

        // Check for domain logic in HTTP handlers
        if (_containsDomainLogicInHandler(member, methodName)) {
          final code = LintCode(
            name: 'web_framework_detail',
            problemMessage: 'HTTP handler contains domain logic: $methodName in $className',
            correctionMessage:
                'Move domain logic to use cases. HTTP handler should only coordinate.',
          );
          reporter.atNode(member, code);
        }
      }
    }

    // Check for adapter logic in web framework
    _checkWebFrameworkResponsibilities(node, reporter);
  }

  void _checkInnerLayerWebClass(
    ClassDeclaration node,
    DiagnosticReporter reporter,
    String filePath,
  ) {
    final className = node.name.lexeme;
    final layerType = _getLayerType(filePath);

    // Check for web class names in inner layers
    if (_isWebClassName(className)) {
      final code = LintCode(
        name: 'web_framework_detail',
        problemMessage: 'Web class found in $layerType layer: $className',
        correctionMessage:
            'Move web classes to framework layer. Use abstractions in $layerType layer.',
      );
      reporter.atNode(node, code);
    }

    // Check for web field dependencies
    for (final member in node.members) {
      if (member is FieldDeclaration) {
        final type = member.fields.type;
        if (type is NamedType) {
          final typeName = type.name.lexeme;
          if (_isWebFrameworkType(typeName)) {
            final code = LintCode(
              name: 'web_framework_detail',
              problemMessage: '$layerType class depends on web framework type: $typeName',
              correctionMessage:
                  'Use service abstractions instead of direct web framework dependencies.',
            );
            reporter.atNode(type, code);
          }
        }
      }
    }

    // Check inheritance from web classes
    final extendsClause = node.extendsClause;
    if (extendsClause != null) {
      final superTypeName = extendsClause.superclass.name.lexeme;
      if (_isWebFrameworkType(superTypeName)) {
        final code = LintCode(
          name: 'web_framework_detail',
          problemMessage: '$layerType class extends web framework class: $superTypeName',
          correctionMessage:
              'Use composition instead of inheritance from web framework classes.',
        );
        reporter.atNode(extendsClause, code);
      }
    }
  }

  void _checkWebFrameworkResponsibilities(
    ClassDeclaration node,
    DiagnosticReporter reporter,
  ) {
    final className = node.name.lexeme;

    // Web framework should only handle HTTP concerns, not adaptation logic
    for (final member in node.members) {
      if (member is MethodDeclaration) {
        final methodName = member.name.lexeme;

        if (_containsDataConversionLogic(member, methodName)) {
          final code = LintCode(
            name: 'web_framework_detail',
            problemMessage: 'Web framework contains data conversion logic: $methodName in $className',
            correctionMessage:
                'Move data conversion to adapter layer. Web framework should only handle HTTP.',
          );
          reporter.atNode(member, code);
        }
      }
    }
  }

  bool _containsHTTPOperation(MethodDeclaration method, String methodName) {
    final httpPatterns = [
      'get', 'post', 'put', 'delete', 'patch',
      'request', 'response', 'http', 'fetch',
      'send', 'receive', 'download', 'upload',
    ];

    final hasHTTPName = httpPatterns.any((pattern) =>
        methodName.toLowerCase().contains(pattern));

    if (hasHTTPName) return true;

    // Check method body for HTTP operations
    final body = method.body;
    if (body is BlockFunctionBody) {
      final bodyString = body.toString().toLowerCase();
      final httpBodyPatterns = [
        'http.', 'request.', 'response.',
        'get(', 'post(', 'put(', 'delete(',
      ];

      return httpBodyPatterns.any((pattern) => bodyString.contains(pattern));
    }

    return false;
  }

  bool _containsWebRouting(MethodDeclaration method, String methodName) {
    final routingPatterns = [
      'route', 'navigate', 'redirect', 'forward',
      'handler', 'middleware', 'endpoint',
      'path', 'url', 'uri',
    ];

    return routingPatterns.any((pattern) =>
        methodName.toLowerCase().contains(pattern));
  }

  bool _containsSessionManagement(MethodDeclaration method, String methodName) {
    final sessionPatterns = [
      'session', 'cookie', 'authentication', 'login',
      'logout', 'auth', 'token', 'credential',
      'signin', 'signout', 'authorize',
    ];

    return sessionPatterns.any((pattern) =>
        methodName.toLowerCase().contains(pattern));
  }

  bool _containsRequestResponseHandling(MethodDeclaration method, String methodName) {
    final reqResPatterns = [
      'request', 'response', 'header', 'body',
      'query', 'param', 'form', 'json',
      'xml', 'payload', 'content',
    ];

    return reqResPatterns.any((pattern) =>
        methodName.toLowerCase().contains(pattern));
  }

  bool _containsBusinessLogicInWeb(MethodDeclaration method, String methodName) {
    final businessLogicPatterns = [
      'validate', 'calculate', 'process', 'apply',
      'business', 'rule', 'policy', 'workflow',
      'approve', 'reject', 'verify', 'check',
    ];

    return businessLogicPatterns.any((pattern) =>
        methodName.toLowerCase().contains(pattern));
  }

  bool _containsDomainLogicInHandler(MethodDeclaration method, String methodName) {
    final domainLogicPatterns = [
      'entity', 'aggregate', 'domain', 'usecase',
      'repository', 'service', 'interactor',
    ];

    final hasDirectDomainReference = domainLogicPatterns.any((pattern) =>
        methodName.toLowerCase().contains(pattern));

    if (hasDirectDomainReference) return true;

    // Check method body for direct domain logic
    final body = method.body;
    if (body is BlockFunctionBody) {
      final bodyString = body.toString();
      final domainBodyPatterns = [
        'new Entity', 'new UseCase', 'new Service',
        '.validate(', '.calculate(', '.process(',
      ];

      return domainBodyPatterns.any((pattern) => bodyString.contains(pattern));
    }

    return false;
  }

  bool _containsDataConversionLogic(MethodDeclaration method, String methodName) {
    final conversionPatterns = [
      'convert', 'map', 'transform', 'adapt',
      'toDto', 'fromDto', 'serialize', 'deserialize',
      'encode', 'decode', 'parse', 'format',
    ];

    return conversionPatterns.any((pattern) =>
        methodName.toLowerCase().contains(pattern));
  }

  bool _isWebFrameworkImport(String importUri) {
    final webFrameworkImports = [
      'package:shelf/',
      'package:dart_frog/',
      'package:conduit/',
      'package:angel3/',
      'package:jaguar/',
      'package:aqueduct/',
      'package:express/',
    ];

    return webFrameworkImports.any((web) => importUri.startsWith(web));
  }

  bool _isPlatformWebImport(String importUri) {
    final platformWebImports = [
      'dart:html',
      'dart:js',
      'dart:js_util',
      'dart:web_audio',
      'dart:web_gl',
      'dart:indexed_db',
    ];

    return platformWebImports.any((platform) => importUri.startsWith(platform));
  }

  bool _isWebClassName(String className) {
    final webClassNames = [
      'HttpServer', 'HttpClient', 'WebServer',
      'Request', 'Response', 'Handler',
      'Router', 'Route', 'Middleware',
      'Session', 'Cookie', 'Header',
    ];

    return webClassNames.any((name) => className.contains(name));
  }

  bool _isWebFrameworkType(String typeName) {
    final webTypes = [
      'HttpServer', 'HttpClient', 'HttpRequest', 'HttpResponse',
      'Request', 'Response', 'Handler', 'Middleware',
      'Router', 'Route', 'Context', 'Session',
      'WebSocket', 'ServerSocket', 'Socket',
    ];

    return webTypes.any((type) => typeName.contains(type));
  }

  bool _isFrameworkLayer(String filePath) {
    final frameworkPaths = [
      '/framework/', '\\framework\\',
      '/frameworks/', '\\frameworks\\',
      '/infrastructure/', '\\infrastructure\\',
      '/web/', '\\web\\',
      '/http/', '\\http\\',
      '/server/', '\\server\\',
      '/api/', '\\api\\',
      '/main.dart', '\\main.dart',
    ];

    return frameworkPaths.any((path) => filePath.contains(path));
  }

  String _getLayerType(String filePath) {
    if (filePath.contains('/domain/') || filePath.contains('\\domain\\')) {
      return 'domain';
    }
    if (filePath.contains('/adapters/') || filePath.contains('\\adapters\\') ||
        filePath.contains('/interface_adapters/') || filePath.contains('\\interface_adapters\\')) {
      return 'adapter';
    }
    if (filePath.contains('/data/') || filePath.contains('\\data\\')) {
      return 'data';
    }
    if (filePath.contains('/presentation/') || filePath.contains('\\presentation\\') ||
        filePath.contains('/ui/') || filePath.contains('\\ui\\')) {
      return 'presentation';
    }
    return 'unknown';
  }
}