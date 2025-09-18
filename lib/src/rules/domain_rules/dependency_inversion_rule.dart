import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Enforces Dependency Inversion Principle in the domain layer.
///
/// This rule ensures that domain layer classes depend only on abstractions:
/// - Domain classes should depend on interfaces/abstractions, not concrete implementations
/// - No direct dependencies on infrastructure or framework classes
/// - Proper abstraction layer between domain and external concerns
/// - Constructor injection should use abstract types
/// - Field declarations should reference abstractions
///
/// Benefits of proper dependency inversion:
/// - Testability through dependency injection
/// - Flexibility to change implementations
/// - Reduced coupling between layers
/// - Better adherence to SOLID principles
/// - Easier mocking and unit testing
class DependencyInversionRule extends DartLintRule {
  const DependencyInversionRule() : super(code: _code);

  static const _code = LintCode(
    name: 'dependency_inversion',
    problemMessage: 'Domain layer must depend on abstractions, not concrete implementations.',
    correctionMessage: 'Use abstract interfaces or base classes instead of concrete implementations to follow DIP.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Check constructor parameters for concrete dependencies
    context.registry.addConstructorDeclaration((node) {
      _checkConstructorDependencies(node, reporter, resolver);
    });

    // Check field declarations for concrete types
    context.registry.addFieldDeclaration((node) {
      _checkFieldDependencies(node, reporter, resolver);
    });

    // Check import statements for inappropriate direct dependencies
    context.registry.addImportDirective((node) {
      _checkImportDependencies(node, reporter, resolver);
    });

    // Check class inheritance for concrete base classes
    context.registry.addClassDeclaration((node) {
      _checkInheritanceDependencies(node, reporter, resolver);
    });
  }

  void _checkConstructorDependencies(
    ConstructorDeclaration node,
    DiagnosticReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    if (!_isDomainLayerFile(filePath)) return;

    final analysis = _analyzeDependencyTypes(node.parameters.parameters);

    for (final violation in analysis.violations) {
      final enhancedCode = LintCode(
        name: 'dependency_inversion',
        problemMessage: violation.message,
        correctionMessage: violation.suggestion,
      );
      reporter.atNode(violation.node!, enhancedCode);
    }
  }

  void _checkFieldDependencies(
    FieldDeclaration node,
    DiagnosticReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    if (!_isDomainLayerFile(filePath)) return;

    final type = node.fields.type;
    if (type is NamedType) {
      final violation = _analyzeFieldDependency(type, node);
      if (violation != null) {
        final enhancedCode = LintCode(
          name: 'dependency_inversion',
          problemMessage: violation.message,
          correctionMessage: violation.suggestion,
        );
        reporter.atNode(type, enhancedCode);
      }
    }
  }

  void _checkImportDependencies(
    ImportDirective node,
    DiagnosticReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    if (!_isDomainLayerFile(filePath)) return;

    final importUri = node.uri.stringValue;
    if (importUri == null) return;

    final violation = _analyzeImportDependency(importUri);
    if (violation != null) {
      final enhancedCode = LintCode(
        name: 'dependency_inversion',
        problemMessage: violation.message,
        correctionMessage: violation.suggestion,
      );
      reporter.atNode(node, enhancedCode);
    }
  }

  void _checkInheritanceDependencies(
    ClassDeclaration node,
    DiagnosticReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    if (!_isDomainLayerFile(filePath)) return;

    // Check superclass
    final superclass = node.extendsClause?.superclass;
    if (superclass is NamedType) {
      final violation = _analyzeInheritanceDependency(superclass, 'extends');
      if (violation != null) {
        final enhancedCode = LintCode(
          name: 'dependency_inversion',
          problemMessage: violation.message,
          correctionMessage: violation.suggestion,
        );
        reporter.atNode(superclass, enhancedCode);
      }
    }

    // Check implemented interfaces
    final interfaces = node.implementsClause?.interfaces;
    if (interfaces != null) {
      for (final interface in interfaces) {
        final violation = _analyzeInheritanceDependency(interface, 'implements');
        if (violation != null) {
          final enhancedCode = LintCode(
            name: 'dependency_inversion',
            problemMessage: violation.message,
            correctionMessage: violation.suggestion,
          );
          reporter.atNode(interface, enhancedCode);
        }
      }
    }

    // Check mixins
    final mixins = node.withClause?.mixinTypes;
    if (mixins != null) {
      for (final mixin in mixins) {
        final violation = _analyzeInheritanceDependency(mixin, 'mixes');
        if (violation != null) {
          final enhancedCode = LintCode(
            name: 'dependency_inversion',
            problemMessage: violation.message,
            correctionMessage: violation.suggestion,
          );
          reporter.atNode(mixin, enhancedCode);
        }
      }
    }
  }

  DependencyAnalysis _analyzeDependencyTypes(List<FormalParameter> parameters) {
    final violations = <DependencyViolation>[];

    for (final param in parameters) {
      if (param is SimpleFormalParameter) {
        final type = param.type;
        if (type is NamedType) {
          final violation = _checkParameterDependency(type, param);
          if (violation != null) {
            violations.add(violation);
          }
        }
      }
    }

    return DependencyAnalysis(violations: violations);
  }

  DependencyViolation? _checkParameterDependency(NamedType type, FormalParameter param) {
    final typeName = type.name.lexeme;

    // Check for concrete implementation patterns
    if (_isConcreteImplementation(typeName)) {
      return DependencyViolation(
        node: param,
        message: 'Constructor parameter depends on concrete implementation: $typeName',
        suggestion: 'Use abstract interface or base class instead of concrete implementation.',
      );
    }

    // Check for infrastructure dependencies
    if (_isInfrastructureDependency(typeName)) {
      return DependencyViolation(
        node: param,
        message: 'Domain layer directly depends on infrastructure: $typeName',
        suggestion: 'Create domain interface and inject through dependency inversion.',
      );
    }

    // Check for framework dependencies
    if (_isFrameworkDependency(typeName)) {
      return DependencyViolation(
        node: param,
        message: 'Domain layer depends on external framework: $typeName',
        suggestion: 'Abstract framework dependency behind domain interface.',
      );
    }

    return null;
  }

  DependencyViolation? _analyzeFieldDependency(NamedType type, FieldDeclaration field) {
    final typeName = type.name.lexeme;

    if (_isConcreteImplementation(typeName)) {
      return DependencyViolation(
        node: field,
        message: 'Field depends on concrete implementation: $typeName',
        suggestion: 'Use abstract type for field declaration.',
      );
    }

    if (_isInfrastructureDependency(typeName)) {
      return DependencyViolation(
        node: field,
        message: 'Domain field directly references infrastructure: $typeName',
        suggestion: 'Create domain abstraction for infrastructure dependency.',
      );
    }

    return null;
  }

  DependencyViolation? _analyzeImportDependency(String importUri) {
    // Check for direct infrastructure imports
    final infraPatterns = [
      'package:sqflite',
      'package:shared_preferences',
      'package:cloud_firestore',
      'package:firebase_',
      'package:http',
      'package:dio',
    ];

    for (final pattern in infraPatterns) {
      if (importUri.startsWith(pattern)) {
        return DependencyViolation(
          node: null, // Will be set by caller
          message: 'Direct infrastructure import in domain layer: $importUri',
          suggestion: 'Create domain abstraction and move infrastructure to data layer.',
        );
      }
    }

    // Check for data layer imports
    if ((importUri.contains('/data/') || importUri.contains('\\data\\')) &&
        !importUri.contains('/domain/') && !importUri.contains('\\domain\\')) {
      return DependencyViolation(
        node: null,
        message: 'Domain layer importing from data layer: $importUri',
        suggestion: 'Domain should not depend on data layer. Use dependency inversion.',
      );
    }

    // Check for presentation layer imports
    if (importUri.contains('/presentation/') || importUri.contains('\\presentation\\')) {
      return DependencyViolation(
        node: null,
        message: 'Domain layer importing from presentation layer: $importUri',
        suggestion: 'Domain should not depend on presentation layer.',
      );
    }

    return null;
  }

  DependencyViolation? _analyzeInheritanceDependency(NamedType type, String relationship) {
    final typeName = type.name.lexeme;

    if (_isConcreteImplementation(typeName)) {
      return DependencyViolation(
        node: type,
        message: 'Domain class $relationship concrete implementation: $typeName',
        suggestion: 'Use abstract base class or interface for inheritance.',
      );
    }

    if (_isFrameworkDependency(typeName)) {
      return DependencyViolation(
        node: type,
        message: 'Domain class $relationship framework type: $typeName',
        suggestion: 'Create domain abstraction instead of depending on framework.',
      );
    }

    return null;
  }

  bool _isConcreteImplementation(String typeName) {
    final concretePatterns = [
      'Impl', 'Implementation', 'Concrete',
      'Service', 'Manager', 'Handler', 'Provider',
      'Client', 'Adapter', 'Gateway'
    ];
    return concretePatterns.any((pattern) => typeName.endsWith(pattern));
  }

  bool _isInfrastructureDependency(String typeName) {
    final infraTypes = [
      'Database', 'SqlDatabase', 'NoSqlDatabase',
      'FileSystem', 'Storage', 'Cache',
      'SharedPreferences', 'SecureStorage',
      'FirebaseFirestore', 'FirebaseAuth',
      'NetworkClient', 'ApiClient',
    ];
    return infraTypes.contains(typeName);
  }

  bool _isFrameworkDependency(String typeName) {
    final frameworkTypes = [
      'HttpClient', 'Client', 'RestClient',
      'Widget', 'StatefulWidget', 'StatelessWidget',
      'BuildContext', 'Navigator',
      'StreamController', 'AnimationController',
    ];
    return frameworkTypes.contains(typeName);
  }

  bool _isDomainLayerFile(String filePath) {
    return filePath.contains('/domain/') ||
           filePath.contains('\\domain\\');
  }
}

/// Analysis result for dependency inversion violations
class DependencyAnalysis {
  final List<DependencyViolation> violations;

  const DependencyAnalysis({
    required this.violations,
  });
}

/// Represents a dependency inversion violation
class DependencyViolation {
  final AstNode? node;
  final String message;
  final String suggestion;

  const DependencyViolation({
    required this.node,
    required this.message,
    required this.suggestion,
  });
}