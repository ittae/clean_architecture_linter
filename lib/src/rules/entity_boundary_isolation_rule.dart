import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Prevents Entity leakage across architectural boundaries.
///
/// Uncle Bob: "We don't want to cheat and pass Entities or Database rows.
/// We don't want the data structures to have any kind of dependency that
/// violates The Dependency Rule."
///
/// This rule enforces:
/// - Entities remain within domain boundaries
/// - Value Objects don't leak to outer layers
/// - Domain aggregates are not passed across boundaries
/// - Entity behavior is not exposed to outer layers
/// - Entities are converted to DTOs at boundaries
/// - No entity serialization across boundaries
///
/// Specific violations detected:
/// - Entity types in controller method signatures
/// - Entities passed to presenter methods
/// - Entities returned from repository implementations
/// - Value Objects in adapter layer
/// - Domain aggregates in infrastructure layer
/// - Entity collections crossing boundaries
class EntityBoundaryIsolationRule extends DartLintRule {
  const EntityBoundaryIsolationRule() : super(code: _code);

  static const _code = LintCode(
    name: 'entity_boundary_isolation',
    problemMessage: 'Entity boundary isolation violation: {0}',
    correctionMessage: 'Entities must remain in domain layer. Convert to DTOs for boundary crossing.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((node) {
      _analyzeMethodEntityUsage(node, reporter, resolver);
    });

    context.registry.addVariableDeclaration((node) {
      _analyzeVariableEntityUsage(node, reporter, resolver);
    });

    context.registry.addFieldDeclaration((node) {
      _analyzeFieldEntityUsage(node, reporter, resolver);
    });

    context.registry.addClassDeclaration((node) {
      _analyzeClassEntityDependency(node, reporter, resolver);
    });

    context.registry.addMethodInvocation((node) {
      _analyzeMethodCallEntityPassing(node, reporter, resolver);
    });
  }

  void _analyzeMethodEntityUsage(
    MethodDeclaration method,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    final layer = _detectLayer(filePath);
    if (layer == null) return;

    final methodName = method.name.lexeme;

    // Check method parameters for entity leakage
    _checkMethodParametersForEntities(method, reporter, layer, methodName);

    // Check return type for entity leakage
    _checkMethodReturnTypeForEntities(method, reporter, layer, methodName);

    // Check method body for entity manipulation outside domain
    _checkMethodBodyEntityManipulation(method, reporter, layer, methodName);
  }

  void _analyzeVariableEntityUsage(
    VariableDeclaration variable,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    final layer = _detectLayer(filePath);
    if (layer == null || _isDomainLayer(layer)) return;

    final parent = variable.parent;
    if (parent is VariableDeclarationList) {
      final type = parent.type;
      if (type is NamedType) {
        final typeName = type.name2.lexeme;

        if (_isEntityType(typeName)) {
          final code = LintCode(
            name: 'entity_boundary_isolation',
            problemMessage: 'Entity $typeName used as variable in ${layer.name} layer',
            correctionMessage: 'Use DTO instead of Entity outside domain layer.',
          );
          reporter.atNode(variable, code);
        }
      }
    }
  }

  void _analyzeFieldEntityUsage(
    FieldDeclaration field,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    final layer = _detectLayer(filePath);
    if (layer == null || _isDomainLayer(layer)) return;

    final type = field.fields.type;
    if (type is NamedType) {
      final typeName = type.name2.lexeme;

      if (_isEntityType(typeName)) {
        final code = LintCode(
          name: 'entity_boundary_isolation',
          problemMessage: 'Entity $typeName used as field in ${layer.name} layer',
          correctionMessage: 'Store DTO instead of Entity in ${layer.name} layer.',
        );
        reporter.atNode(field, code);
      }

      if (_isEntityCollectionType(typeName)) {
        final code = LintCode(
          name: 'entity_boundary_isolation',
          problemMessage: 'Entity collection $typeName used as field in ${layer.name} layer',
          correctionMessage: 'Use collection of DTOs instead of entity collection.',
        );
        reporter.atNode(field, code);
      }
    }
  }

  void _analyzeClassEntityDependency(
    ClassDeclaration node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    final className = node.name.lexeme;
    final layer = _detectLayer(filePath);

    if (layer == null || _isDomainLayer(layer)) return;

    // Check class inheritance from entities
    _checkEntityInheritance(node, reporter, layer, className);

    // Check class implementation of entity interfaces
    _checkEntityInterfaceImplementation(node, reporter, layer, className);

    // Check for entity composition
    _checkEntityComposition(node, reporter, layer, className);
  }

  void _analyzeMethodCallEntityPassing(
    MethodInvocation node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    final layer = _detectLayer(filePath);
    if (layer == null) return;

    final methodName = node.methodName.name;

    // Check arguments for entity passing
    _checkMethodArgumentsForEntities(node, reporter, layer, methodName);

    // Check for entity method calls on non-domain objects
    _checkEntityMethodCallsOutsideDomain(node, reporter, layer, methodName);
  }

  void _checkMethodParametersForEntities(
    MethodDeclaration method,
    ErrorReporter reporter,
    ArchitecturalLayer layer,
    String methodName,
  ) {
    if (_isDomainLayer(layer)) return;

    final parameters = method.parameters?.parameters ?? [];

    for (final param in parameters) {
      if (param is SimpleFormalParameter) {
        final type = param.type;
        if (type is NamedType) {
          final typeName = type.name2.lexeme;
          final paramName = param.name?.lexeme ?? '';

          if (_isEntityType(typeName)) {
            final violationType = _getEntityViolationType(layer, methodName);
            final code = LintCode(
              name: 'entity_boundary_isolation',
              problemMessage: '${violationType.description}: Entity $typeName in parameter $paramName',
              correctionMessage: violationType.correction,
            );
            reporter.atNode(param, code);
          }

          if (_isValueObjectType(typeName)) {
            final code = LintCode(
              name: 'entity_boundary_isolation',
              problemMessage: 'Value Object $typeName used in ${layer.name} layer parameter',
              correctionMessage: 'Extract primitive value or create DTO for value object data.',
            );
            reporter.atNode(param, code);
          }

          if (_isDomainAggregateType(typeName)) {
            final code = LintCode(
              name: 'entity_boundary_isolation',
              problemMessage: 'Domain Aggregate $typeName passed to ${layer.name} layer',
              correctionMessage: 'Break down aggregate into DTOs for boundary crossing.',
            );
            reporter.atNode(param, code);
          }
        }
      }
    }
  }

  void _checkMethodReturnTypeForEntities(
    MethodDeclaration method,
    ErrorReporter reporter,
    ArchitecturalLayer layer,
    String methodName,
  ) {
    if (_isDomainLayer(layer)) return;

    final returnType = method.returnType;
    if (returnType is NamedType) {
      final typeName = returnType.name2.lexeme;

      if (_isEntityType(typeName)) {
        final violationType = _getEntityViolationType(layer, methodName);
        final code = LintCode(
          name: 'entity_boundary_isolation',
          problemMessage: '${violationType.description}: Method returns Entity $typeName',
          correctionMessage: violationType.correction,
        );
        reporter.atNode(method, code);
      }

      if (_isEntityCollectionType(typeName)) {
        final code = LintCode(
          name: 'entity_boundary_isolation',
          problemMessage: 'Method returns entity collection from ${layer.name} layer',
          correctionMessage: 'Return collection of DTOs instead of entities.',
        );
        reporter.atNode(method, code);
      }
    }
  }

  void _checkMethodBodyEntityManipulation(
    MethodDeclaration method,
    ErrorReporter reporter,
    ArchitecturalLayer layer,
    String methodName,
  ) {
    if (_isDomainLayer(layer)) return;

    final body = method.body;
    final bodyString = body.toString();

    // Check for direct entity instantiation
    if (_containsEntityInstantiation(bodyString)) {
      final code = LintCode(
        name: 'entity_boundary_isolation',
        problemMessage: 'Method $methodName in ${layer.name} layer instantiates entities',
        correctionMessage: 'Entities should only be created in domain layer.',
      );
      reporter.atNode(method, code);
    }

    // Check for entity state modification
    if (_containsEntityStateModification(bodyString)) {
      final code = LintCode(
        name: 'entity_boundary_isolation',
        problemMessage: 'Method $methodName in ${layer.name} layer modifies entity state',
        correctionMessage: 'Entity state should only be modified in domain layer.',
      );
      reporter.atNode(method, code);
    }

    // Check for entity business rule invocation
    if (_containsEntityBusinessRuleInvocation(bodyString)) {
      final code = LintCode(
        name: 'entity_boundary_isolation',
        problemMessage: 'Method $methodName in ${layer.name} layer calls entity business rules',
        correctionMessage: 'Call business rules through use cases, not directly on entities.',
      );
      reporter.atNode(method, code);
    }
  }

  void _checkEntityInheritance(
    ClassDeclaration node,
    ErrorReporter reporter,
    ArchitecturalLayer layer,
    String className,
  ) {
    final extendsClause = node.extendsClause;
    if (extendsClause != null) {
      final superclassName = extendsClause.superclass.name2.lexeme;

      if (_isEntityType(superclassName)) {
        final code = LintCode(
          name: 'entity_boundary_isolation',
          problemMessage: '${layer.name} layer class $className extends entity $superclassName',
          correctionMessage: 'Use composition instead of inheritance from entities.',
        );
        reporter.atNode(extendsClause, code);
      }
    }
  }

  void _checkEntityInterfaceImplementation(
    ClassDeclaration node,
    ErrorReporter reporter,
    ArchitecturalLayer layer,
    String className,
  ) {
    final implementsClause = node.implementsClause;
    if (implementsClause != null) {
      for (final interface in implementsClause.interfaces) {
        final interfaceName = interface.name2.lexeme;

        if (_isEntityInterface(interfaceName)) {
          final code = LintCode(
            name: 'entity_boundary_isolation',
            problemMessage: '${layer.name} layer class $className implements entity interface $interfaceName',
            correctionMessage: 'Create boundary-specific interface instead of implementing entity interface.',
          );
          reporter.atNode(interface, code);
        }
      }
    }
  }

  void _checkEntityComposition(
    ClassDeclaration node,
    ErrorReporter reporter,
    ArchitecturalLayer layer,
    String className,
  ) {
    final fields = node.members.whereType<FieldDeclaration>();

    for (final field in fields) {
      final type = field.fields.type;
      if (type is NamedType) {
        final typeName = type.name2.lexeme;

        if (_isEntityType(typeName)) {
          final code = LintCode(
            name: 'entity_boundary_isolation',
            problemMessage: '${layer.name} layer class $className composes entity $typeName',
            correctionMessage: 'Store entity ID or DTO instead of entity reference.',
          );
          reporter.atNode(field, code);
        }

        if (_isEntityAggregateType(typeName)) {
          final code = LintCode(
            name: 'entity_boundary_isolation',
            problemMessage: '${layer.name} layer class $className composes entity aggregate $typeName',
            correctionMessage: 'Break down aggregate composition into DTOs.',
          );
          reporter.atNode(field, code);
        }
      }
    }
  }

  void _checkMethodArgumentsForEntities(
    MethodInvocation node,
    ErrorReporter reporter,
    ArchitecturalLayer layer,
    String methodName,
  ) {
    if (_isDomainLayer(layer)) return;

    // This would require type resolution to determine argument types
    // For now, we'll check for obvious entity passing patterns
    final target = node.target?.toString() ?? '';

    if (_isEntityReference(target)) {
      final code = LintCode(
        name: 'entity_boundary_isolation',
        problemMessage: 'Entity reference passed to method $methodName in ${layer.name} layer',
        correctionMessage: 'Pass entity data as DTO instead of entity reference.',
      );
      reporter.atNode(node, code);
    }
  }

  void _checkEntityMethodCallsOutsideDomain(
    MethodInvocation node,
    ErrorReporter reporter,
    ArchitecturalLayer layer,
    String methodName,
  ) {
    if (_isDomainLayer(layer)) return;

    final target = node.target?.toString() ?? '';

    if (_isEntityMethodCall(target, methodName)) {
      final code = LintCode(
        name: 'entity_boundary_isolation',
        problemMessage: 'Entity method $methodName called in ${layer.name} layer',
        correctionMessage: 'Entity methods should only be called from domain layer.',
      );
      reporter.atNode(node, code);
    }
  }

  EntityViolationType _getEntityViolationType(ArchitecturalLayer layer, String methodName) {
    switch (layer.name) {
      case 'controller':
        return EntityViolationType(
          'Controller receives Entity',
          'Convert Entity to Request DTO in controller',
        );
      case 'presenter':
        return EntityViolationType(
          'Presenter handles Entity',
          'Convert Entity to Response DTO for presenter',
        );
      case 'adapter':
        return EntityViolationType(
          'Adapter processes Entity',
          'Use adapter-specific DTOs instead of entities',
        );
      case 'infrastructure':
        return EntityViolationType(
          'Infrastructure layer accesses Entity',
          'Convert Entity to persistence model in infrastructure',
        );
      default:
        return EntityViolationType(
          'Entity leaked to outer layer',
          'Convert Entity to appropriate DTO for boundary crossing',
        );
    }
  }

  // Helper methods for type classification
  ArchitecturalLayer? _detectLayer(String filePath) {
    if (filePath.contains('/domain/')) return ArchitecturalLayer('domain', 4);
    if (filePath.contains('/usecases/') || filePath.contains('/use_cases/')) {
      return ArchitecturalLayer('use_case', 3);
    }
    if (filePath.contains('/controllers/')) return ArchitecturalLayer('controller', 2);
    if (filePath.contains('/presenters/')) return ArchitecturalLayer('presenter', 2);
    if (filePath.contains('/adapters/')) return ArchitecturalLayer('adapter', 2);
    if (filePath.contains('/infrastructure/')) return ArchitecturalLayer('infrastructure', 1);
    if (filePath.contains('/data/')) return ArchitecturalLayer('data', 1);
    return null;
  }

  bool _isDomainLayer(ArchitecturalLayer layer) {
    return layer.name == 'domain' || layer.name == 'use_case';
  }

  bool _isEntityType(String typeName) {
    // Entity indicators
    final entityIndicators = ['Entity', 'Aggregate', 'AggregateRoot', 'DomainEntity'];

    if (entityIndicators.any((indicator) => typeName.contains(indicator))) {
      return true;
    }

    // Check for domain model patterns
    return _isDomainModelClass(typeName) && !_isDataTransferObject(typeName);
  }

  bool _isValueObjectType(String typeName) {
    final valueObjectIndicators = ['ValueObject', 'Value', 'Id', 'Identifier'];

    return valueObjectIndicators.any((indicator) => typeName.contains(indicator)) || _hasValueObjectPattern(typeName);
  }

  bool _isDomainAggregateType(String typeName) {
    final aggregateIndicators = ['Aggregate', 'AggregateRoot', 'Root'];

    return aggregateIndicators.any((indicator) => typeName.contains(indicator));
  }

  bool _isEntityCollectionType(String typeName) {
    return (typeName.startsWith('List<') || typeName.startsWith('Set<') || typeName.startsWith('Collection<')) &&
        _containsEntityType(typeName);
  }

  bool _isEntityAggregateType(String typeName) {
    return _isDomainAggregateType(typeName) || _isEntityType(typeName);
  }

  bool _isEntityInterface(String interfaceName) {
    final entityInterfaceIndicators = ['IEntity', 'EntityInterface', 'DomainEntity', 'Aggregate'];

    return entityInterfaceIndicators.any((indicator) => interfaceName.contains(indicator));
  }

  bool _isDomainModelClass(String typeName) {
    // Heuristic: domain model classes often have business-oriented names
    final businessTerms = [
      'User',
      'Order',
      'Product',
      'Customer',
      'Account',
      'Payment',
      'Invoice',
      'Contract',
      'Policy'
    ];

    return businessTerms.any((term) => typeName.contains(term)) &&
        !typeName.contains('DTO') &&
        !typeName.contains('Request') &&
        !typeName.contains('Response');
  }

  bool _isDataTransferObject(String typeName) {
    final dtoIndicators = ['DTO', 'Data', 'Request', 'Response', 'Command', 'Query'];

    return dtoIndicators.any((indicator) => typeName.contains(indicator));
  }

  bool _hasValueObjectPattern(String typeName) {
    // Value objects often end with specific suffixes
    final valueObjectSuffixes = ['Id', 'Code', 'Number', 'Address', 'Email', 'Phone'];

    return valueObjectSuffixes.any((suffix) => typeName.endsWith(suffix));
  }

  bool _containsEntityType(String typeName) {
    // Extract generic type parameter and check if it's an entity
    final genericMatch = RegExp(r'<(\w+)>').firstMatch(typeName);
    if (genericMatch != null) {
      final genericType = genericMatch.group(1)!;
      return _isEntityType(genericType);
    }
    return false;
  }

  bool _containsEntityInstantiation(String bodyString) {
    final entityInstantiationPatterns = [
      'new Entity',
      'new.*Entity',
      r'Entity\(',
      'new.*Aggregate',
      r'AggregateRoot\('
    ];

    return entityInstantiationPatterns.any((pattern) => RegExp(pattern).hasMatch(bodyString));
  }

  bool _containsEntityStateModification(String bodyString) {
    final stateModificationPatterns = ['\\.set', '\\.update', '\\.change', '\\.modify', '\\.apply', '\\.assign'];

    return stateModificationPatterns.any((pattern) => RegExp(pattern).hasMatch(bodyString));
  }

  bool _containsEntityBusinessRuleInvocation(String bodyString) {
    final businessRulePatterns = [
      '\\.validate',
      '\\.check',
      '\\.verify',
      '\\.enforce',
      '\\.calculatee',
      '\\.compute',
      '\\.evaluate'
    ];

    return businessRulePatterns.any((pattern) => RegExp(pattern).hasMatch(bodyString));
  }

  bool _isEntityReference(String target) {
    final entityReferencePatterns = ['entity', 'aggregate', 'domainObject', 'businessObject'];

    return entityReferencePatterns.any((pattern) => target.toLowerCase().contains(pattern));
  }

  bool _isEntityMethodCall(String target, String methodName) {
    return _isEntityReference(target) &&
        (methodName.contains('validate') ||
            methodName.contains('calculate') ||
            methodName.contains('apply') ||
            methodName.contains('process'));
  }
}

class ArchitecturalLayer {
  final String name;
  final int level;

  ArchitecturalLayer(this.name, this.level);
}

class EntityViolationType {
  final String description;
  final String correction;

  EntityViolationType(this.description, this.correction);
}
