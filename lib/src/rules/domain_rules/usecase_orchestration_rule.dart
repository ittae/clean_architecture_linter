import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../clean_architecture_linter_base.dart';

/// Enforces proper orchestration pattern in Use Cases.
///
/// This rule ensures that Use Cases follow Clean Architecture principles:
/// - Orchestrate the flow of data to and from entities
/// - Direct entities to use their enterprise-wide business rules
/// - Focus on achieving the goals of the specific use case
/// - Coordinate between entities and external boundaries (repositories)
/// - Contain application-specific business rules, not enterprise rules
///
/// Use Cases should:
/// - Accept input data and convert it to entity operations
/// - Coordinate multiple entities if needed
/// - Apply application-specific business rules
/// - Return output data in a form suitable for the delivery mechanism
class UseCaseOrchestrationRule extends CleanArchitectureLintRule {
  const UseCaseOrchestrationRule() : super(code: _code);

  static const _code = LintCode(
    name: 'usecase_orchestration',
    problemMessage: 'Use Case must properly orchestrate entities and focus on application-specific business rules.',
    correctionMessage:
        'Ensure Use Case orchestrates entities, uses repositories, and contains only application-specific logic.',
  );

  @override
  void runRule(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((node) {
      _checkUseCaseOrchestration(node, reporter, resolver);
    });

    context.registry.addMethodDeclaration((node) {
      _checkUseCaseMethod(node, reporter, resolver);
    });
  }

  void _checkUseCaseOrchestration(
    ClassDeclaration node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    if (!_isUseCaseFile(filePath)) return;

    final analysis = _analyzeUseCaseStructure(node);

    // Check for proper dependency injection pattern
    _checkDependencyPattern(analysis, reporter, node);

    // Check for orchestration responsibilities
    _checkOrchestrationPattern(analysis, reporter, node);

    // Check that it's not doing entity work
    _checkEntityWorkSeparation(analysis, reporter, node);
  }

  void _checkUseCaseMethod(
    MethodDeclaration method,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    if (!_isUseCaseFile(filePath)) return;

    final methodName = method.name.lexeme;
    if (methodName != 'execute' && methodName != 'call') return;

    // Check method body for orchestration patterns
    final body = method.body;
    if (body is BlockFunctionBody) {
      _checkMethodOrchestration(body, reporter, method);
    }
  }

  void _checkDependencyPattern(
    UseCaseStructureAnalysis analysis,
    ErrorReporter reporter,
    ClassDeclaration node,
  ) {
    // Check for repository dependencies (good)
    final hasRepositories = analysis.dependencies.any(
      (dep) => _isRepositoryDependency(dep),
    );

    // Check for entity dependencies in constructor (usually bad)
    final hasEntityDependencies = analysis.dependencies.any(
      (dep) => _isEntityDependency(dep),
    );

    if (hasEntityDependencies) {
      final code = LintCode(
        name: 'usecase_orchestration',
        problemMessage: 'Use Case should not inject entities as dependencies',
        correctionMessage:
            'Use Cases should create or receive entities through repositories, not inject them directly.',
      );
      reporter.atNode(node, code);
    }

    // Check for infrastructure dependencies (bad)
    final hasInfrastructureDependencies = analysis.dependencies.any(
      (dep) => _isInfrastructureDependency(dep),
    );

    if (hasInfrastructureDependencies) {
      final code = LintCode(
        name: 'usecase_orchestration',
        problemMessage: 'Use Case should not depend directly on infrastructure',
        correctionMessage: 'Use repository abstractions instead of direct infrastructure dependencies.',
      );
      reporter.atNode(node, code);
    }

    // Suggest repository if none found and class has dependencies
    if (!hasRepositories && analysis.dependencies.isNotEmpty) {
      final code = LintCode(
        name: 'usecase_orchestration',
        problemMessage: 'Use Case may need repository dependencies for data access',
        correctionMessage: 'Consider using repository abstractions to access and manipulate entities.',
      );
      reporter.atNode(node, code);
    }
  }

  void _checkOrchestrationPattern(
    UseCaseStructureAnalysis analysis,
    ErrorReporter reporter,
    ClassDeclaration node,
  ) {
    final executeMethods = analysis.methods.where(
      (method) => method.name.lexeme == 'execute' || method.name.lexeme == 'call',
    );

    for (final method in executeMethods) {
      // Check return type suggests orchestration output
      if (!_hasProperReturnType(method)) {
        final code = LintCode(
          name: 'usecase_orchestration',
          problemMessage: 'Use Case should return meaningful result or void',
          correctionMessage:
              'Use Case should return the result of the operation (entity, success indicator, or output data).',
        );
        reporter.atNode(method, code);
      }

      // Check parameters suggest input coordination
      if (!_hasProperParameters(method)) {
        final code = LintCode(
          name: 'usecase_orchestration',
          problemMessage: 'Use Case should accept input parameters for the operation',
          correctionMessage: 'Use Case execute/call method should accept the data needed to perform the operation.',
        );
        reporter.atNode(method, code);
      }
    }
  }

  void _checkEntityWorkSeparation(
    UseCaseStructureAnalysis analysis,
    ErrorReporter reporter,
    ClassDeclaration node,
  ) {
    // Check if Use Case is doing work that should be in entities
    for (final method in analysis.methods) {
      final methodName = method.name.lexeme;

      if (_isEntityLevelWork(methodName)) {
        final code = LintCode(
          name: 'usecase_orchestration',
          problemMessage: 'Method "$methodName" suggests entity-level work in Use Case',
          correctionMessage:
              'Move entity-specific business rules to the entity class. Use Case should orchestrate, not implement business rules.',
        );
        reporter.atNode(method, code);
      }
    }
  }

  void _checkMethodOrchestration(
    BlockFunctionBody body,
    ErrorReporter reporter,
    MethodDeclaration method,
  ) {
    final bodyString = body.toString();

    // Check for direct database/infrastructure calls (anti-pattern)
    final directInfraCalls = [
      '.save(',
      '.insert(',
      '.update(',
      '.delete(',
      '.query(',
      '.find(',
      '.get(',
      '.post(',
      'database.',
      'db.',
      'http.',
      'api.',
    ];

    for (final call in directInfraCalls) {
      if (bodyString.contains(call)) {
        final code = LintCode(
          name: 'usecase_orchestration',
          problemMessage: 'Use Case contains direct infrastructure calls',
          correctionMessage: 'Use repository abstractions instead of direct infrastructure calls.',
        );
        reporter.atNode(body, code);
        break;
      }
    }

    // Check for entity creation patterns (good)
    final entityPatterns = ['new ', 'Entity(', '.create('];
    final hasEntityCreation = entityPatterns.any((pattern) => bodyString.contains(pattern));

    // Check for repository usage patterns (good)
    final repositoryPatterns = ['repository.', 'Repository', '.getBy', '.findBy'];
    final hasRepositoryUsage = repositoryPatterns.any((pattern) => bodyString.contains(pattern));

    // If it's a complex use case but has neither entity creation nor repository usage
    if (bodyString.length > 200 && !hasEntityCreation && !hasRepositoryUsage) {
      final code = LintCode(
        name: 'usecase_orchestration',
        problemMessage: 'Complex Use Case should orchestrate entities or use repositories',
        correctionMessage: 'Use Case should create/manipulate entities or coordinate with repositories.',
      );
      reporter.atNode(method, code);
    }
  }

  UseCaseStructureAnalysis _analyzeUseCaseStructure(ClassDeclaration node) {
    final methods = <MethodDeclaration>[];
    final dependencies = <String>[];

    for (final member in node.members) {
      if (member is MethodDeclaration && !member.isStatic) {
        methods.add(member);
      } else if (member is FieldDeclaration && member.fields.isFinal) {
        // Extract dependency types
        final type = member.fields.type;
        if (type is NamedType) {
          dependencies.add(type.name2.lexeme);
        }
      }
    }

    return UseCaseStructureAnalysis(
      methods: methods,
      dependencies: dependencies,
    );
  }

  bool _isRepositoryDependency(String typeName) {
    return typeName.contains('Repository') || typeName.contains('DataSource') || typeName.endsWith('Gateway');
  }

  bool _isEntityDependency(String typeName) {
    return typeName.endsWith('Entity') || typeName.endsWith('Model') || typeName.endsWith('Domain');
  }

  bool _isInfrastructureDependency(String typeName) {
    final infraTypes = [
      'Database',
      'Cache',
      'HttpClient',
      'ApiClient',
      'FileSystem',
      'Storage',
      'NetworkClient',
      'SqlDatabase',
      'NoSqlDatabase',
      'RestClient',
    ];
    return infraTypes.any((type) => typeName.contains(type));
  }

  bool _hasProperReturnType(MethodDeclaration method) {
    final returnType = method.returnType;
    if (returnType == null) return true; // Dynamic is acceptable

    if (returnType is NamedType) {
      final typeName = returnType.name2.lexeme;
      // Void, Future, entities, or result types are good
      return typeName == 'void' ||
          typeName == 'Future' ||
          typeName.endsWith('Entity') ||
          typeName.endsWith('Result') ||
          typeName.endsWith('Response') ||
          typeName == 'bool';
    }
    return true;
  }

  bool _hasProperParameters(MethodDeclaration method) {
    final parameters = method.parameters;
    if (parameters == null) return false;

    // Use case should typically have at least one parameter
    // unless it's a simple query with no input
    return parameters.parameters.isNotEmpty;
  }

  bool _isEntityLevelWork(String methodName) {
    final entityWorkPatterns = [
      'validate',
      'isValid',
      'calculate',
      'compute',
      'applyRule',
      'checkRule',
      'enforceRule',
      'add',
      'remove',
      'update',
      'modify',
      'processPayment',
      'calculateTax',
      'applyDiscount',
    ];
    return entityWorkPatterns.any((pattern) => methodName.toLowerCase().contains(pattern.toLowerCase()));
  }

  bool _isUseCaseFile(String filePath) {
    return CleanArchitectureUtils.isDomainLayerFile(filePath) &&
        (filePath.contains('/usecases/') ||
            filePath.contains('\\usecases\\') ||
            filePath.contains('/use_cases/') ||
            filePath.contains('\\use_cases\\') ||
            filePath.endsWith('_usecase.dart') ||
            filePath.endsWith('usecase.dart'));
  }
}

class UseCaseStructureAnalysis {
  final List<MethodDeclaration> methods;
  final List<String> dependencies;

  const UseCaseStructureAnalysis({
    required this.methods,
    required this.dependencies,
  });
}
