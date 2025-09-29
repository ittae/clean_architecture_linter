import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../clean_architecture_linter_base.dart';

/// Enforces proper repository abstraction patterns in domain layer.
///
/// This rule ensures that the domain layer follows the Repository pattern correctly:
/// - Domain should only depend on abstract repository interfaces
/// - No direct dependencies on data layer implementations
/// - Repository interfaces should follow proper naming conventions
/// - Repository methods should return domain entities, not data models
///
/// Benefits of proper repository abstraction:
/// - Testability through mock implementations
/// - Independence from data layer changes
/// - Clear contract definition
/// - Supports multiple data source strategies
class RepositoryInterfaceRule extends CleanArchitectureLintRule {
  const RepositoryInterfaceRule() : super(code: _code);

  static const _code = LintCode(
    name: 'repository_interface',
    problemMessage: 'Domain layer must depend only on repository abstractions, not concrete implementations.',
    correctionMessage:
        'Use abstract repository interfaces and ensure proper separation between domain and data layers.',
  );

  @override
  void runRule(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    // Check import statements for data layer repository implementations
    context.registry.addImportDirective((node) {
      _checkRepositoryImports(node, reporter, resolver);
    });

    // Check class declarations for proper repository interface patterns
    context.registry.addClassDeclaration((node) {
      _checkRepositoryInterface(node, reporter, resolver);
    });

    // Check constructor parameters for repository dependencies
    context.registry.addConstructorDeclaration((node) {
      _checkRepositoryDependencies(node, reporter, resolver);
    });

    // Check field declarations for repository field types
    context.registry.addFieldDeclaration((node) {
      _checkRepositoryFields(node, reporter, resolver);
    });
  }

  void _checkRepositoryImports(
    ImportDirective node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;

    // Only check files in domain layer
    if (!CleanArchitectureUtils.isDomainLayerFile(filePath)) return;

    final importUri = node.uri.stringValue;
    if (importUri == null) return;

    // Check if importing from data layer repository implementations
    final violation = _analyzeRepositoryImport(importUri);
    if (violation != null) {
      final enhancedCode = LintCode(
        name: 'repository_interface',
        problemMessage: violation.message,
        correctionMessage: violation.suggestion,
      );
      reporter.atNode(node, enhancedCode);
    }
  }

  void _checkRepositoryInterface(
    ClassDeclaration node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    if (!CleanArchitectureUtils.isDomainLayerFile(filePath)) return;

    final className = node.name.lexeme;
    if (!_isRepositoryClass(className)) return;

    // Check if repository interface is properly abstract
    if (node.abstractKeyword == null) {
      // This is a concrete repository in domain layer - should be abstract
      final code = LintCode(
        name: 'repository_interface',
        problemMessage: 'Repository in domain layer should be abstract: $className',
        correctionMessage: 'Make repository abstract or move implementation to data layer.',
      );
      reporter.atNode(node, code);
    }

    // Check repository method signatures
    for (final member in node.members) {
      if (member is MethodDeclaration) {
        _checkRepositoryMethod(member, reporter, className);
      }
    }
  }

  void _checkRepositoryDependencies(
    ConstructorDeclaration node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    if (!CleanArchitectureUtils.isDomainLayerFile(filePath)) return;

    // Check constructor parameters for repository types
    final parameters = node.parameters.parameters;
    for (final param in parameters) {
      if (param is SimpleFormalParameter) {
        final type = param.type;
        if (type is NamedType) {
          final typeName = type.name2.lexeme;
          if (_isConcreteRepositoryType(typeName)) {
            final code = LintCode(
              name: 'repository_interface',
              problemMessage: 'Constructor depends on concrete repository implementation: $typeName',
              correctionMessage: 'Use abstract repository interface instead of concrete implementation.',
            );
            reporter.atNode(type, code);
          }
        }
      }
    }
  }

  void _checkRepositoryFields(
    FieldDeclaration node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    if (!CleanArchitectureUtils.isDomainLayerFile(filePath)) return;

    final type = node.fields.type;
    if (type is NamedType) {
      final typeName = type.name2.lexeme;
      if (_isConcreteRepositoryType(typeName)) {
        final code = LintCode(
          name: 'repository_interface',
          problemMessage: 'Field depends on concrete repository implementation: $typeName',
          correctionMessage: 'Use abstract repository interface instead of concrete implementation.',
        );
        reporter.atNode(type, code);
      }
    }
  }

  void _checkRepositoryMethod(
    MethodDeclaration method,
    ErrorReporter reporter,
    String className,
  ) {
    final methodName = method.name.lexeme;
    final returnType = method.returnType;

    // Check if repository method returns domain entities (not data models)
    if (returnType is NamedType) {
      final returnTypeName = returnType.name2.lexeme;
      if (_isDataLayerModel(returnTypeName)) {
        final code = LintCode(
          name: 'repository_interface',
          problemMessage: 'Repository method returns data layer model: $returnTypeName',
          correctionMessage: 'Repository methods should return domain entities, not data models.',
        );
        reporter.atNode(returnType, code);
      }
    }

    // Method names are domain-specific and should not be enforced by linter
  }

  RepositoryViolation? _analyzeRepositoryImport(String importUri) {
    // Check for data layer repository implementations
    if ((importUri.contains('/data/') || importUri.contains('\\data\\')) &&
        (importUri.contains('repository') || importUri.contains('Repository'))) {
      if (importUri.contains('impl') || importUri.contains('Impl')) {
        return RepositoryViolation(
          message: 'Importing concrete repository implementation from data layer',
          suggestion: 'Import only abstract repository interfaces. Move concrete implementations to data layer.',
        );
      }
    }

    // Check for infrastructure repository imports
    final infraPatterns = [
      'package:sqflite',
      'package:hive',
      'package:shared_preferences',
      'package:cloud_firestore',
    ];

    for (final pattern in infraPatterns) {
      if (importUri.startsWith(pattern)) {
        return RepositoryViolation(
          message: 'Direct infrastructure dependency detected in domain repository',
          suggestion: 'Use repository abstractions instead of direct infrastructure dependencies.',
        );
      }
    }

    return null;
  }


  bool _isRepositoryClass(String className) {
    return className.endsWith('Repository') || className.contains('Repository');
  }

  bool _isConcreteRepositoryType(String typeName) {
    return typeName.endsWith('RepositoryImpl') ||
        typeName.endsWith('RepositoryImplementation') ||
        (typeName.contains('Repository') && typeName.contains('Impl'));
  }

  bool _isDataLayerModel(String typeName) {
    return typeName.endsWith('Model') ||
        typeName.endsWith('Dto') ||
        typeName.endsWith('Response') ||
        typeName.endsWith('Entity') && typeName.contains('Data');
  }

}

/// Represents a repository interface violation
class RepositoryViolation {
  final String message;
  final String suggestion;

  const RepositoryViolation({required this.message, required this.suggestion});
}
