import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Enforces proper repository implementation patterns in the data layer.
///
/// This rule ensures that repository implementations:
/// - Implement domain repository interfaces
/// - Properly transform data models to domain entities
/// - Delegate to appropriate data sources
/// - Handle errors and edge cases properly
/// - Don't contain business logic (only orchestration)
///
/// Repositories are responsible for:
/// - Coordinating between multiple data sources
/// - Caching strategies and data freshness
/// - Converting between data models and domain entities
/// - Error translation from technical to domain exceptions
class RepositoryImplementationRule extends DartLintRule {
  const RepositoryImplementationRule() : super(code: _code);

  static const _code = LintCode(
    name: 'repository_implementation',
    problemMessage:
        'Repository must properly implement domain interfaces with data transformation.',
    correctionMessage:
        'Ensure repository implements domain interface, transforms data models to entities, and delegates to data sources.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((node) {
      _checkRepositoryImplementation(node, reporter, resolver);
    });

    context.registry.addImportDirective((node) {
      _checkRepositoryImports(node, reporter, resolver);
    });
  }

  void _checkRepositoryImplementation(
    ClassDeclaration node,
    DiagnosticReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;

    // Only check files in data layer repositories
    if (!_isDataLayerRepositoryFile(filePath)) return;

    final className = node.name.lexeme;

    // Check if this is a repository implementation
    if (!_isRepositoryImplementation(className)) return;

    // Analyze the repository structure
    final analysis = _analyzeRepositoryClass(node);

    // Check if it implements a domain interface
    _checkDomainInterfaceImplementation(node, reporter, className);

    // Check for proper data source dependencies
    _checkDataSourceDependencies(analysis, reporter, className);

    // Check for data transformation logic
    _checkDataTransformation(analysis, reporter, className);

    // Check that repository doesn't contain business logic
    _checkNoBusinessLogic(analysis, reporter, className);
  }

  void _checkRepositoryImports(
    ImportDirective node,
    DiagnosticReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    if (!_isDataLayerRepositoryFile(filePath)) return;

    final importUri = node.uri.stringValue;
    if (importUri == null) return;

    // Repository should import both domain and data layers
    // This is valid as it bridges the two layers
  }

  RepositoryAnalysis _analyzeRepositoryClass(ClassDeclaration node) {
    final methods = <MethodDeclaration>[];
    final fields = <FieldDeclaration>[];
    final constructorParams = <FormalParameter>[];
    bool hasDataSourceDep = false;
    bool hasMapperOrConverter = false;
    bool hasTransformationLogic = false;

    for (final member in node.members) {
      if (member is MethodDeclaration) {
        methods.add(member);

        // Check for transformation patterns
        final bodyString = member.body.toString();
        if (_containsTransformationPattern(bodyString)) {
          hasTransformationLogic = true;
        }
      } else if (member is FieldDeclaration) {
        fields.add(member);

        final type = member.fields.type;
        if (type is NamedType) {
          final typeName = type.name.lexeme;
          if (typeName.contains('DataSource')) hasDataSourceDep = true;
          if (typeName.contains('Mapper') || typeName.contains('Converter')) {
            hasMapperOrConverter = true;
          }
        }
      } else if (member is ConstructorDeclaration) {
        constructorParams.addAll(member.parameters.parameters);
      }
    }

    return RepositoryAnalysis(
      methods: methods,
      fields: fields,
      constructorParams: constructorParams,
      hasDataSourceDep: hasDataSourceDep,
      hasMapperOrConverter: hasMapperOrConverter,
      hasTransformationLogic: hasTransformationLogic,
    );
  }

  void _checkDomainInterfaceImplementation(
    ClassDeclaration node,
    DiagnosticReporter reporter,
    String className,
  ) {
    final implementsClause = node.implementsClause;
    final extendsClause = node.extendsClause;

    if (implementsClause == null && extendsClause == null) {
      final code = LintCode(
        name: 'repository_implementation',
        problemMessage: 'Repository "$className" doesn\'t implement domain interface',
        correctionMessage: 'Implement the corresponding domain repository interface',
      );
      reporter.atNode(node, code);
    } else if (implementsClause != null) {
      // Check if implementing from domain layer
      bool implementsDomainInterface = false;
      for (final interface in implementsClause.interfaces) {
        final interfaceName = interface.name.lexeme;
        if (!interfaceName.contains('Impl') && interfaceName.contains('Repository')) {
          implementsDomainInterface = true;
          break;
        }
      }

      if (!implementsDomainInterface) {
        final code = LintCode(
          name: 'repository_implementation',
          problemMessage: 'Repository "$className" should implement domain repository interface',
          correctionMessage: 'Ensure the interface is from domain layer, not data layer',
        );
        reporter.atNode(node, code);
      }
    }
  }

  void _checkDataSourceDependencies(
    RepositoryAnalysis analysis,
    DiagnosticReporter reporter,
    String className,
  ) {
    if (!analysis.hasDataSourceDep) {
      final code = LintCode(
        name: 'repository_implementation',
        problemMessage: 'Repository "$className" has no DataSource dependencies',
        correctionMessage: 'Repository should delegate to DataSources for external communication',
      );
      reporter.atNode(analysis.methods.firstOrNull ?? analysis.fields.first, code);
    }
  }

  void _checkDataTransformation(
    RepositoryAnalysis analysis,
    DiagnosticReporter reporter,
    String className,
  ) {
    // Check if repository has transformation logic or mappers
    if (!analysis.hasTransformationLogic && !analysis.hasMapperOrConverter) {
      // Check methods for model-to-entity conversion
      bool hasConversion = false;
      for (final method in analysis.methods) {
        final returnType = method.returnType?.toString() ?? '';
        if (_isEntityType(returnType)) {
          // Method returns entity, should have conversion logic
          final bodyString = method.body.toString();
          if (!_containsModelToEntityConversion(bodyString)) {
            final code = LintCode(
              name: 'repository_implementation',
              problemMessage: 'Method "${method.name.lexeme}" returns entity without proper data transformation',
              correctionMessage: 'Convert data models to domain entities before returning',
            );
            reporter.atNode(method, code);
          } else {
            hasConversion = true;
          }
        }
      }

      if (!hasConversion && analysis.methods.isNotEmpty) {
        final code = LintCode(
          name: 'repository_implementation',
          problemMessage: 'Repository "$className" lacks data transformation logic',
          correctionMessage: 'Add mappers or converters to transform between data models and domain entities',
        );
        reporter.atNode(analysis.methods.first, code);
      }
    }
  }

  void _checkNoBusinessLogic(
    RepositoryAnalysis analysis,
    DiagnosticReporter reporter,
    String className,
  ) {
    for (final method in analysis.methods) {
      final bodyString = method.body.toString();
      if (_containsBusinessLogic(bodyString)) {
        final code = LintCode(
          name: 'repository_implementation',
          problemMessage: 'Repository method "${method.name.lexeme}" contains business logic',
          correctionMessage: 'Move business logic to domain layer (use cases or domain services)',
        );
        reporter.atNode(method, code);
      }
    }
  }

  bool _isDataLayerRepositoryFile(String filePath) {
    return (filePath.contains('/data/') || filePath.contains('\\data\\')) &&
        (filePath.contains('/repositories/') ||
            filePath.contains('\\repositories\\') ||
            filePath.contains('repository'));
  }

  bool _isRepositoryImplementation(String className) {
    return className.endsWith('Repository') ||
        className.endsWith('RepositoryImpl') ||
        className.contains('Repository');
  }

  bool _containsTransformationPattern(String bodyString) {
    final patterns = [
      'toEntity', 'fromModel', 'toDomain', 'fromData',
      'map(', 'mapper.', 'converter.', 'transform',
      '.toEntity()', '.toDomain()', '.fromJson(',
    ];
    return patterns.any((pattern) => bodyString.contains(pattern));
  }

  bool _isEntityType(String typeName) {
    // Check if return type is likely a domain entity
    return !typeName.contains('Model') &&
           !typeName.contains('DTO') &&
           !typeName.contains('Response') &&
           !typeName.contains('void') &&
           !typeName.contains('DataSource');
  }

  bool _containsModelToEntityConversion(String bodyString) {
    final conversionPatterns = [
      'toEntity', 'toDomain', '.map(', 'fromModel',
      'return Entity', 'return domain',
    ];
    return conversionPatterns.any((pattern) => bodyString.contains(pattern));
  }

  bool _containsBusinessLogic(String bodyString) {
    // Check for complex business logic patterns
    final businessPatterns = [
      'validate', 'calculate', 'compute', 'process',
      'if (.*&&.*||', // Complex conditionals
      'switch.*case.*case.*case', // Multiple business rules
    ];

    for (final pattern in businessPatterns) {
      if (RegExp(pattern).hasMatch(bodyString)) {
        // Exclude simple validation or null checks
        if (!bodyString.contains('!= null') &&
            !bodyString.contains('== null') &&
            !bodyString.contains('?.') &&
            !bodyString.contains('??')) {
          return true;
        }
      }
    }
    return false;
  }
}

class RepositoryAnalysis {
  final List<MethodDeclaration> methods;
  final List<FieldDeclaration> fields;
  final List<FormalParameter> constructorParams;
  final bool hasDataSourceDep;
  final bool hasMapperOrConverter;
  final bool hasTransformationLogic;

  RepositoryAnalysis({
    required this.methods,
    required this.fields,
    required this.constructorParams,
    required this.hasDataSourceDep,
    required this.hasMapperOrConverter,
    required this.hasTransformationLogic,
  });
}
