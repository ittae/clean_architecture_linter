import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import '../../config/clean_architecture_config.dart';

/// Consolidated rule for domain entity validation.
///
/// This rule combines multiple entity-related checks:
/// 1. **Business Rules**: Entities contain only enterprise-wide business rules
/// 2. **Stability**: Entities are stable and independent of external changes
/// 3. **Immutability**: Entities are immutable for data integrity
/// Benefits of consolidation:
/// - Reduced performance overhead
/// - Consistent error reporting
/// - Simplified configuration
/// - Single pass validation
class ConsolidatedEntityRule extends DartLintRule {
  const ConsolidatedEntityRule() : super(code: _code);

  // Default configuration - can be customized through analysis_options.yaml
  static const _defaultConfig = CleanArchitectureConfig();

  // Configuration getters
  CleanArchitectureConfig get config => _defaultConfig;
  LayerPaths get layerPaths => config.layerPaths;
  RuleSeverity get severity => config.getSeverityForRule(code.name);
  bool get isRuleEnabled => config.isRuleEnabled(code.name);

  static const _code = LintCode(
    name: 'consolidated_entity_rule',
    problemMessage: 'Entity violates Clean Architecture principles',
    correctionMessage: 'Ensure entity is immutable, stable, and contains only business rules',
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    // Skip if rule is disabled
    if (!isRuleEnabled) return;

    context.registry.addClassDeclaration((node) {
      _validateEntity(node, reporter, resolver);
    });

    context.registry.addImportDirective((node) {
      _validateImports(node, reporter, resolver);
    });
  }

  void _validateEntity(
    ClassDeclaration node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;

    // Use configured paths
    if (!layerPaths.isEntityFile(filePath)) return;

    // final className = node.name.lexeme; // Will use when needed
    final violations = <EntityViolation>[];

    // 1. Check immutability
    violations.addAll(_checkImmutability(node));

    // 2. Check business rules purity
    violations.addAll(_checkBusinessRulesPurity(node));

    // 3. Check stability
    violations.addAll(_checkStability(node));

    // Report violations based on severity
    for (final violation in violations) {
      final code = _createLintCode(violation);
      reporter.atNode(violation.node ?? node, code);
    }
  }

  void _validateImports(
    ImportDirective node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    if (!layerPaths.isEntityFile(filePath)) return;

    final importUri = node.uri.stringValue;
    if (importUri == null) return;

    final violation = _checkImportViolation(importUri);
    if (violation != null) {
      final code = _createLintCode(violation);
      reporter.atNode(node, code);
    }
  }

  List<EntityViolation> _checkImmutability(ClassDeclaration node) {
    final violations = <EntityViolation>[];

    // Skip if class is @freezed or sealed
    if (_isFreezedClass(node) || _isSealedClass(node)) {
      return violations;
    }

    for (final member in node.members) {
      if (member is FieldDeclaration) {
        final fields = member.fields;

        // Check for non-final fields
        if (!fields.isFinal && !fields.isConst) {
          violations.add(EntityViolation(
            type: ViolationType.immutability,
            message: 'Entity contains mutable field',
            suggestion: 'Make all fields final for immutability',
            node: member,
          ));
        }

        // Check for mutable collection types
        final type = fields.type;
        if (type is NamedType && fields.isFinal) {
          final typeName = type.name2.lexeme;
          if (_isMutableCollectionType(typeName)) {
            violations.add(EntityViolation(
              type: ViolationType.immutability,
              message: 'Entity uses mutable collection type: $typeName',
              suggestion: 'Use immutable collections (e.g., UnmodifiableListView)',
              node: type,
            ));
          }
        }
      } else if (member is MethodDeclaration) {
        // Check for setters
        if (member.isSetter) {
          violations.add(EntityViolation(
            type: ViolationType.immutability,
            message: 'Entity contains setter method',
            suggestion: 'Remove setter, use copyWith() pattern instead',
            node: member,
          ));
        }

        // Check for mutating methods
        final methodName = member.name.lexeme;
        if (_isMutatingMethodName(methodName) && !member.isStatic) {
          violations.add(EntityViolation(
            type: ViolationType.immutability,
            message: 'Method suggests state mutation: $methodName',
            suggestion: 'Return new instance instead of mutating state',
            node: member,
          ));
        }
      }
    }

    return violations;
  }

  List<EntityViolation> _checkBusinessRulesPurity(ClassDeclaration node) {
    final violations = <EntityViolation>[];
    // final className = node.name.lexeme; // Will use when needed

    for (final member in node.members) {
      if (member is MethodDeclaration) {
        final methodName = member.name.lexeme;

        // Check for application-specific methods
        if (_isApplicationSpecificMethod(methodName)) {
          violations.add(EntityViolation(
            type: ViolationType.businessRules,
            message: 'Application-specific method in entity: $methodName',
            suggestion: 'Move application logic to use cases or services',
            node: member,
          ));
        }

        // Check for infrastructure methods
        if (_isInfrastructureMethod(methodName)) {
          violations.add(EntityViolation(
            type: ViolationType.businessRules,
            message: 'Infrastructure concern in entity: $methodName',
            suggestion: 'Use repository abstractions instead',
            node: member,
          ));
        }

        // Check for UI methods
        if (_isUIMethod(methodName)) {
          violations.add(EntityViolation(
            type: ViolationType.businessRules,
            message: 'UI concern in entity: $methodName',
            suggestion: 'Move UI logic to presentation layer',
            node: member,
          ));
        }
      } else if (member is FieldDeclaration) {
        final type = member.fields.type;
        if (type is NamedType) {
          final typeName = type.name2.lexeme;

          // Check for non-domain types
          if (_isInfrastructureType(typeName) || _isApplicationSpecificType(typeName)) {
            violations.add(EntityViolation(
              type: ViolationType.businessRules,
              message: 'Non-domain type in entity: $typeName',
              suggestion: 'Use domain-specific types only',
              node: type,
            ));
          }
        }
      }
    }

    return violations;
  }

  List<EntityViolation> _checkStability(ClassDeclaration node) {
    final violations = <EntityViolation>[];
    final className = node.name.lexeme;

    // Check class naming for technology-specific terms
    if (_isTechnologySpecificClassName(className)) {
      violations.add(EntityViolation(
        type: ViolationType.stability,
        message: 'Technology-specific entity name: $className',
        suggestion: 'Use domain-specific names independent of technology',
        node: node,
      ));
    }

    for (final member in node.members) {
      if (member is MethodDeclaration) {
        final methodName = member.name.lexeme;

        // Check for operational concerns
        if (_isOperationalMethod(methodName)) {
          violations.add(EntityViolation(
            type: ViolationType.stability,
            message: 'Operational concern in entity: $methodName',
            suggestion: 'Remove operational concerns from entity',
            node: member,
          ));
        }

        // Check for volatile business rules
        if (_isVolatileBusinessRule(methodName)) {
          violations.add(EntityViolation(
            type: ViolationType.stability,
            message: 'Potentially volatile business rule: $methodName',
            suggestion: 'Consider if this is stable or should be in use case',
            node: member,
          ));
        }
      }
    }

    return violations;
  }

  EntityViolation? _checkImportViolation(String importUri) {
    // UI framework imports
    final uiFrameworks = ['package:flutter/', 'dart:ui', 'dart:html'];
    for (final framework in uiFrameworks) {
      if (importUri.startsWith(framework)) {
        return EntityViolation(
          type: ViolationType.stability,
          message: 'Entity imports UI framework: $importUri',
          suggestion: 'Remove UI dependencies from entity',
        );
      }
    }

    // Infrastructure imports
    final infraLibs = ['package:http/', 'package:dio/', 'package:sqflite/', 'package:shared_preferences/', 'dart:io'];
    for (final lib in infraLibs) {
      if (importUri.startsWith(lib)) {
        return EntityViolation(
          type: ViolationType.businessRules,
          message: 'Entity imports infrastructure: $importUri',
          suggestion: 'Use domain abstractions instead',
        );
      }
    }

    return null;
  }

  LintCode _createLintCode(EntityViolation violation) {
    final severityPrefix = severity.messagePrefix;
    return LintCode(
      name: 'consolidated_entity_rule',
      problemMessage: '$severityPrefix${violation.message}',
      correctionMessage: violation.suggestion,
    );
  }

  // Helper methods
  bool _isFreezedClass(ClassDeclaration node) {
    // Check for @freezed annotation
    for (final metadata in node.metadata) {
      if (metadata.name.name == 'freezed') return true;
    }
    return false;
  }

  bool _isSealedClass(ClassDeclaration node) {
    // Check if class is declared as sealed
    return node.sealedKeyword != null;
  }

  bool _isMutableCollectionType(String typeName) {
    return typeName == 'List' || typeName == 'Map' || typeName == 'Set';
  }

  bool _isMutatingMethodName(String methodName) {
    final mutatingPatterns = ['set', 'update', 'modify', 'change', 'add', 'remove', 'delete', 'clear'];
    final lower = methodName.toLowerCase();
    return mutatingPatterns.any((pattern) => lower.startsWith(pattern));
  }

  bool _isApplicationSpecificMethod(String methodName) {
    final patterns = ['navigate', 'route', 'login', 'authenticate', 'cache', 'sync'];
    final lower = methodName.toLowerCase();
    return patterns.any((pattern) => lower.contains(pattern));
  }

  bool _isInfrastructureMethod(String methodName) {
    final patterns = ['database', 'query', 'http', 'api', 'file', 'serialize'];
    final lower = methodName.toLowerCase();
    return patterns.any((pattern) => lower.contains(pattern));
  }

  bool _isUIMethod(String methodName) {
    final patterns = ['render', 'draw', 'widget', 'click', 'tap', 'animation'];
    final lower = methodName.toLowerCase();
    return patterns.any((pattern) => lower.contains(pattern));
  }

  bool _isInfrastructureType(String typeName) {
    return typeName.contains('Database') || typeName.contains('HttpClient') || typeName.contains('Storage');
  }

  bool _isApplicationSpecificType(String typeName) {
    return typeName.contains('Controller') || typeName.contains('Service') || typeName.contains('Manager');
  }

  bool _isTechnologySpecificClassName(String className) {
    final techPatterns = ['SQL', 'Json', 'XML', 'HTTP', 'REST'];
    return techPatterns.any((pattern) => className.contains(pattern));
  }

  bool _isOperationalMethod(String methodName) {
    final patterns = ['log', 'monitor', 'trace', 'metric', 'telemetry'];
    final lower = methodName.toLowerCase();
    return patterns.any((pattern) => lower.contains(pattern));
  }

  bool _isVolatileBusinessRule(String methodName) {
    final patterns = ['campaign', 'promotion', 'discount', 'seasonal'];
    final lower = methodName.toLowerCase();
    return patterns.any((pattern) => lower.contains(pattern));
  }
}

class EntityViolation {
  final ViolationType type;
  final String message;
  final String suggestion;
  final AstNode? node;

  const EntityViolation({
    required this.type,
    required this.message,
    required this.suggestion,
    this.node,
  });
}

enum ViolationType {
  immutability,
  businessRules,
  stability,
}
