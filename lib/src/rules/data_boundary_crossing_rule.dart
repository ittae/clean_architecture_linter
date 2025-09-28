import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../clean_architecture_linter_base.dart';

/// Enforces proper data crossing boundaries in Clean Architecture.
///
/// Uncle Bob: "Typically the data that crosses the boundaries is simple data
/// structures. You can use basic structs or simple Data Transfer objects if
/// you like. Or the data can simply be arguments in function calls. Or you
/// can pack it into a hashmap, or construct it into an object. The important
/// thing is that isolated, simple, data structures are passed across the
/// boundaries."
///
/// Key principles enforced:
/// - Simple data structures cross boundaries (DTOs, basic structs)
/// - No Entities passed across boundaries
/// - No Database rows passed inward
/// - No framework-specific data structures across boundaries
/// - Data format convenient for inner circle
/// - No dependencies that violate The Dependency Rule
///
/// Violations detected:
/// - Entities crossing boundaries
/// - Database RowStructure objects passed inward
/// - Framework-specific objects in boundary methods
/// - Complex objects with behavior crossing boundaries
/// - ORM objects leaking to inner layers
class DataBoundaryCrossingRule extends CleanArchitectureLintRule {
  const DataBoundaryCrossingRule() : super(code: _code);

  static const _code = LintCode(
    name: 'data_boundary_crossing',
    problemMessage: 'Data boundary crossing violation: {0}',
    correctionMessage: 'Use simple data structures (DTOs) that are convenient for the inner circle.',
  );

  @override
  void runRule(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((node) {
      _analyzeMethodDataBoundary(node, reporter, resolver);
    });

    context.registry.addFunctionDeclaration((node) {
      _analyzeFunctionDataBoundary(node, reporter, resolver);
    });

    context.registry.addClassDeclaration((node) {
      _analyzeDataTransferClass(node, reporter, resolver);
    });

    context.registry.addVariableDeclaration((node) {
      _analyzeVariableDataBoundary(node, reporter, resolver);
    });
  }

  void _analyzeMethodDataBoundary(
    MethodDeclaration method,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    final layer = _detectLayer(filePath);
    if (layer == null) return;

    final methodName = method.name.lexeme;

    // Check method parameters for boundary violations
    _validateMethodParameters(method, reporter, layer, methodName);

    // Check return type for boundary violations
    _validateMethodReturnType(method, reporter, layer, methodName);

    // Check method body for data boundary violations
    _validateMethodBodyDataFlow(method, reporter, layer, methodName);
  }

  void _analyzeFunctionDataBoundary(
    FunctionDeclaration function,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    final layer = _detectLayer(filePath);
    if (layer == null) return;

    final functionName = function.name.lexeme;

    // Check function parameters and return type
    _validateFunctionParameters(function, reporter, layer, functionName);
    _validateFunctionReturnType(function, reporter, layer, functionName);
  }

  void _analyzeDataTransferClass(
    ClassDeclaration node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    final className = node.name.lexeme;
    final layer = _detectLayer(filePath);

    if (layer == null) return;

    // Check if class is appropriate for data transfer
    if (_isDataTransferClass(className)) {
      _validateDataTransferObjectDesign(node, reporter, layer, className);
    }

    // Check if inappropriate data structures are being used
    _checkInappropriateDataStructures(node, reporter, layer, className);
  }

  void _analyzeVariableDataBoundary(
    VariableDeclaration variable,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    final layer = _detectLayer(filePath);
    if (layer == null) return;

    // Check variable type for boundary violations
    final parent = variable.parent;
    if (parent is VariableDeclarationList) {
      final type = parent.type;
      if (type != null) {
        _validateVariableType(variable, reporter, layer, type);
      }
    }
  }

  void _validateMethodParameters(
    MethodDeclaration method,
    ErrorReporter reporter,
    ArchitecturalLayer layer,
    String methodName,
  ) {
    final parameters = method.parameters?.parameters ?? [];

    for (final param in parameters) {
      if (param is SimpleFormalParameter) {
        final type = param.type;
        if (type is NamedType) {
          final typeName = type.name2.lexeme;
          final paramName = param.name?.lexeme ?? '';

          _validateParameterBoundaryData(
            param,
            reporter,
            layer,
            methodName,
            typeName,
            paramName,
          );
        }
      }
    }
  }

  void _validateMethodReturnType(
    MethodDeclaration method,
    ErrorReporter reporter,
    ArchitecturalLayer layer,
    String methodName,
  ) {
    final returnType = method.returnType;
    if (returnType is NamedType) {
      final typeName = returnType.name2.lexeme;

      _validateReturnTypeBoundaryData(
        method,
        reporter,
        layer,
        methodName,
        typeName,
      );
    }
  }

  void _validateMethodBodyDataFlow(
    MethodDeclaration method,
    ErrorReporter reporter,
    ArchitecturalLayer layer,
    String methodName,
  ) {
    // Check for inappropriate data conversions
    _checkDataConversionViolations(method, reporter, layer, methodName);

    // Check for entity manipulation in boundary methods
    _checkEntityManipulationViolations(method, reporter, layer, methodName);

    // Check for database row passing
    _checkDatabaseRowViolations(method, reporter, layer, methodName);
  }

  void _validateParameterBoundaryData(
    SimpleFormalParameter param,
    ErrorReporter reporter,
    ArchitecturalLayer layer,
    String methodName,
    String typeName,
    String paramName,
  ) {
    // Check for Entity objects crossing boundaries
    if (_isEntityType(typeName)) {
      final boundary = _detectBoundaryType(layer, methodName);
      if (boundary != BoundaryType.none) {
        final code = LintCode(
          name: 'data_boundary_crossing',
          problemMessage: 'Entity $typeName passed across ${boundary.name} boundary in $methodName',
          correctionMessage: 'Convert entity to simple DTO before crossing boundary.',
        );
        reporter.atNode(param, code);
      }
    }

    // Check for Database row structures
    if (_isDatabaseRowType(typeName)) {
      if (_isCrossingInward(layer)) {
        final code = LintCode(
          name: 'data_boundary_crossing',
          problemMessage: 'Database row structure $typeName passed inward across boundary',
          correctionMessage: 'Convert to simple data structure convenient for inner circle.',
        );
        reporter.atNode(param, code);
      }
    }

    // Check for framework-specific types
    if (_isFrameworkSpecificType(typeName)) {
      final boundary = _detectBoundaryType(layer, methodName);
      if (boundary != BoundaryType.none) {
        final code = LintCode(
          name: 'data_boundary_crossing',
          problemMessage: 'Framework-specific type $typeName crosses ${boundary.name} boundary',
          correctionMessage: 'Use framework-agnostic data structure for boundary crossing.',
        );
        reporter.atNode(param, code);
      }
    }

    // Check for complex objects with behavior
    if (_isComplexObjectWithBehavior(typeName)) {
      final boundary = _detectBoundaryType(layer, methodName);
      if (boundary != BoundaryType.none) {
        final code = LintCode(
          name: 'data_boundary_crossing',
          problemMessage: 'Complex object $typeName with behavior crosses boundary in $methodName',
          correctionMessage: 'Extract data into simple structure for boundary crossing.',
        );
        reporter.atNode(param, code);
      }
    }
  }

  void _validateReturnTypeBoundaryData(
    MethodDeclaration method,
    ErrorReporter reporter,
    ArchitecturalLayer layer,
    String methodName,
    String typeName,
  ) {
    final boundary = _detectBoundaryType(layer, methodName);
    if (boundary == BoundaryType.none) return;

    // Check for Entity returns across boundaries
    if (_isEntityType(typeName)) {
      final code = LintCode(
        name: 'data_boundary_crossing',
        problemMessage: 'Method $methodName returns Entity $typeName across ${boundary.name} boundary',
        correctionMessage: 'Return simple DTO instead of Entity.',
      );
      reporter.atNode(method, code);
    }

    // Check for ORM objects being returned
    if (_isORMType(typeName)) {
      final code = LintCode(
        name: 'data_boundary_crossing',
        problemMessage: 'Method $methodName returns ORM object $typeName across boundary',
        correctionMessage: 'Convert ORM object to simple data structure before returning.',
      );
      reporter.atNode(method, code);
    }

    // Check for inappropriate collection types
    if (_isInappropriateCollectionType(typeName, boundary)) {
      final code = LintCode(
        name: 'data_boundary_crossing',
        problemMessage: 'Method $methodName returns inappropriate collection type across boundary',
        correctionMessage: 'Use simple collection of DTOs for boundary crossing.',
      );
      reporter.atNode(method, code);
    }
  }

  void _validateDataTransferObjectDesign(
    ClassDeclaration node,
    ErrorReporter reporter,
    ArchitecturalLayer layer,
    String className,
  ) {
    // Check DTO design principles
    _validateDTOSimplicity(node, reporter, className);
    _validateDTOImmutability(node, reporter, className);
    _validateDTODependencies(node, reporter, layer, className);
    _validateDTONaming(node, reporter, className);
  }

  void _validateDTOSimplicity(
    ClassDeclaration node,
    ErrorReporter reporter,
    String className,
  ) {
    // Check for business logic in DTO
    final methods = node.members.whereType<MethodDeclaration>();

    for (final method in methods) {
      final methodName = method.name.lexeme;

      if (_isBusinessLogicMethod(methodName) && !_isAllowedDTOMethod(methodName)) {
        final code = LintCode(
          name: 'data_boundary_crossing',
          problemMessage: 'DTO $className contains business logic method: $methodName',
          correctionMessage: 'DTOs should be simple data containers without business logic.',
        );
        reporter.atNode(method, code);
      }
    }

    // Check for complex nested objects
    _validateDTONestedComplexity(node, reporter, className);
  }

  void _validateDTOImmutability(
    ClassDeclaration node,
    ErrorReporter reporter,
    String className,
  ) {
    final fields = node.members.whereType<FieldDeclaration>();

    for (final field in fields) {
      if (!field.fields.isFinal && !field.fields.isLate) {
        final code = LintCode(
          name: 'data_boundary_crossing',
          problemMessage: 'DTO $className has mutable field - DTOs should be immutable',
          correctionMessage: 'Make DTO fields final for immutable data transfer.',
        );
        reporter.atNode(field, code);
      }
    }
  }

  void _validateDTODependencies(
    ClassDeclaration node,
    ErrorReporter reporter,
    ArchitecturalLayer layer,
    String className,
  ) {
    // Check for inappropriate dependencies in DTO fields
    final fields = node.members.whereType<FieldDeclaration>();

    for (final field in fields) {
      final type = field.fields.type;
      if (type is NamedType) {
        final typeName = type.name2.lexeme;

        if (_violatesDTODependencyRules(typeName, layer)) {
          final code = LintCode(
            name: 'data_boundary_crossing',
            problemMessage: 'DTO $className has inappropriate dependency: $typeName',
            correctionMessage: 'DTOs should only contain simple types or other DTOs.',
          );
          reporter.atNode(field, code);
        }
      }
    }
  }

  void _checkDataConversionViolations(
    MethodDeclaration method,
    ErrorReporter reporter,
    ArchitecturalLayer layer,
    String methodName,
  ) {
    final body = method.body;
    final bodyString = body.toString();

    // Check for entity-to-entity conversions across boundaries
    if (_containsEntityConversion(bodyString) && _isBoundaryMethod(layer, methodName)) {
      final code = LintCode(
        name: 'data_boundary_crossing',
        problemMessage: 'Method $methodName performs entity conversion across boundary',
        correctionMessage: 'Use simple data mapping instead of entity conversion.',
      );
      reporter.atNode(method, code);
    }

    // Check for direct database object passing
    if (_containsDatabaseObjectPassing(bodyString)) {
      final code = LintCode(
        name: 'data_boundary_crossing',
        problemMessage: 'Method $methodName passes database objects across boundary',
        correctionMessage: 'Convert database objects to simple data structures.',
      );
      reporter.atNode(method, code);
    }
  }

  void _checkEntityManipulationViolations(
    MethodDeclaration method,
    ErrorReporter reporter,
    ArchitecturalLayer layer,
    String methodName,
  ) {
    final body = method.body;
    // Check if boundary method manipulates entities directly
    if (_isBoundaryMethod(layer, methodName) && _manipulatesEntities(body)) {
      final code = LintCode(
        name: 'data_boundary_crossing',
        problemMessage: 'Boundary method $methodName manipulates entities directly',
        correctionMessage: 'Extract entity data to DTOs before boundary operations.',
      );
      reporter.atNode(method, code);
    }
  }

  void _checkDatabaseRowViolations(
    MethodDeclaration method,
    ErrorReporter reporter,
    ArchitecturalLayer layer,
    String methodName,
  ) {
    final body = method.body;
    final bodyString = body.toString();

    // Check for RowStructure or similar being passed inward
    if (_containsRowStructurePassing(bodyString) && _isCrossingInward(layer)) {
      final code = LintCode(
        name: 'data_boundary_crossing',
        problemMessage: 'Method $methodName passes database row structure inward',
        correctionMessage: 'Convert row structure to format convenient for inner circle.',
      );
      reporter.atNode(method, code);
    }
  }

  void _checkInappropriateDataStructures(
    ClassDeclaration node,
    ErrorReporter reporter,
    ArchitecturalLayer layer,
    String className,
  ) {
    // Check if class represents inappropriate boundary data
    if (_isInappropriateBoundaryData(className, layer)) {
      final code = LintCode(
        name: 'data_boundary_crossing',
        problemMessage: 'Class $className is inappropriate for boundary data transfer',
        correctionMessage: 'Create simple DTO for boundary data transfer instead.',
      );
      reporter.atNode(node, code);
    }

    // Check for framework coupling in data structures
    _checkFrameworkCouplingInData(node, reporter, layer, className);
  }

  void _validateFunctionParameters(
    FunctionDeclaration function,
    ErrorReporter reporter,
    ArchitecturalLayer layer,
    String functionName,
  ) {
    final parameters = function.functionExpression.parameters?.parameters ?? [];

    for (final param in parameters) {
      if (param is SimpleFormalParameter) {
        final type = param.type;
        if (type is NamedType) {
          final typeName = type.name2.lexeme;

          _validateParameterBoundaryData(
            param,
            reporter,
            layer,
            functionName,
            typeName,
            param.name?.lexeme ?? '',
          );
        }
      }
    }
  }

  void _validateFunctionReturnType(
    FunctionDeclaration function,
    ErrorReporter reporter,
    ArchitecturalLayer layer,
    String functionName,
  ) {
    final returnType = function.returnType;
    if (returnType is NamedType) {
      final typeName = returnType.name2.lexeme;

      // Create a simple validation for function return type
      final boundary = _detectBoundaryType(layer, functionName);
      if (boundary != BoundaryType.none && _isInappropriateBoundaryDataType(typeName)) {
        final code = LintCode(
          name: 'data_boundary_crossing',
          problemMessage: 'Function returns inappropriate boundary type: $typeName',
          correctionMessage: 'Return DTO or simple data structure for boundary crossing.',
        );
        reporter.atNode(function, code);
      }
    }
  }

  void _validateVariableType(
    VariableDeclaration variable,
    ErrorReporter reporter,
    ArchitecturalLayer layer,
    TypeAnnotation type,
  ) {
    if (type is NamedType) {
      final typeName = type.name2.lexeme;

      if (_isInappropriateBoundaryDataType(typeName) && _isInBoundaryContext(layer)) {
        final code = LintCode(
          name: 'data_boundary_crossing',
          problemMessage: 'Variable of inappropriate boundary type: $typeName',
          correctionMessage: 'Use simple data structure for boundary operations.',
        );
        reporter.atNode(variable, code);
      }
    }
  }

  void _validateDTONestedComplexity(
    ClassDeclaration node,
    ErrorReporter reporter,
    String className,
  ) {
    final fields = node.members.whereType<FieldDeclaration>();

    for (final field in fields) {
      final type = field.fields.type;
      if (type is NamedType) {
        final typeName = type.name2.lexeme;

        if (_isOverlyComplexForDTO(typeName)) {
          final code = LintCode(
            name: 'data_boundary_crossing',
            problemMessage: 'DTO $className field has overly complex type: $typeName',
            correctionMessage: 'Simplify DTO structure or create separate DTOs for complex data.',
          );
          reporter.atNode(field, code);
        }
      }
    }
  }

  void _validateDTONaming(
    ClassDeclaration node,
    ErrorReporter reporter,
    String className,
  ) {
    if (!_hasProperDTONaming(className)) {
      final code = LintCode(
        name: 'data_boundary_crossing',
        problemMessage: 'Data transfer class $className should follow DTO naming conventions',
        correctionMessage: 'Use DTO, Data, or Request/Response suffix for boundary data classes.',
      );
      reporter.atNode(node, code);
    }
  }

  void _checkFrameworkCouplingInData(
    ClassDeclaration node,
    ErrorReporter reporter,
    ArchitecturalLayer layer,
    String className,
  ) {
    // Check for framework annotations or dependencies
    for (final member in node.members) {
      if (member is FieldDeclaration) {
        final type = member.fields.type;
        if (type is NamedType) {
          final typeName = type.name2.lexeme;

          if (_isFrameworkCoupledType(typeName)) {
            final code = LintCode(
              name: 'data_boundary_crossing',
              problemMessage: 'Data class $className has framework coupling: $typeName',
              correctionMessage: 'Remove framework dependencies from boundary data structures.',
            );
            reporter.atNode(member, code);
          }
        }
      }
    }
  }

  // Helper methods for type classification
  ArchitecturalLayer? _detectLayer(String filePath) {
    if (filePath.contains('/domain/')) return ArchitecturalLayer('domain', 4);
    if (filePath.contains('/usecases/') || filePath.contains('/use_cases/')) {
      return ArchitecturalLayer('use_case', 3);
    }
    if (filePath.contains('/adapters/')) return ArchitecturalLayer('adapter', 2);
    if (filePath.contains('/controllers/')) return ArchitecturalLayer('controller', 2);
    if (filePath.contains('/presenters/')) return ArchitecturalLayer('presenter', 2);
    if (filePath.contains('/infrastructure/')) return ArchitecturalLayer('infrastructure', 1);
    if (filePath.contains('/data/')) return ArchitecturalLayer('data', 1);
    return null;
  }

  BoundaryType _detectBoundaryType(ArchitecturalLayer layer, String methodName) {
    // Detect if method is crossing architectural boundaries
    if (_isControllerBoundaryMethod(layer, methodName)) return BoundaryType.controllerUsecase;
    if (_isUseCaseBoundaryMethod(layer, methodName)) return BoundaryType.usecasePresenter;
    if (_isRepositoryBoundaryMethod(layer, methodName)) return BoundaryType.usecaseRepository;
    if (_isGatewayBoundaryMethod(layer, methodName)) return BoundaryType.adapterInfrastructure;
    return BoundaryType.none;
  }

  bool _isEntityType(String typeName) {
    return typeName.contains('Entity') ||
        typeName.contains('Aggregate') ||
        typeName.contains('ValueObject') ||
        _isDomainModelType(typeName);
  }

  bool _isDatabaseRowType(String typeName) {
    final rowTypes = ['Row', 'RowStructure', 'ResultSet', 'DataRow', 'QueryResult', 'DatabaseRow', 'TableRow'];
    return rowTypes.any((type) => typeName.contains(type));
  }

  bool _isFrameworkSpecificType(String typeName) {
    final frameworkTypes = [
      'HttpRequest',
      'HttpResponse',
      'ServletRequest',
      'ServletResponse',
      'DatabaseConnection',
      'Connection',
      'Statement',
      'PreparedStatement',
      'Intent',
      'Bundle',
      'Context',
      'Activity',
      'Fragment'
    ];
    return frameworkTypes.any((type) => typeName.contains(type));
  }

  bool _isComplexObjectWithBehavior(String typeName) {
    final behavioralTypes = ['Service', 'Manager', 'Handler', 'Processor', 'Controller', 'Component', 'Bean'];
    return behavioralTypes.any((type) => typeName.contains(type));
  }

  bool _isORMType(String typeName) {
    final ormTypes = ['Entity', 'Model', 'ActiveRecord', 'DataModel', 'PersistentObject', 'DomainObject'];
    return ormTypes.any((type) => typeName.contains(type)) && !_isDataTransferClass(typeName);
  }

  bool _isDataTransferClass(String className) {
    final dtoIndicators = ['DTO', 'Data', 'Request', 'Response', 'Command', 'Query', 'Message', 'Payload'];
    return dtoIndicators.any((indicator) => className.contains(indicator));
  }

  bool _isInappropriateCollectionType(String typeName, BoundaryType boundary) {
    // Check for framework-specific collections or collections of inappropriate types
    return typeName.contains('ArrayList') ||
        typeName.contains('Vector') ||
        typeName.contains('HashMap') && boundary != BoundaryType.none;
  }

  bool _isCrossingInward(ArchitecturalLayer layer) {
    // Methods in outer layers that pass data inward
    return layer.name == 'infrastructure' || layer.name == 'adapter' || layer.name == 'data';
  }

  bool _isBusinessLogicMethod(String methodName) {
    final businessPatterns = [
      'calculate',
      'validate',
      'process',
      'execute',
      'apply',
      'transform',
      'compute',
      'evaluate'
    ];
    return businessPatterns.any((pattern) => methodName.toLowerCase().contains(pattern));
  }

  bool _isAllowedDTOMethod(String methodName) {
    final allowedMethods = ['toString', 'equals', 'hashCode', 'copyWith', 'toJson', 'fromJson', 'toMap', 'fromMap'];
    return allowedMethods.any((method) => methodName.contains(method));
  }

  bool _violatesDTODependencyRules(String typeName, ArchitecturalLayer layer) {
    return _isEntityType(typeName) || _isFrameworkSpecificType(typeName) || _isComplexObjectWithBehavior(typeName);
  }

  bool _isBoundaryMethod(ArchitecturalLayer layer, String methodName) {
    return _detectBoundaryType(layer, methodName) != BoundaryType.none;
  }

  bool _containsEntityConversion(String bodyString) {
    final conversionPatterns = ['.toEntity(', '.fromEntity(', 'Entity.from', 'toValueObject'];
    return conversionPatterns.any((pattern) => bodyString.contains(pattern));
  }

  bool _containsDatabaseObjectPassing(String bodyString) {
    final dbPatterns = ['ResultSet', 'DataRow', 'RowStructure', 'QueryResult'];
    return dbPatterns.any((pattern) => bodyString.contains(pattern));
  }

  bool _manipulatesEntities(FunctionBody body) {
    final bodyString = body.toString();
    final entityManipulation = ['.setId(', '.updateValue(', '.changeState(', '.applyRule('];
    return entityManipulation.any((pattern) => bodyString.contains(pattern));
  }

  bool _containsRowStructurePassing(String bodyString) {
    return bodyString.contains('RowStructure') || bodyString.contains('row.') || bodyString.contains('resultSet.');
  }

  bool _isInappropriateBoundaryData(String className, ArchitecturalLayer layer) {
    return _isEntityType(className) ||
        _isFrameworkSpecificType(className) ||
        (_isDatabaseRowType(className) && layer.level > 1);
  }

  bool _isInappropriateBoundaryDataType(String typeName) {
    return _isEntityType(typeName) || _isDatabaseRowType(typeName) || _isFrameworkSpecificType(typeName);
  }

  bool _isInBoundaryContext(ArchitecturalLayer layer) {
    return layer.name == 'adapter' || layer.name == 'controller' || layer.name == 'presenter';
  }

  bool _isOverlyComplexForDTO(String typeName) {
    return _isComplexObjectWithBehavior(typeName) ||
        _isFrameworkSpecificType(typeName) ||
        typeName.contains('Manager') ||
        typeName.contains('Builder');
  }

  bool _hasProperDTONaming(String className) {
    final dtoSuffixes = ['DTO', 'Data', 'Request', 'Response', 'Command', 'Query'];
    return dtoSuffixes.any((suffix) => className.endsWith(suffix));
  }

  bool _isFrameworkCoupledType(String typeName) {
    return _isFrameworkSpecificType(typeName) || typeName.contains('Annotation') || typeName.contains('Context');
  }

  bool _isDomainModelType(String typeName) {
    return typeName.contains('Model') && !_isDataTransferClass(typeName);
  }

  // Boundary detection methods
  bool _isControllerBoundaryMethod(ArchitecturalLayer layer, String methodName) {
    return layer.name == 'controller' && (methodName.contains('handle') || methodName.contains('process'));
  }

  bool _isUseCaseBoundaryMethod(ArchitecturalLayer layer, String methodName) {
    return layer.name == 'use_case' && (methodName.contains('execute') || methodName.contains('perform'));
  }

  bool _isRepositoryBoundaryMethod(ArchitecturalLayer layer, String methodName) {
    return layer.name == 'infrastructure' &&
        (methodName.contains('save') || methodName.contains('find') || methodName.contains('get'));
  }

  bool _isGatewayBoundaryMethod(ArchitecturalLayer layer, String methodName) {
    return layer.name == 'infrastructure' &&
        (methodName.contains('call') || methodName.contains('send') || methodName.contains('fetch'));
  }
}

class ArchitecturalLayer {
  final String name;
  final int level;

  ArchitecturalLayer(this.name, this.level);
}

enum BoundaryType {
  controllerUsecase,
  usecasePresenter,
  usecaseRepository,
  adapterInfrastructure,
  none,
}
