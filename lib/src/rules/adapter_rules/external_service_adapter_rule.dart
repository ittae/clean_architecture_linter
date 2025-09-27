import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Enforces proper external service adaptation in Interface Adapter layer.
///
/// This rule ensures that external service adapters properly isolate internal layers:
/// - Convert data from external services to internal format
/// - Convert data from internal format to external service format
/// - Shield internal layers from external service details
/// - Handle external service errors and map to domain errors
/// - Contain all knowledge about external APIs, protocols, and formats
///
/// External Service Adapters should:
/// - Be the only layer that knows external service details
/// - Handle protocol-specific concerns (HTTP, gRPC, etc.)
/// - Convert external errors to domain errors
/// - Map external data structures to internal structures
/// - Isolate business logic from external service changes
class ExternalServiceAdapterRule extends DartLintRule {
  const ExternalServiceAdapterRule() : super(code: _code);

  static const _code = LintCode(
    name: 'external_service_adapter',
    problemMessage: 'External service adapter must properly isolate internal layers from external service details.',
    correctionMessage:
        'Ensure adapter handles conversion, error mapping, and shields internal layers from external changes.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((node) {
      _checkExternalServiceAdapter(node, reporter, resolver);
    });

    context.registry.addImportDirective((node) {
      _checkExternalServiceImports(node, reporter, resolver);
    });

    context.registry.addMethodDeclaration((node) {
      _checkExternalServiceMethod(node, reporter, resolver);
    });
  }

  void _checkExternalServiceAdapter(
    ClassDeclaration node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    if (!_isAdapterLayerFile(filePath)) return;

    final className = node.name.lexeme;
    if (!_isExternalServiceAdapter(className)) return;

    // Check for proper error handling
    _checkErrorHandling(node, reporter);

    // Check for proper data conversion
    _checkDataConversion(node, reporter);

    // Check for business logic leakage
    _checkBusinessLogicLeakage(node, reporter);

    // Check adapter interface implementation
    _checkAdapterInterface(node, reporter);
  }

  void _checkExternalServiceImports(
    ImportDirective node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    if (!_isAdapterLayerFile(filePath)) return;

    final importUri = node.uri.stringValue;
    if (importUri == null) return;

    // Check if external service imports are properly isolated
    if (_isExternalServiceImport(importUri)) {
      // This is expected in adapter layer
      return;
    }

    // Check for domain imports in external adapters
    if (_isDomainImport(importUri) && !_isAllowedDomainImport(importUri)) {
      final code = LintCode(
        name: 'external_service_adapter',
        problemMessage: 'External adapter imports domain details: $importUri',
        correctionMessage: 'External adapters should only import necessary domain interfaces, not implementations.',
      );
      reporter.atNode(node, code);
    }
  }

  void _checkExternalServiceMethod(
    MethodDeclaration method,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    if (!_isAdapterLayerFile(filePath)) return;

    final methodName = method.name.lexeme;

    // Check if method properly handles external service communication
    if (_isExternalServiceMethod(methodName)) {
      _checkExternalMethodImplementation(method, reporter);
    }

    // Check for business logic in external service methods
    if (_implementsBusinessLogic(method, methodName)) {
      final code = LintCode(
        name: 'external_service_adapter',
        problemMessage: 'External adapter implements business logic: $methodName',
        correctionMessage:
            'Move business logic to use case or entity. Adapter should only handle external communication.',
      );
      reporter.atNode(method, code);
    }
  }

  void _checkErrorHandling(
    ClassDeclaration node,
    ErrorReporter reporter,
  ) {
    final methods = node.members.whereType<MethodDeclaration>().toList();

    // Check if adapter has proper error handling methods
    final hasErrorHandling = methods.any((m) => _isErrorHandlingMethod(m.name.lexeme));

    if (!hasErrorHandling && _hasExternalServiceMethods(methods)) {
      final code = LintCode(
        name: 'external_service_adapter',
        problemMessage: 'External adapter lacks error handling',
        correctionMessage: 'Add error handling to convert external service errors to domain errors.',
      );
      reporter.atNode(node, code);
    }

    // Check individual methods for error handling
    for (final method in methods) {
      if (_isExternalServiceMethod(method.name.lexeme)) {
        _checkMethodErrorHandling(method, reporter);
      }
    }
  }

  void _checkDataConversion(
    ClassDeclaration node,
    ErrorReporter reporter,
  ) {
    final methods = node.members.whereType<MethodDeclaration>().toList();

    // Check for proper conversion methods
    final hasToExternal = methods.any((m) => _isToExternalMethod(m.name.lexeme));
    final hasFromExternal = methods.any((m) => _isFromExternalMethod(m.name.lexeme));

    if (_hasExternalServiceMethods(methods) && !hasToExternal && !hasFromExternal) {
      final code = LintCode(
        name: 'external_service_adapter',
        problemMessage: 'External adapter lacks data conversion methods',
        correctionMessage: 'Add methods to convert between internal and external data formats.',
      );
      reporter.atNode(node, code);
    }
  }

  void _checkBusinessLogicLeakage(
    ClassDeclaration node,
    ErrorReporter reporter,
  ) {
    for (final member in node.members) {
      if (member is MethodDeclaration) {
        final methodName = member.name.lexeme;

        // Check for business logic implementation
        if (_implementsBusinessLogic(member, methodName)) {
          final code = LintCode(
            name: 'external_service_adapter',
            problemMessage: 'External adapter contains business logic: $methodName',
            correctionMessage:
                'Move business logic to use case or entity. Adapter should only handle external communication.',
          );
          reporter.atNode(member, code);
        }

        // Check for domain rule enforcement
        if (_enforcesDomainRules(member, methodName)) {
          final code = LintCode(
            name: 'external_service_adapter',
            problemMessage: 'External adapter enforces domain rules: $methodName',
            correctionMessage: 'Move domain rule enforcement to entity. Adapter should be passive converter.',
          );
          reporter.atNode(member, code);
        }
      }
    }
  }

  void _checkAdapterInterface(
    ClassDeclaration node,
    ErrorReporter reporter,
  ) {
    // Check if adapter implements proper interfaces
    final implementsClause = node.implementsClause;
    if (implementsClause == null) {
      final code = LintCode(
        name: 'external_service_adapter',
        problemMessage: 'External adapter should implement domain interface',
        correctionMessage: 'Implement domain interface to enable dependency inversion.',
      );
      reporter.atNode(node, code);
      return;
    }

    // Check if implemented interfaces are domain interfaces
    for (final interface in implementsClause.interfaces) {
      final interfaceName = interface.name2.lexeme;
      if (!_isDomainInterface(interfaceName)) {
        final code = LintCode(
          name: 'external_service_adapter',
          problemMessage: 'External adapter implements non-domain interface: $interfaceName',
          correctionMessage: 'Implement domain interfaces to maintain dependency inversion.',
        );
        reporter.atNode(interface, code);
      }
    }
  }

  void _checkExternalMethodImplementation(
    MethodDeclaration method,
    ErrorReporter reporter,
  ) {
    final body = method.body;
    if (body is BlockFunctionBody) {
      final bodyString = body.toString();

      // Check for proper external service patterns
      if (!_hasExternalServicePatterns(bodyString)) {
        final code = LintCode(
          name: 'external_service_adapter',
          problemMessage: 'Method should handle external service communication properly',
          correctionMessage: 'Ensure method handles external calls, errors, and data conversion.',
        );
        reporter.atNode(method, code);
      }

      // Check for missing error handling
      if (!_hasErrorHandlingPatterns(bodyString)) {
        final code = LintCode(
          name: 'external_service_adapter',
          problemMessage: 'External service method lacks error handling',
          correctionMessage: 'Add try-catch or error handling for external service calls.',
        );
        reporter.atNode(method, code);
      }
    }
  }

  void _checkMethodErrorHandling(
    MethodDeclaration method,
    ErrorReporter reporter,
  ) {
    final body = method.body;
    if (body is BlockFunctionBody) {
      final bodyString = body.toString();

      if (!_hasErrorHandlingPatterns(bodyString)) {
        final code = LintCode(
          name: 'external_service_adapter',
          problemMessage: 'External service method lacks error handling',
          correctionMessage: 'Add error handling to convert external errors to domain errors.',
        );
        reporter.atNode(method, code);
      }
    }
  }

  bool _isExternalServiceAdapter(String className) {
    final adapterPatterns = [
      'Adapter',
      'Gateway',
      'Client',
      'Service',
      'Api',
      'Rest',
      'Http',
      'Grpc',
      'External',
      'Remote',
      'Web',
    ];

    return adapterPatterns.any((pattern) => className.contains(pattern));
  }

  bool _isExternalServiceMethod(String methodName) {
    final serviceMethodPatterns = [
      'call',
      'request',
      'send',
      'fetch',
      'get',
      'post',
      'put',
      'delete',
      'invoke',
      'execute',
      'query',
    ];

    return serviceMethodPatterns.any((pattern) => methodName.toLowerCase().contains(pattern));
  }

  bool _isErrorHandlingMethod(String methodName) {
    final errorPatterns = [
      'handleError',
      'mapError',
      'convertError',
      'onError',
      'catchError',
      'errorHandler',
    ];

    return errorPatterns.any((pattern) => methodName.contains(pattern));
  }

  bool _isToExternalMethod(String methodName) {
    final toExternalPatterns = [
      'toRequest',
      'toApi',
      'toExternal',
      'serialize',
      'encode',
      'format',
    ];

    return toExternalPatterns.any((pattern) => methodName.contains(pattern));
  }

  bool _isFromExternalMethod(String methodName) {
    final fromExternalPatterns = [
      'fromResponse',
      'fromApi',
      'fromExternal',
      'deserialize',
      'decode',
      'parse',
    ];

    return fromExternalPatterns.any((pattern) => methodName.contains(pattern));
  }

  bool _implementsBusinessLogic(MethodDeclaration method, String methodName) {
    final businessPatterns = [
      'validate',
      'calculate',
      'process',
      'apply',
      'business',
      'rule',
      'policy',
      'logic',
    ];

    return businessPatterns.any((pattern) => methodName.toLowerCase().contains(pattern));
  }

  bool _enforcesDomainRules(MethodDeclaration method, String methodName) {
    final rulePatterns = [
      'enforce',
      'check',
      'verify',
      'ensure',
      'domainRule',
      'businessRule',
      'invariant',
    ];

    return rulePatterns.any((pattern) => methodName.toLowerCase().contains(pattern));
  }

  bool _hasExternalServiceMethods(List<MethodDeclaration> methods) {
    return methods.any((m) => _isExternalServiceMethod(m.name.lexeme));
  }

  bool _hasExternalServicePatterns(String bodyString) {
    final patterns = [
      'http',
      'client',
      'request',
      'response',
      'api',
      'service',
      'call',
      'invoke',
    ];

    return patterns.any((pattern) => bodyString.toLowerCase().contains(pattern));
  }

  bool _hasErrorHandlingPatterns(String bodyString) {
    final patterns = [
      'try',
      'catch',
      'finally',
      'error',
      'exception',
      'failure',
      'onError',
      'handleError',
    ];

    return patterns.any((pattern) => bodyString.toLowerCase().contains(pattern));
  }

  bool _isExternalServiceImport(String importUri) {
    final externalServices = [
      'package:http/',
      'package:dio/',
      'package:grpc/',
      'package:firebase_',
      'package:cloud_firestore/',
      'package:aws_',
      'package:googleapis/',
    ];

    return externalServices.any((service) => importUri.startsWith(service));
  }

  bool _isDomainImport(String importUri) {
    return importUri.contains('/domain/') || importUri.contains('\\domain\\');
  }

  bool _isAllowedDomainImport(String importUri) {
    // Allow imports of interfaces, entities for conversion, but not use cases
    return importUri.contains('/entities/') ||
        importUri.contains('/repositories/') ||
        importUri.contains('/interfaces/') ||
        !importUri.contains('/usecases/');
  }

  bool _isDomainInterface(String interfaceName) {
    final domainPatterns = [
      'Repository',
      'Gateway',
      'Service',
      'Interface',
      'Port',
      'Contract',
    ];

    return domainPatterns.any((pattern) => interfaceName.contains(pattern)) || interfaceName.startsWith('I');
  }

  bool _isAdapterLayerFile(String filePath) {
    final adapterPaths = [
      '/adapters/',
      '\\adapters\\',
      '/interface_adapters/',
      '\\interface_adapters\\',
      '/external/',
      '\\external\\',
      '/infrastructure/',
      '\\infrastructure\\',
      '/gateways/',
      '\\gateways\\',
      '/services/',
      '\\services\\',
    ];

    return adapterPaths.any((path) => filePath.contains(path));
  }
}
