import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Enforces entity stability by ensuring they are least likely to change.
///
/// This rule validates that entities remain stable and independent:
/// - No volatile dependencies (external services, frameworks, UI)
/// - No operational concerns (logging, monitoring, performance)
/// - No application-specific business logic
/// - No technology-specific implementations
///
/// Entities should be the most stable components in the system.
/// They should not be affected by:
/// - Page navigation changes
/// - Security implementation changes
/// - Database technology changes
/// - Web service changes
/// - UI framework changes
/// - Any particular application operational changes
class EntityStabilityRule extends DartLintRule {
  const EntityStabilityRule() : super(code: _code);

  static const _code = LintCode(
    name: 'entity_stability',
    problemMessage:
        'Entities must be stable and not depend on volatile external concerns.',
    correctionMessage:
        'Remove volatile dependencies. Entities should contain only stable business rules.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((node) {
      _checkEntityStability(node, reporter, resolver);
    });

    context.registry.addImportDirective((node) {
      _checkImportStability(node, reporter, resolver);
    });
  }

  void _checkEntityStability(
    ClassDeclaration node,
    DiagnosticReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    if (!_isEntityFile(filePath)) return;

    final className = node.name.lexeme;

    // Check for volatile method patterns
    for (final member in node.members) {
      if (member is MethodDeclaration) {
        _checkMethodStability(member, reporter, className);
      } else if (member is FieldDeclaration) {
        _checkFieldStability(member, reporter, className);
      }
    }

    // Check class-level stability concerns
    _checkClassStability(node, reporter);
  }

  void _checkImportStability(
    ImportDirective node,
    DiagnosticReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    if (!_isEntityFile(filePath)) return;

    final importUri = node.uri.stringValue;
    if (importUri == null) return;

    final violation = _checkImportForVolatility(importUri);
    if (violation != null) {
      final enhancedCode = LintCode(
        name: 'entity_stability',
        problemMessage: violation.message,
        correctionMessage: violation.suggestion,
      );
      reporter.atNode(node, enhancedCode);
    }
  }

  void _checkMethodStability(
    MethodDeclaration method,
    DiagnosticReporter reporter,
    String className,
  ) {
    final methodName = method.name.lexeme;

    // Check for operational concerns
    if (_isOperationalMethod(methodName)) {
      final code = LintCode(
        name: 'entity_stability',
        problemMessage:
            'Method "$methodName" contains operational concerns in entity "$className"',
        correctionMessage:
            'Remove operational concerns from entity. Use application services or infrastructure.',
      );
      reporter.atNode(method, code);
    }

    // Check for technology-specific methods
    if (_isTechnologySpecificMethod(methodName)) {
      final code = LintCode(
        name: 'entity_stability',
        problemMessage:
            'Method "$methodName" is technology-specific in entity "$className"',
        correctionMessage:
            'Remove technology-specific concerns. Entities should be technology-agnostic.',
      );
      reporter.atNode(method, code);
    }

    // Check for volatile business rules
    if (_isVolatileBusinessRule(methodName)) {
      final code = LintCode(
        name: 'entity_stability',
        problemMessage:
            'Method "$methodName" may contain volatile business rules in entity "$className"',
        correctionMessage:
            'Consider if this is a stable enterprise rule or should be moved to use case/service.',
      );
      reporter.atNode(method, code);
    }
  }

  void _checkFieldStability(
    FieldDeclaration field,
    DiagnosticReporter reporter,
    String className,
  ) {
    final type = field.fields.type;
    if (type is NamedType) {
      final typeName = type.name.lexeme;

      // Check for volatile field types
      if (_isVolatileType(typeName)) {
        final code = LintCode(
          name: 'entity_stability',
          problemMessage:
              'Field type "$typeName" is volatile in entity "$className"',
          correctionMessage:
              'Use stable domain types instead of volatile external types.',
        );
        reporter.atNode(type, code);
      }

      // Check for configuration/settings types
      if (_isConfigurationType(typeName)) {
        final code = LintCode(
          name: 'entity_stability',
          problemMessage:
              'Field type "$typeName" represents configuration in entity "$className"',
          correctionMessage:
              'Configuration should not be in entities. Move to application configuration.',
        );
        reporter.atNode(type, code);
      }
    }
  }

  void _checkClassStability(
    ClassDeclaration node,
    DiagnosticReporter reporter,
  ) {
    final className = node.name.lexeme;

    // Check for technology-specific naming
    if (_isTechnologySpecificClassName(className)) {
      final code = LintCode(
        name: 'entity_stability',
        problemMessage: 'Entity class name "$className" is technology-specific',
        correctionMessage:
            'Use domain-specific names that are independent of technology choices.',
      );
      reporter.atNode(node, code);
    }

    // Check for temporal or context-specific naming
    if (_isTemporalClassName(className)) {
      final code = LintCode(
        name: 'entity_stability',
        problemMessage: 'Entity class name "$className" is temporally-specific',
        correctionMessage:
            'Use timeless business names that won\'t change with business context.',
      );
      reporter.atNode(node, code);
    }
  }

  StabilityViolation? _checkImportForVolatility(String importUri) {
    // Framework volatility
    final volatileFrameworks = [
      'package:flutter/',
      'package:angular/',
      'package:react/',
      'dart:ui',
      'dart:html',
      'dart:js',
    ];
    for (final framework in volatileFrameworks) {
      if (importUri.startsWith(framework)) {
        return StabilityViolation(
          message: 'Entity imports volatile framework: $importUri',
          suggestion: 'Remove framework dependencies. Entities must be framework-agnostic.',
        );
      }
    }

    // Technology volatility
    final volatileTech = [
      'package:http/',
      'package:dio/',
      'package:grpc/',
      'package:sqflite/',
      'package:hive/',
      'package:firebase_',
      'package:cloud_firestore/',
      'package:mongo_dart/',
      'dart:io',
    ];
    for (final tech in volatileTech) {
      if (importUri.startsWith(tech)) {
        return StabilityViolation(
          message: 'Entity imports volatile technology: $importUri',
          suggestion: 'Remove technology dependencies. Use domain abstractions.',
        );
      }
    }

    // Platform volatility
    final volatilePlatform = [
      'package:device_info_plus/',
      'package:permission_handler/',
      'package:path_provider/',
      'package:connectivity_plus/',
      'package:battery_plus/',
    ];
    for (final platform in volatilePlatform) {
      if (importUri.startsWith(platform)) {
        return StabilityViolation(
          message: 'Entity imports volatile platform dependency: $importUri',
          suggestion: 'Remove platform dependencies. Entities should be platform-independent.',
        );
      }
    }

    return null;
  }

  bool _isOperationalMethod(String methodName) {
    final operationalPatterns = [
      'log', 'trace', 'debug', 'monitor',
      'measure', 'profile', 'benchmark',
      'audit', 'track', 'analytics',
      'retry', 'timeout', 'circuit',
      'health', 'status', 'ping',
    ];
    final lowerMethodName = methodName.toLowerCase();
    return operationalPatterns.any((pattern) => lowerMethodName.contains(pattern));
  }

  bool _isTechnologySpecificMethod(String methodName) {
    final techPatterns = [
      'sql', 'nosql', 'mongo', 'firebase',
      'rest', 'graphql', 'grpc', 'soap',
      'redis', 'memcache', 'elasticsearch',
      'kafka', 'rabbitmq', 'sqs',
      'aws', 'azure', 'gcp', 'kubernetes',
      'docker', 'terraform',
    ];
    final lowerMethodName = methodName.toLowerCase();
    return techPatterns.any((pattern) => lowerMethodName.contains(pattern));
  }

  bool _isVolatileBusinessRule(String methodName) {
    final volatilePatterns = [
      'discount', 'promotion', 'campaign', 'offer',
      'feature', 'experiment', 'ab_test',
      'temporary', 'seasonal', 'holiday',
      'regional', 'localized', 'country_specific',
      'version_specific', 'legacy',
    ];
    final lowerMethodName = methodName.toLowerCase();
    return volatilePatterns.any((pattern) => lowerMethodName.contains(pattern));
  }

  bool _isVolatileType(String typeName) {
    final volatileTypes = [
      'HttpClient', 'RestClient', 'GraphQLClient',
      'Database', 'Cache', 'Queue',
      'Logger', 'Monitor', 'Tracer',
      'Configuration', 'Settings', 'Config',
      'Environment', 'Platform', 'Device',
      'Session', 'Context', 'Request', 'Response',
    ];
    return volatileTypes.any((type) => typeName.contains(type));
  }

  bool _isConfigurationType(String typeName) {
    final configTypes = [
      'Config', 'Configuration', 'Settings',
      'Properties', 'Environment', 'Options',
      'Parameters', 'Preferences', 'Profile',
    ];
    return configTypes.any((type) => typeName.contains(type));
  }

  bool _isTechnologySpecificClassName(String className) {
    final techPatterns = [
      'Sql', 'NoSql', 'Mongo', 'Firebase',
      'Rest', 'GraphQL', 'Grpc', 'Json', 'Xml',
      'Redis', 'Elastic', 'Kafka', 'Rabbit',
      'Aws', 'Azure', 'Gcp', 'Cloud',
      'Docker', 'Kubernetes', 'Web', 'Mobile',
    ];
    return techPatterns.any((pattern) => className.contains(pattern));
  }

  bool _isTemporalClassName(String className) {
    final temporalPatterns = [
      'Temp', 'Temporary', 'Legacy', 'Old', 'New',
      'V1', 'V2', 'Version', 'Beta', 'Alpha',
      'Experimental', 'Test', 'Demo', 'Sample',
      'Current', 'Latest', 'Updated', 'Modern',
    ];
    return temporalPatterns.any((pattern) => className.contains(pattern));
  }

  bool _isEntityFile(String filePath) {
    return (filePath.contains('/domain/') || filePath.contains('\\domain\\')) &&
        (filePath.contains('/entities/') || filePath.contains('\\entities\\') ||
         filePath.endsWith('_entity.dart') || filePath.endsWith('entity.dart'));
  }
}

class StabilityViolation {
  final String message;
  final String suggestion;

  const StabilityViolation({
    required this.message,
    required this.suggestion,
  });
}