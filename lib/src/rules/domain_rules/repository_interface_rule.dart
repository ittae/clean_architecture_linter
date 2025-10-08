import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../clean_architecture_linter_base.dart';
import '../../mixins/repository_rule_visitor.dart';

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
class RepositoryInterfaceRule extends CleanArchitectureLintRule
    with RepositoryRuleVisitor {
  const RepositoryInterfaceRule() : super(code: _code);

  static const _code = LintCode(
    name: 'repository_interface',
    problemMessage:
        'Domain layer must depend only on repository abstractions, not concrete implementations.',
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
    if (!CleanArchitectureUtils.isDomainFile(filePath)) return;

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
    if (!CleanArchitectureUtils.isDomainFile(filePath)) return;

    final className = node.name.lexeme;
    if (!className.contains('Repository')) return;

    // Check if repository interface is properly abstract
    if (!isRepositoryInterface(node)) {
      // This is a concrete repository in domain layer - should be abstract
      final code = LintCode(
        name: 'repository_interface',
        problemMessage:
            'Repository in domain layer should be abstract: $className',
        correctionMessage:
            'Make repository abstract or move implementation to data layer.',
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
    if (!CleanArchitectureUtils.isDomainFile(filePath)) return;

    // Check constructor parameters for repository types
    final parameters = node.parameters.parameters;
    for (final param in parameters) {
      if (param is SimpleFormalParameter) {
        final type = param.type;
        if (type is NamedType) {
          final typeName = type.name2.lexeme;
          if (CleanArchitectureUtils.isRepositoryImplClass(typeName)) {
            final code = LintCode(
              name: 'repository_interface',
              problemMessage:
                  'Constructor depends on concrete repository implementation: $typeName',
              correctionMessage:
                  'Use abstract repository interface instead of concrete implementation.',
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
    if (!CleanArchitectureUtils.isDomainFile(filePath)) return;

    final type = node.fields.type;
    if (type is NamedType) {
      final typeName = type.name2.lexeme;
      if (CleanArchitectureUtils.isRepositoryImplClass(typeName)) {
        final code = LintCode(
          name: 'repository_interface',
          problemMessage:
              'Field depends on concrete repository implementation: $typeName',
          correctionMessage:
              'Use abstract repository interface instead of concrete implementation.',
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
    final returnType = method.returnType;

    // Check if repository method returns domain entities (not data models)
    _checkReturnTypeForModels(returnType, reporter);

    // Check method parameters for data layer models
    _checkMethodParametersForModels(method, reporter);
  }

  /// Checks if return type contains data layer models (including nested generics)
  void _checkReturnTypeForModels(
    TypeAnnotation? returnType,
    ErrorReporter reporter,
  ) {
    if (returnType == null) return;

    if (returnType is NamedType) {
      final returnTypeName = returnType.name2.lexeme;

      // Check the main type
      if (_isDataLayerModel(returnTypeName)) {
        final code = LintCode(
          name: 'repository_interface',
          problemMessage:
              'Repository method returns data layer model: $returnTypeName',
          correctionMessage:
              'Repository methods should return domain entities, not data models.',
        );
        reporter.atNode(returnType, code);
        return; // Don't check further if main type is already a model
      }

      // Check generic type arguments (e.g., Result<UserModel, Failure>)
      final typeArguments = returnType.typeArguments?.arguments;
      if (typeArguments != null) {
        for (final typeArg in typeArguments) {
          if (typeArg is NamedType) {
            final typeArgName = typeArg.name2.lexeme;
            if (_isDataLayerModel(typeArgName)) {
              final code = LintCode(
                name: 'repository_interface',
                problemMessage:
                    'Repository method uses data layer model in generic type: $typeArgName',
                correctionMessage:
                    'Use domain entities in generic types. Example: Result<User, Failure> instead of Result<UserModel, Failure>',
              );
              reporter.atNode(typeArg, code);
            }
          }
        }
      }
    }
  }

  /// Checks if method parameters contain data layer models
  void _checkMethodParametersForModels(
    MethodDeclaration method,
    ErrorReporter reporter,
  ) {
    final parameters = method.parameters;
    if (parameters == null) return;

    for (final param in parameters.parameters) {
      TypeAnnotation? paramType;

      if (param is SimpleFormalParameter) {
        paramType = param.type;
      } else if (param is DefaultFormalParameter) {
        final innerParam = param.parameter;
        if (innerParam is SimpleFormalParameter) {
          paramType = innerParam.type;
        }
      }

      if (paramType is NamedType) {
        final paramTypeName = paramType.name2.lexeme;
        if (_isDataLayerModel(paramTypeName)) {
          final code = LintCode(
            name: 'repository_interface',
            problemMessage:
                'Repository method parameter uses data layer model: $paramTypeName',
            correctionMessage:
                'Repository method parameters should use domain entities, not data models.',
          );
          reporter.atNode(paramType, code);
        }

        // Check generic type arguments in parameters (e.g., List<UserModel>)
        final typeArguments = paramType.typeArguments?.arguments;
        if (typeArguments != null) {
          for (final typeArg in typeArguments) {
            if (typeArg is NamedType) {
              final typeArgName = typeArg.name2.lexeme;
              if (_isDataLayerModel(typeArgName)) {
                final code = LintCode(
                  name: 'repository_interface',
                  problemMessage:
                      'Repository parameter uses data layer model in generic type: $typeArgName',
                  correctionMessage:
                      'Use domain entities in generic types. Example: List<User> instead of List<UserModel>',
                );
                reporter.atNode(typeArg, code);
              }
            }
          }
        }
      }
    }
  }

  RepositoryViolation? _analyzeRepositoryImport(String importUri) {
    // Check for data layer repository implementations
    if ((importUri.contains('/data/') || importUri.contains('\\data\\')) &&
        (importUri.contains('repository') ||
            importUri.contains('Repository'))) {
      if (importUri.contains('impl') || importUri.contains('Impl')) {
        return RepositoryViolation(
          message:
              'Importing concrete repository implementation from data layer',
          suggestion:
              'Import only abstract repository interfaces. Move concrete implementations to data layer.',
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
          message:
              'Direct infrastructure dependency detected in domain repository',
          suggestion:
              'Use repository abstractions instead of direct infrastructure dependencies.',
        );
      }
    }

    return null;
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
