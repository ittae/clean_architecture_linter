import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Enforces Use Case layer independence from external concerns.
///
/// This rule ensures that Use Cases remain isolated as defined in Clean Architecture:
/// - NOT affected by changes to database technology
/// - NOT affected by changes to UI frameworks
/// - NOT affected by changes to common frameworks
/// - NOT affected by changes to external services
/// - WILL be affected by changes to application operation
/// - WILL NOT affect the entities layer
///
/// Use Cases should be:
/// - Independent of database implementation
/// - Independent of UI technology
/// - Independent of external frameworks
/// - Independent of delivery mechanisms
/// - Dependent only on entities and abstractions
class UseCaseIndependenceRule extends DartLintRule {
  const UseCaseIndependenceRule() : super(code: _code);

  static const _code = LintCode(
    name: 'usecase_independence',
    problemMessage: 'Use Case must remain independent of external concerns and frameworks.',
    correctionMessage:
        'Remove dependencies on databases, UI, frameworks, or external services. Use abstractions instead.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addImportDirective((node) {
      _checkUseCaseImportIndependence(node, reporter, resolver);
    });

    context.registry.addClassDeclaration((node) {
      _checkUseCaseClassIndependence(node, reporter, resolver);
    });

    context.registry.addMethodDeclaration((node) {
      _checkUseCaseMethodIndependence(node, reporter, resolver);
    });
  }

  void _checkUseCaseImportIndependence(
    ImportDirective node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    if (!_isUseCaseFile(filePath)) return;

    final importUri = node.uri.stringValue;
    if (importUri == null) return;

    final violation = _checkImportForIndependenceViolation(importUri);
    if (violation != null) {
      final enhancedCode = LintCode(
        name: 'usecase_independence',
        problemMessage: violation.message,
        correctionMessage: violation.suggestion,
      );
      reporter.atNode(node, enhancedCode);
    }
  }

  void _checkUseCaseClassIndependence(
    ClassDeclaration node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    if (!_isUseCaseFile(filePath)) return;

    // Check inheritance for independence violations
    _checkInheritanceIndependence(node, reporter);

    // Check field dependencies for independence violations
    _checkFieldIndependence(node, reporter);

    // Check for framework-specific annotations
    _checkAnnotationIndependence(node, reporter);
  }

  void _checkUseCaseMethodIndependence(
    MethodDeclaration method,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    if (!_isUseCaseFile(filePath)) return;

    // Check method signatures for external dependencies
    _checkMethodSignatureIndependence(method, reporter);

    // Check method body for independence violations
    final body = method.body;
    if (body is BlockFunctionBody) {
      _checkMethodBodyIndependence(body, reporter, method);
    }
  }

  void _checkInheritanceIndependence(
    ClassDeclaration node,
    ErrorReporter reporter,
  ) {
    // Check superclass
    final superclass = node.extendsClause?.superclass;
    if (superclass is NamedType) {
      final superTypeName = superclass.name2.lexeme;
      if (_isExternalFrameworkClass(superTypeName)) {
        final code = LintCode(
          name: 'usecase_independence',
          problemMessage: 'Use Case extends external framework class: $superTypeName',
          correctionMessage: 'Use Cases should not depend on external frameworks. Use composition instead.',
        );
        reporter.atNode(superclass, code);
      }
    }

    // Check implemented interfaces
    final interfaces = node.implementsClause?.interfaces;
    if (interfaces != null) {
      for (final interface in interfaces) {
        final interfaceName = interface.name2.lexeme;
        if (_isExternalFrameworkClass(interfaceName)) {
          final code = LintCode(
            name: 'usecase_independence',
            problemMessage: 'Use Case implements external framework interface: $interfaceName',
            correctionMessage: 'Use Cases should not depend on external frameworks. Create domain abstractions.',
          );
          reporter.atNode(interface, code);
        }
      }
    }
  }

  void _checkFieldIndependence(
    ClassDeclaration node,
    ErrorReporter reporter,
  ) {
    for (final member in node.members) {
      if (member is FieldDeclaration) {
        final type = member.fields.type;
        if (type is NamedType) {
          final typeName = type.name2.lexeme;

          if (_isDatabaseDependency(typeName)) {
            final code = LintCode(
              name: 'usecase_independence',
              problemMessage: 'Use Case field depends on database technology: $typeName',
              correctionMessage: 'Use repository abstractions instead of direct database dependencies.',
            );
            reporter.atNode(type, code);
          }

          if (_isUIFrameworkDependency(typeName)) {
            final code = LintCode(
              name: 'usecase_independence',
              problemMessage: 'Use Case field depends on UI framework: $typeName',
              correctionMessage: 'Use Cases should be independent of UI. Remove UI framework dependencies.',
            );
            reporter.atNode(type, code);
          }

          if (_isExternalServiceDependency(typeName)) {
            final code = LintCode(
              name: 'usecase_independence',
              problemMessage: 'Use Case field depends on external service: $typeName',
              correctionMessage: 'Use service abstractions instead of direct external service dependencies.',
            );
            reporter.atNode(type, code);
          }
        }
      }
    }
  }

  void _checkAnnotationIndependence(
    ClassDeclaration node,
    ErrorReporter reporter,
  ) {
    for (final annotation in node.metadata) {
      final annotationName = annotation.name.name;
      if (_isFrameworkSpecificAnnotation(annotationName)) {
        final code = LintCode(
          name: 'usecase_independence',
          problemMessage: 'Use Case uses framework-specific annotation: @$annotationName',
          correctionMessage: 'Remove framework-specific annotations. Use Cases should be framework-agnostic.',
        );
        reporter.atNode(annotation, code);
      }
    }
  }

  void _checkMethodSignatureIndependence(
    MethodDeclaration method,
    ErrorReporter reporter,
  ) {
    // Check return type
    final returnType = method.returnType;
    if (returnType is NamedType) {
      final typeName = returnType.name2.lexeme;
      if (_isExternalFrameworkClass(typeName)) {
        final code = LintCode(
          name: 'usecase_independence',
          problemMessage: 'Use Case method returns external framework type: $typeName',
          correctionMessage: 'Return domain types or abstractions instead of framework-specific types.',
        );
        reporter.atNode(returnType, code);
      }
    }

    // Check parameters
    final parameters = method.parameters;
    if (parameters != null) {
      for (final param in parameters.parameters) {
        if (param is SimpleFormalParameter) {
          final type = param.type;
          if (type is NamedType) {
            final typeName = type.name2.lexeme;
            if (_isExternalFrameworkClass(typeName)) {
              final code = LintCode(
                name: 'usecase_independence',
                problemMessage: 'Use Case method parameter uses external framework type: $typeName',
                correctionMessage: 'Use domain types or abstractions instead of framework-specific parameters.',
              );
              reporter.atNode(type, code);
            }
          }
        }
      }
    }
  }

  void _checkMethodBodyIndependence(
    BlockFunctionBody body,
    ErrorReporter reporter,
    MethodDeclaration method,
  ) {
    final bodyString = body.toString();

    // Check for direct database calls
    final databaseCalls = [
      'database.',
      'db.',
      'sql.',
      'query(',
      'connection.',
      'statement.',
      'transaction.',
      'mongodb.',
      'firestore.',
      'redis.',
    ];

    for (final call in databaseCalls) {
      if (bodyString.contains(call)) {
        final code = LintCode(
          name: 'usecase_independence',
          problemMessage: 'Use Case contains direct database calls',
          correctionMessage: 'Use repository abstractions instead of direct database access.',
        );
        reporter.atNode(body, code);
        break;
      }
    }

    // Check for UI framework calls
    final uiCalls = [
      'Navigator.',
      'BuildContext',
      'Widget',
      'setState(',
      'notifyListeners()',
      'context.',
      'MaterialApp',
      'Scaffold',
      'AppBar',
    ];

    for (final call in uiCalls) {
      if (bodyString.contains(call)) {
        final code = LintCode(
          name: 'usecase_independence',
          problemMessage: 'Use Case contains UI framework calls',
          correctionMessage: 'Use Cases should be independent of UI. Remove UI framework calls.',
        );
        reporter.atNode(body, code);
        break;
      }
    }

    // Check for external service calls
    final externalCalls = [
      'http.',
      'dio.',
      'client.',
      'api.',
      'aws.',
      'gcp.',
      'azure.',
      'firebase.',
      'stripe.',
      'paypal.',
      'twilio.',
    ];

    for (final call in externalCalls) {
      if (bodyString.contains(call)) {
        final code = LintCode(
          name: 'usecase_independence',
          problemMessage: 'Use Case contains direct external service calls',
          correctionMessage: 'Use service abstractions instead of direct external service calls.',
        );
        reporter.atNode(body, code);
        break;
      }
    }

    // Check for platform-specific calls
    final platformCalls = [
      'Platform.',
      'dart:io',
      'dart:html',
      'window.',
      'document.',
      'localStorage.',
    ];

    for (final call in platformCalls) {
      if (bodyString.contains(call)) {
        final code = LintCode(
          name: 'usecase_independence',
          problemMessage: 'Use Case contains platform-specific calls',
          correctionMessage:
              'Use Cases should be platform-independent. Use abstractions for platform-specific functionality.',
        );
        reporter.atNode(body, code);
        break;
      }
    }
  }

  IndependenceViolation? _checkImportForIndependenceViolation(String importUri) {
    // Database dependencies
    final databaseLibs = [
      'package:sqflite/',
      'package:hive/',
      'package:drift/',
      'package:floor/',
      'package:isar/',
      'package:realm/',
      'package:mongo_dart/',
      'package:mysql1/',
      'package:postgres/',
    ];
    for (final lib in databaseLibs) {
      if (importUri.startsWith(lib)) {
        return IndependenceViolation(
          message: 'Use Case imports database library: $importUri',
          suggestion: 'Use repository abstractions instead of direct database imports.',
        );
      }
    }

    // UI Framework dependencies
    final uiLibs = [
      'package:flutter/',
      'package:angular/',
      'package:react/',
      'dart:ui',
      'dart:html',
    ];
    for (final lib in uiLibs) {
      if (importUri.startsWith(lib)) {
        return IndependenceViolation(
          message: 'Use Case imports UI framework: $importUri',
          suggestion: 'Use Cases should be independent of UI frameworks.',
        );
      }
    }

    // External service dependencies
    final serviceLibs = [
      'package:http/',
      'package:dio/',
      'package:grpc/',
      'package:firebase_',
      'package:aws_',
      'package:gcp_',
      'package:stripe_',
    ];
    for (final lib in serviceLibs) {
      if (importUri.startsWith(lib)) {
        return IndependenceViolation(
          message: 'Use Case imports external service library: $importUri',
          suggestion: 'Use service abstractions instead of direct external service imports.',
        );
      }
    }

    // Platform-specific dependencies
    final platformLibs = [
      'dart:io',
      'dart:js',
      'package:universal_io/',
      'package:universal_platform/',
    ];
    for (final lib in platformLibs) {
      if (importUri.startsWith(lib)) {
        return IndependenceViolation(
          message: 'Use Case imports platform-specific library: $importUri',
          suggestion: 'Use Cases should be platform-independent. Use abstractions.',
        );
      }
    }

    return null;
  }

  bool _isDatabaseDependency(String typeName) {
    final dbTypes = [
      'Database',
      'Connection',
      'Transaction',
      'Statement',
      'SqlDatabase',
      'NoSqlDatabase',
      'MongoDB',
      'FirebaseFirestore',
      'HiveBox',
      'IsarCollection',
      'RealmObject',
    ];
    return dbTypes.any((type) => typeName.contains(type));
  }

  bool _isUIFrameworkDependency(String typeName) {
    final uiTypes = [
      'Widget',
      'BuildContext',
      'Navigator',
      'Route',
      'Component',
      'Element',
      'View',
      'Controller',
      'MaterialApp',
      'Scaffold',
      'AppBar',
      'Drawer',
    ];
    return uiTypes.any((type) => typeName.contains(type));
  }

  bool _isExternalServiceDependency(String typeName) {
    final serviceTypes = [
      'HttpClient',
      'RestClient',
      'GraphQLClient',
      'GrpcClient',
      'FirebaseAuth',
      'FirebaseStorage',
      'StripeClient',
      'PayPalClient',
      'TwilioClient',
      'SendGridClient',
    ];
    return serviceTypes.any((type) => typeName.contains(type));
  }

  bool _isExternalFrameworkClass(String typeName) {
    final frameworkTypes = [
      'Widget',
      'Component',
      'Element',
      'Controller',
      'HttpClient',
      'RestClient',
      'Database',
      'Connection',
      'MaterialApp',
      'AngularComponent',
      'ReactComponent',
    ];
    return frameworkTypes.any((type) => typeName.contains(type));
  }

  bool _isFrameworkSpecificAnnotation(String annotationName) {
    final frameworkAnnotations = [
      'Component',
      'Injectable',
      'Service',
      'Controller',
      'Widget',
      'StatefulWidget',
      'StatelessWidget',
      'Entity',
      'Table',
      'Column',
      'PrimaryKey',
      'RestController',
      'RequestMapping',
      'Autowired',
    ];
    return frameworkAnnotations.contains(annotationName);
  }

  bool _isUseCaseFile(String filePath) {
    return (filePath.contains('/domain/') || filePath.contains('\\domain\\')) &&
        (filePath.contains('/usecases/') ||
            filePath.contains('\\usecases\\') ||
            filePath.contains('/use_cases/') ||
            filePath.contains('\\use_cases\\') ||
            filePath.endsWith('_usecase.dart') ||
            filePath.endsWith('usecase.dart'));
  }
}

class IndependenceViolation {
  final String message;
  final String suggestion;

  const IndependenceViolation({
    required this.message,
    required this.suggestion,
  });
}
