import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Enforces that Use Cases contain application-specific business rules.
///
/// This rule ensures that Use Cases follow Clean Architecture principles:
/// - Contain application-specific business rules (not enterprise rules)
/// - Are isolated from external concerns (database, UI, frameworks)
/// - Will change when application operation changes
/// - Will NOT affect entities when they change
/// - Focus on the specific application's business workflows
///
/// Use Cases should:
/// - Implement workflows specific to the application
/// - Coordinate between entities for application needs
/// - Apply business rules that are application-context dependent
/// - Remain isolated from infrastructure and UI concerns
class UseCaseApplicationRulesRule extends DartLintRule {
  const UseCaseApplicationRulesRule() : super(code: _code);

  static const _code = LintCode(
    name: 'usecase_application_rules',
    problemMessage:
        'Use Case must contain application-specific business rules and remain isolated from external concerns.',
    correctionMessage:
        'Ensure Use Case focuses on application workflows and avoids enterprise rules or external dependencies.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((node) {
      _checkApplicationRules(node, reporter, resolver);
    });

    context.registry.addImportDirective((node) {
      _checkUseCaseImports(node, reporter, resolver);
    });

    context.registry.addMethodDeclaration((node) {
      _checkMethodApplicationRules(node, reporter, resolver);
    });
  }

  void _checkApplicationRules(
    ClassDeclaration node,
    DiagnosticReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    if (!_isUseCaseFile(filePath)) return;

    final className = node.name.lexeme;

    // Check for enterprise-level naming (should be application-specific)
    if (_hasEnterpriseLevelNaming(className)) {
      final code = LintCode(
        name: 'usecase_application_rules',
        problemMessage: 'Use Case name suggests enterprise-level rules: $className',
        correctionMessage:
            'Use application-specific names. Enterprise rules belong in entities.',
      );
      reporter.atNode(node, code);
    }

    // Check for generic/reusable naming (should be application-specific)
    if (_isTooGenericForApplication(className)) {
      final code = LintCode(
        name: 'usecase_application_rules',
        problemMessage: 'Use Case name is too generic for application-specific rules: $className',
        correctionMessage:
            'Use more specific names that reflect the application\'s particular workflow.',
      );
      reporter.atNode(node, code);
    }

    // Analyze the class structure for application rule violations
    _analyzeClassForApplicationRules(node, reporter);
  }

  void _checkUseCaseImports(
    ImportDirective node,
    DiagnosticReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    if (!_isUseCaseFile(filePath)) return;

    final importUri = node.uri.stringValue;
    if (importUri == null) return;

    final violation = _checkImportForIsolationViolation(importUri);
    if (violation != null) {
      final enhancedCode = LintCode(
        name: 'usecase_application_rules',
        problemMessage: violation.message,
        correctionMessage: violation.suggestion,
      );
      reporter.atNode(node, enhancedCode);
    }
  }

  void _checkMethodApplicationRules(
    MethodDeclaration method,
    DiagnosticReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    if (!_isUseCaseFile(filePath)) return;

    final methodName = method.name.lexeme;

    // Check for enterprise-level business rules in methods
    if (_isEnterpriseLevelBusinessRule(methodName)) {
      final code = LintCode(
        name: 'usecase_application_rules',
        problemMessage: 'Method "$methodName" implements enterprise-level rules',
        correctionMessage:
            'Move enterprise-level business rules to entity classes. Use Case should orchestrate, not implement core business rules.',
      );
      reporter.atNode(method, code);
    }

    // Check for infrastructure concerns
    if (_hasInfrastructureConcerns(methodName)) {
      final code = LintCode(
        name: 'usecase_application_rules',
        problemMessage: 'Method "$methodName" contains infrastructure concerns',
        correctionMessage:
            'Use Case should be isolated from infrastructure. Use repository abstractions.',
      );
      reporter.atNode(method, code);
    }

    // Check for UI concerns
    if (_hasUIConcerns(methodName)) {
      final code = LintCode(
        name: 'usecase_application_rules',
        problemMessage: 'Method "$methodName" contains UI concerns',
        correctionMessage:
            'Use Case should be isolated from UI. Move presentation logic to presentation layer.',
      );
      reporter.atNode(method, code);
    }

    // Check method body for application rule violations
    final body = method.body;
    if (body is BlockFunctionBody) {
      _checkMethodBodyForApplicationRules(body, reporter, method);
    }
  }

  void _analyzeClassForApplicationRules(
    ClassDeclaration node,
    DiagnosticReporter reporter,
  ) {
    // Check inheritance - Use Cases shouldn't extend entities or infrastructure
    final superclass = node.extendsClause?.superclass;
    if (superclass is NamedType) {
      final superTypeName = superclass.name.lexeme;
      if (_isEntityClass(superTypeName)) {
        final code = LintCode(
          name: 'usecase_application_rules',
          problemMessage: 'Use Case should not extend entity class: $superTypeName',
          correctionMessage:
              'Use Cases should coordinate entities, not inherit from them. Use composition instead.',
        );
        reporter.atNode(superclass, code);
      }

      if (_isInfrastructureClass(superTypeName)) {
        final code = LintCode(
          name: 'usecase_application_rules',
          problemMessage: 'Use Case should not extend infrastructure class: $superTypeName',
          correctionMessage:
              'Use Cases should be isolated from infrastructure. Use dependency injection instead.',
        );
        reporter.atNode(superclass, code);
      }
    }

    // Check for fields that suggest enterprise rule implementation
    for (final member in node.members) {
      if (member is FieldDeclaration) {
        _checkFieldForApplicationRules(member, reporter);
      }
    }
  }

  void _checkFieldForApplicationRules(
    FieldDeclaration field,
    DiagnosticReporter reporter,
  ) {
    final type = field.fields.type;
    if (type is NamedType) {
      final typeName = type.name.lexeme;

      // Check for entity fields (usually bad - should be parameters/returns)
      if (_isEntityClass(typeName) && field.fields.isFinal) {
        final code = LintCode(
          name: 'usecase_application_rules',
          problemMessage: 'Use Case should not store entity as field: $typeName',
          correctionMessage:
              'Entities should be created, received from repositories, or passed as parameters.',
        );
        reporter.atNode(type, code);
      }

      // Check for infrastructure types
      if (_isInfrastructureClass(typeName)) {
        final code = LintCode(
          name: 'usecase_application_rules',
          problemMessage: 'Use Case should not depend on infrastructure: $typeName',
          correctionMessage:
              'Use repository abstractions instead of direct infrastructure dependencies.',
        );
        reporter.atNode(type, code);
      }
    }
  }

  void _checkMethodBodyForApplicationRules(
    BlockFunctionBody body,
    DiagnosticReporter reporter,
    MethodDeclaration method,
  ) {
    final bodyString = body.toString();

    // Check for enterprise rule implementation patterns
    final enterprisePatterns = [
      'validate()', 'isValid()', 'calculate()',
      'applyBusinessRule()', 'enforceRule()',
      'validateInvariant()', 'checkBusinessRule()',
    ];

    for (final pattern in enterprisePatterns) {
      if (bodyString.contains(pattern)) {
        final code = LintCode(
          name: 'usecase_application_rules',
          problemMessage: 'Use Case implementing enterprise business rule: $pattern',
          correctionMessage:
              'Move enterprise business rules to entity methods. Use Case should call entity methods.',
        );
        reporter.atNode(body, code);
        break;
      }
    }

    // Check for framework dependencies
    final frameworkPatterns = [
      'flutter.', 'material.', 'cupertino.',
      'angular.', 'react.', 'vue.',
    ];

    for (final pattern in frameworkPatterns) {
      if (bodyString.contains(pattern)) {
        final code = LintCode(
          name: 'usecase_application_rules',
          problemMessage: 'Use Case contains framework dependencies',
          correctionMessage:
              'Use Cases should be framework-agnostic. Remove framework dependencies.',
        );
        reporter.atNode(body, code);
        break;
      }
    }
  }

  IsolationViolation? _checkImportForIsolationViolation(String importUri) {
    // Check for framework imports
    final frameworkLibs = [
      'package:flutter/',
      'package:angular/',
      'package:react/',
      'dart:ui',
      'dart:html',
      'dart:js',
    ];
    for (final lib in frameworkLibs) {
      if (importUri.startsWith(lib)) {
        return IsolationViolation(
          message: 'Use Case imports framework library: $importUri',
          suggestion: 'Use Cases should be framework-agnostic. Remove framework dependencies.',
        );
      }
    }

    // Check for infrastructure imports
    final infraLibs = [
      'package:http/',
      'package:dio/',
      'package:sqflite/',
      'package:hive/',
      'package:shared_preferences/',
      'package:cloud_firestore/',
      'dart:io',
    ];
    for (final lib in infraLibs) {
      if (importUri.startsWith(lib)) {
        return IsolationViolation(
          message: 'Use Case imports infrastructure library: $importUri',
          suggestion: 'Use repository abstractions instead of direct infrastructure imports.',
        );
      }
    }

    // Check for presentation layer imports
    if (importUri.contains('/presentation/') ||
        importUri.contains('/ui/') ||
        importUri.contains('/widgets/')) {
      return IsolationViolation(
        message: 'Use Case imports from presentation layer: $importUri',
        suggestion: 'Use Cases should be isolated from presentation concerns.',
      );
    }

    return null;
  }

  bool _hasEnterpriseLevelNaming(String className) {
    final enterprisePatterns = [
      'Validate', 'Calculate', 'Process', 'Transform',
      'BusinessRule', 'CoreRule', 'DomainRule',
      'EntityValidator', 'BusinessLogic',
    ];
    return enterprisePatterns.any((pattern) => className.contains(pattern));
  }

  bool _isTooGenericForApplication(String className) {
    final genericPatterns = [
      'GenericUseCase', 'BaseUseCase', 'CommonUseCase',
      'UtilUseCase', 'HelperUseCase', 'SharedUseCase',
    ];
    return genericPatterns.any((pattern) => className.contains(pattern));
  }

  bool _isEnterpriseLevelBusinessRule(String methodName) {
    final enterpriseRulePatterns = [
      'validateBusinessRule', 'applyBusinessRule', 'enforceBusinessRule',
      'validateDomainRule', 'applyDomainRule', 'enforceDomainRule',
      'validateInvariant', 'enforceInvariant', 'checkInvariant',
      'calculateTax', 'calculateInterest', 'calculateCommission',
      'validatePayment', 'processPayment', 'calculatePayment',
    ];
    return enterpriseRulePatterns.any((pattern) =>
        methodName.toLowerCase().contains(pattern.toLowerCase()));
  }

  bool _hasInfrastructureConcerns(String methodName) {
    final infraPatterns = [
      'database', 'db', 'sql', 'cache', 'storage',
      'http', 'rest', 'api', 'network', 'connection',
      'file', 'disk', 'serialize', 'deserialize',
    ];
    return infraPatterns.any((pattern) =>
        methodName.toLowerCase().contains(pattern));
  }

  bool _hasUIConcerns(String methodName) {
    final uiPatterns = [
      'render', 'display', 'show', 'hide', 'navigate',
      'widget', 'component', 'view', 'screen', 'page',
      'click', 'tap', 'touch', 'gesture', 'animation',
    ];
    return uiPatterns.any((pattern) =>
        methodName.toLowerCase().contains(pattern));
  }

  bool _isEntityClass(String typeName) {
    return typeName.endsWith('Entity') ||
           typeName.endsWith('DomainObject') ||
           typeName.endsWith('BusinessObject');
  }

  bool _isInfrastructureClass(String typeName) {
    final infraTypes = [
      'Database', 'Cache', 'Storage', 'FileSystem',
      'HttpClient', 'RestClient', 'ApiClient', 'NetworkClient',
      'Serializer', 'Deserializer', 'Mapper',
    ];
    return infraTypes.any((type) => typeName.contains(type));
  }

  bool _isUseCaseFile(String filePath) {
    return (filePath.contains('/domain/') || filePath.contains('\\domain\\')) &&
        (filePath.contains('/usecases/') || filePath.contains('\\usecases\\') ||
         filePath.contains('/use_cases/') || filePath.contains('\\use_cases\\') ||
         filePath.endsWith('_usecase.dart') || filePath.endsWith('usecase.dart'));
  }
}

class IsolationViolation {
  final String message;
  final String suggestion;

  const IsolationViolation({
    required this.message,
    required this.suggestion,
  });
}