import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../clean_architecture_linter_base.dart';

/// Enforces proper Data Transfer Object (DTO) patterns for boundary crossing.
///
/// Uncle Bob: "You can use basic structs or simple Data Transfer objects if
/// you like. Or the data can simply be arguments in function calls. Or you
/// can pack it into a hashmap, or construct it into an object. The important
/// thing is that isolated, simple, data structures are passed across the
/// boundaries."
///
/// This rule enforces:
/// - DTOs are simple, isolated data structures
/// - No business logic in DTOs
/// - DTOs are immutable for consistency
/// - Proper DTO naming conventions
/// - DTOs contain only primitive types or other DTOs
/// - No framework dependencies in DTOs
/// - DTOs are convenient for the inner circle
///
/// DTO design patterns enforced:
/// - Request DTOs for inbound data
/// - Response DTOs for outbound data
/// - Command DTOs for actions
/// - Query DTOs for read operations
/// - Event DTOs for domain events
class DTOBoundaryPatternRule extends CleanArchitectureLintRule {
  const DTOBoundaryPatternRule() : super(code: _code);

  static const _code = LintCode(
    name: 'dto_boundary_pattern',
    problemMessage: 'DTO boundary pattern violation: {0}',
    correctionMessage: 'Follow DTO design patterns for proper boundary data transfer.',
  );

  @override
  void runRule(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((node) {
      _analyzeDTOClass(node, reporter, resolver);
    });

    context.registry.addMethodDeclaration((node) {
      _analyzeDTOUsage(node, reporter, resolver);
    });

    context.registry.addConstructorDeclaration((node) {
      _analyzeDTOConstructor(node, reporter, resolver);
    });
  }

  void _analyzeDTOClass(
    ClassDeclaration node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    final className = node.name.lexeme;
    final layer = _detectLayer(filePath);

    if (layer == null) return;

    if (_isDTOClass(className)) {
      _validateDTODesign(node, reporter, layer, className);
      _validateDTOResponsibilities(node, reporter, className);
      _validateDTODependencies(node, reporter, className);
      _validateDTOImmutability(node, reporter, className);
      _validateDTONaming(node, reporter, className);
    }

    // Check if class should be a DTO
    _checkShouldBeDTO(node, reporter, layer, className);
  }

  void _analyzeDTOUsage(
    MethodDeclaration method,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    final layer = _detectLayer(filePath);
    if (layer == null) return;

    final methodName = method.name.lexeme;

    // Check if method should use DTOs
    if (_isBoundaryMethod(layer, methodName)) {
      _validateBoundaryMethodDTOUsage(method, reporter, layer, methodName);
    }

    // Check DTO transformation patterns
    _validateDTOTransformationPatterns(method, reporter, layer, methodName);
  }

  void _analyzeDTOConstructor(
    ConstructorDeclaration constructor,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    final layer = _detectLayer(filePath);
    if (layer == null) return;

    // Find parent class
    AstNode? parent = constructor.parent;
    while (parent != null && parent is! ClassDeclaration) {
      parent = parent.parent;
    }

    if (parent is ClassDeclaration) {
      final className = parent.name.lexeme;

      if (_isDTOClass(className)) {
        _validateDTOConstructorPattern(constructor, reporter, className);
      }
    }
  }

  void _validateDTODesign(
    ClassDeclaration node,
    ErrorReporter reporter,
    ArchitecturalLayer layer,
    String className,
  ) {
    // Check DTO structure
    _validateDTOStructure(node, reporter, className);

    // Check DTO fields
    _validateDTOFields(node, reporter, className);

    // Check DTO methods
    _validateDTOMethods(node, reporter, className);

    // Check DTO inheritance
    _validateDTOInheritance(node, reporter, className);
  }

  void _validateDTOStructure(
    ClassDeclaration node,
    ErrorReporter reporter,
    String className,
  ) {
    final fields = node.members.whereType<FieldDeclaration>();
    final methods = node.members.whereType<MethodDeclaration>();

    // Check if DTO is too complex
    if (fields.length > 15) {
      final code = LintCode(
        name: 'dto_boundary_pattern',
        problemMessage: 'DTO $className has too many fields (${fields.length})',
        correctionMessage: 'Consider breaking down into smaller, focused DTOs.',
      );
      reporter.atNode(node, code);
    }

    // Check for inappropriate method count
    final businessMethods = methods.where((m) => !_isAllowedDTOMethod(m.name.lexeme)).length;

    if (businessMethods > 2) {
      final code = LintCode(
        name: 'dto_boundary_pattern',
        problemMessage: 'DTO $className has too much behavior ($businessMethods methods)',
        correctionMessage: 'DTOs should be simple data containers with minimal behavior.',
      );
      reporter.atNode(node, code);
    }
  }

  void _validateDTOFields(
    ClassDeclaration node,
    ErrorReporter reporter,
    String className,
  ) {
    final fields = node.members.whereType<FieldDeclaration>();

    for (final field in fields) {
      final type = field.fields.type;
      if (type is NamedType) {
        final typeName = type.name2.lexeme;

        // Check for inappropriate field types
        if (_isInappropriateDTOFieldType(typeName)) {
          final code = LintCode(
            name: 'dto_boundary_pattern',
            problemMessage: 'DTO $className has inappropriate field type: $typeName',
            correctionMessage: 'Use primitive types, other DTOs, or simple collections in DTOs.',
          );
          reporter.atNode(field, code);
        }

        // Check for entity references
        if (_isEntityType(typeName)) {
          final code = LintCode(
            name: 'dto_boundary_pattern',
            problemMessage: 'DTO $className contains entity reference: $typeName',
            correctionMessage: 'Replace entity reference with entity ID or nested DTO.',
          );
          reporter.atNode(field, code);
        }

        // Check for framework dependencies
        if (_isFrameworkType(typeName)) {
          final code = LintCode(
            name: 'dto_boundary_pattern',
            problemMessage: 'DTO $className depends on framework type: $typeName',
            correctionMessage: 'Remove framework dependencies from DTOs.',
          );
          reporter.atNode(field, code);
        }

        // Check for complex nested objects
        if (_isOverlyComplexType(typeName)) {
          final code = LintCode(
            name: 'dto_boundary_pattern',
            problemMessage: 'DTO $className has overly complex field: $typeName',
            correctionMessage: 'Simplify complex types or create separate DTOs.',
          );
          reporter.atNode(field, code);
        }
      }

      // Check field mutability
      if (!field.fields.isFinal && !field.fields.isLate) {
        final code = LintCode(
          name: 'dto_boundary_pattern',
          problemMessage: 'DTO $className has mutable field - DTOs should be immutable',
          correctionMessage: 'Make DTO fields final for immutable data transfer.',
        );
        reporter.atNode(field, code);
      }
    }
  }

  void _validateDTOMethods(
    ClassDeclaration node,
    ErrorReporter reporter,
    String className,
  ) {
    final methods = node.members.whereType<MethodDeclaration>();

    for (final method in methods) {
      final methodName = method.name.lexeme;

      // Check for business logic methods
      if (_isBusinessLogicMethod(methodName)) {
        final code = LintCode(
          name: 'dto_boundary_pattern',
          problemMessage: 'DTO $className contains business logic method: $methodName',
          correctionMessage: 'Move business logic to appropriate domain or use case layer.',
        );
        reporter.atNode(method, code);
      }

      // Check for inappropriate DTO methods
      if (!_isAllowedDTOMethod(methodName) && !_isUtilityMethod(methodName)) {
        final code = LintCode(
          name: 'dto_boundary_pattern',
          problemMessage: 'DTO $className has inappropriate method: $methodName',
          correctionMessage: 'DTOs should only have data access and utility methods.',
        );
        reporter.atNode(method, code);
      }

      // Check for stateful operations
      if (_isStatefulOperation(method)) {
        final code = LintCode(
          name: 'dto_boundary_pattern',
          problemMessage: 'DTO $className method $methodName performs stateful operations',
          correctionMessage: 'DTOs should be stateless data containers.',
        );
        reporter.atNode(method, code);
      }
    }
  }

  void _validateDTOInheritance(
    ClassDeclaration node,
    ErrorReporter reporter,
    String className,
  ) {
    final extendsClause = node.extendsClause;
    if (extendsClause != null) {
      final superclassName = extendsClause.superclass.name2.lexeme;

      if (!_isDTOClass(superclassName) && !_isAllowedDTOSuperclass(superclassName)) {
        final code = LintCode(
          name: 'dto_boundary_pattern',
          problemMessage: 'DTO $className extends non-DTO class: $superclassName',
          correctionMessage: 'DTOs should only extend other DTOs or allowed base classes.',
        );
        reporter.atNode(extendsClause, code);
      }
    }
  }

  void _validateDTOResponsibilities(
    ClassDeclaration node,
    ErrorReporter reporter,
    String className,
  ) {
    final dtoType = _classifyDTOType(className);

    switch (dtoType) {
      case DTOType.request:
        _validateRequestDTOPattern(node, reporter, className);
        break;
      case DTOType.response:
        _validateResponseDTOPattern(node, reporter, className);
        break;
      case DTOType.command:
        _validateCommandDTOPattern(node, reporter, className);
        break;
      case DTOType.query:
        _validateQueryDTOPattern(node, reporter, className);
        break;
      case DTOType.event:
        _validateEventDTOPattern(node, reporter, className);
        break;
      case DTOType.generic:
        _validateGenericDTOPattern(node, reporter, className);
        break;
    }
  }

  void _validateDTODependencies(
    ClassDeclaration node,
    ErrorReporter reporter,
    String className,
  ) {
    // Check imports in the file
    final compilationUnit = node.thisOrAncestorOfType<CompilationUnit>();
    if (compilationUnit != null) {
      for (final directive in compilationUnit.directives) {
        if (directive is ImportDirective) {
          final importUri = directive.uri.stringValue;
          if (importUri != null && _isInappropriateDTOImport(importUri)) {
            final code = LintCode(
              name: 'dto_boundary_pattern',
              problemMessage: 'DTO file imports inappropriate dependency: $importUri',
              correctionMessage: 'DTOs should only import primitive types and other DTOs.',
            );
            reporter.atNode(directive, code);
          }
        }
      }
    }
  }

  void _validateDTOImmutability(
    ClassDeclaration node,
    ErrorReporter reporter,
    String className,
  ) {
    // Check for setters
    final methods = node.members.whereType<MethodDeclaration>();
    for (final method in methods) {
      if (method.isSetter) {
        final code = LintCode(
          name: 'dto_boundary_pattern',
          problemMessage: 'DTO $className has setter - DTOs should be immutable',
          correctionMessage: 'Remove setters and use constructor or copyWith for data setting.',
        );
        reporter.atNode(method, code);
      }
    }

    // Check for methods that modify state
    for (final method in methods) {
      if (_modifiesState(method)) {
        final code = LintCode(
          name: 'dto_boundary_pattern',
          problemMessage: 'DTO $className method ${method.name.lexeme} modifies state',
          correctionMessage: 'DTOs should be immutable - return new instance instead of modifying.',
        );
        reporter.atNode(method, code);
      }
    }
  }

  void _validateDTONaming(
    ClassDeclaration node,
    ErrorReporter reporter,
    String className,
  ) {
    if (!_hasProperDTONaming(className)) {
      final dtoType = _classifyDTOType(className);
      final code = LintCode(
        name: 'dto_boundary_pattern',
        problemMessage: 'DTO $className should follow naming convention for ${dtoType.name}',
        correctionMessage: _getDTONamingAdvice(dtoType),
      );
      reporter.atNode(node, code);
    }
  }

  void _validateBoundaryMethodDTOUsage(
    MethodDeclaration method,
    ErrorReporter reporter,
    ArchitecturalLayer layer,
    String methodName,
  ) {
    // Check parameters
    final parameters = method.parameters?.parameters ?? [];
    var hasDTOParameter = false;
    var hasInappropriateParameter = false;

    for (final param in parameters) {
      if (param is SimpleFormalParameter) {
        final type = param.type;
        if (type is NamedType) {
          final typeName = type.name2.lexeme;

          if (_isDTOClass(typeName)) {
            hasDTOParameter = true;
          } else if (_shouldBeDTOForBoundary(typeName, layer)) {
            hasInappropriateParameter = true;
          }
        }
      }
    }

    // Check return type
    final returnType = method.returnType;
    var hasDTOReturn = false;
    var hasInappropriateReturn = false;

    if (returnType is NamedType) {
      final typeName = returnType.name2.lexeme;

      if (_isDTOClass(typeName)) {
        hasDTOReturn = true;
      } else if (_shouldBeDTOForBoundary(typeName, layer)) {
        hasInappropriateReturn = true;
      }
    }

    // Report violations
    if (hasInappropriateParameter && !hasDTOParameter) {
      final code = LintCode(
        name: 'dto_boundary_pattern',
        problemMessage: 'Boundary method $methodName should use DTOs for parameters',
        correctionMessage: 'Create appropriate DTOs for boundary data transfer.',
      );
      reporter.atNode(method, code);
    }

    if (hasInappropriateReturn && !hasDTOReturn) {
      final code = LintCode(
        name: 'dto_boundary_pattern',
        problemMessage: 'Boundary method $methodName should return DTO',
        correctionMessage: 'Return DTO instead of entity or complex object.',
      );
      reporter.atNode(method, code);
    }
  }

  void _validateDTOTransformationPatterns(
    MethodDeclaration method,
    ErrorReporter reporter,
    ArchitecturalLayer layer,
    String methodName,
  ) {
    // Check for proper DTO transformation patterns
    if (_isTransformationMethod(methodName)) {
      _validateTransformationImplementation(method, reporter, methodName);
    }

    // Check for missing DTO transformations
    if (_needsDTOTransformation(method, layer)) {
      final code = LintCode(
        name: 'dto_boundary_pattern',
        problemMessage: 'Method $methodName should include DTO transformation',
        correctionMessage: 'Add proper DTO to entity or entity to DTO transformation.',
      );
      reporter.atNode(method, code);
    }
  }

  void _validateDTOConstructorPattern(
    ConstructorDeclaration constructor,
    ErrorReporter reporter,
    String className,
  ) {
    // Check for proper DTO constructor patterns
    final parameters = constructor.parameters.parameters;

    if (parameters.isEmpty) {
      final code = LintCode(
        name: 'dto_boundary_pattern',
        problemMessage: 'DTO $className has empty constructor - should initialize all fields',
        correctionMessage: 'Provide constructor parameters for all DTO fields.',
      );
      reporter.atNode(constructor, code);
    }

    // Check for validation in constructor
    if (_hasValidationInConstructor(constructor)) {
      final code = LintCode(
        name: 'dto_boundary_pattern',
        problemMessage: 'DTO $className constructor contains validation logic',
        correctionMessage: 'Move validation to domain layer - DTOs should be simple data containers.',
      );
      reporter.atNode(constructor, code);
    }
  }

  // DTO Type-specific validation methods
  void _validateRequestDTOPattern(
    ClassDeclaration node,
    ErrorReporter reporter,
    String className,
  ) {
    // Request DTOs should contain input data for operations
    _checkRequestDTOFields(node, reporter, className);
  }

  void _validateResponseDTOPattern(
    ClassDeclaration node,
    ErrorReporter reporter,
    String className,
  ) {
    // Response DTOs should contain output data
    _checkResponseDTOFields(node, reporter, className);
  }

  void _validateCommandDTOPattern(
    ClassDeclaration node,
    ErrorReporter reporter,
    String className,
  ) {
    // Command DTOs should represent actions
    _checkCommandDTOStructure(node, reporter, className);
  }

  void _validateQueryDTOPattern(
    ClassDeclaration node,
    ErrorReporter reporter,
    String className,
  ) {
    // Query DTOs should represent read operations
    _checkQueryDTOStructure(node, reporter, className);
  }

  void _validateEventDTOPattern(
    ClassDeclaration node,
    ErrorReporter reporter,
    String className,
  ) {
    // Event DTOs should represent domain events
    _checkEventDTOStructure(node, reporter, className);
  }

  void _validateGenericDTOPattern(
    ClassDeclaration node,
    ErrorReporter reporter,
    String className,
  ) {
    // Generic DTOs should follow general DTO principles
    _checkGenericDTOStructure(node, reporter, className);
  }

  void _checkShouldBeDTO(
    ClassDeclaration node,
    ErrorReporter reporter,
    ArchitecturalLayer layer,
    String className,
  ) {
    // Check if class is used for boundary crossing but isn't properly structured as DTO
    if (_isUsedForBoundaryCrossing(node, layer) && !_isDTOClass(className)) {
      final code = LintCode(
        name: 'dto_boundary_pattern',
        problemMessage: 'Class $className is used for boundary crossing but is not structured as DTO',
        correctionMessage: 'Restructure as proper DTO or create separate DTO for boundary crossing.',
      );
      reporter.atNode(node, code);
    }
  }

  // Helper methods
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

  bool _isDTOClass(String className) {
    final dtoIndicators = ['DTO', 'Data', 'Request', 'Response', 'Command', 'Query', 'Message', 'Payload', 'Event'];
    return dtoIndicators.any((indicator) => className.contains(indicator));
  }

  DTOType _classifyDTOType(String className) {
    if (className.contains('Request')) return DTOType.request;
    if (className.contains('Response')) return DTOType.response;
    if (className.contains('Command')) return DTOType.command;
    if (className.contains('Query')) return DTOType.query;
    if (className.contains('Event')) return DTOType.event;
    return DTOType.generic;
  }

  bool _isBoundaryMethod(ArchitecturalLayer layer, String methodName) {
    final boundaryIndicators = ['handle', 'process', 'execute', 'present', 'convert', 'transform'];
    return boundaryIndicators.any((indicator) => methodName.contains(indicator));
  }

  bool _isInappropriateDTOFieldType(String typeName) {
    final inappropriateTypes = ['Service', 'Repository', 'Manager', 'Handler', 'Context', 'Connection', 'Session'];
    return inappropriateTypes.any((type) => typeName.contains(type));
  }

  bool _isEntityType(String typeName) {
    final entityIndicators = ['Entity', 'Aggregate', 'ValueObject', 'DomainObject'];
    return entityIndicators.any((indicator) => typeName.contains(indicator));
  }

  bool _isFrameworkType(String typeName) {
    final frameworkTypes = ['HttpRequest', 'HttpResponse', 'Context', 'Intent', 'Bundle', 'Activity', 'Fragment'];
    return frameworkTypes.any((type) => typeName.contains(type));
  }

  bool _isOverlyComplexType(String typeName) {
    return typeName.contains('Builder') || typeName.contains('Factory') || typeName.contains('Manager');
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

  bool _isUtilityMethod(String methodName) {
    final utilityMethods = ['isEmpty', 'isValid', 'hasValue', 'isPresent'];
    return utilityMethods.any((method) => methodName.contains(method));
  }

  bool _isStatefulOperation(MethodDeclaration method) {
    final body = method.body;
    final bodyString = body.toString();
    return bodyString.contains('this.') &&
        (bodyString.contains(' = ') || bodyString.contains('add(') || bodyString.contains('remove('));
  }

  bool _isAllowedDTOSuperclass(String superclassName) {
    final allowedSuperclasses = ['Object', 'Equatable', 'Serializable'];
    return allowedSuperclasses.contains(superclassName);
  }

  bool _hasProperDTONaming(String className) {
    final dtoSuffixes = ['DTO', 'Data', 'Request', 'Response', 'Command', 'Query', 'Event'];
    return dtoSuffixes.any((suffix) => className.endsWith(suffix));
  }

  String _getDTONamingAdvice(DTOType type) {
    switch (type) {
      case DTOType.request:
        return 'Use "Request" suffix for input DTOs (e.g., CreateUserRequest)';
      case DTOType.response:
        return 'Use "Response" suffix for output DTOs (e.g., UserResponse)';
      case DTOType.command:
        return 'Use "Command" suffix for action DTOs (e.g., CreateUserCommand)';
      case DTOType.query:
        return 'Use "Query" suffix for read DTOs (e.g., GetUserQuery)';
      case DTOType.event:
        return 'Use "Event" suffix for domain events (e.g., UserCreatedEvent)';
      case DTOType.generic:
        return 'Use "DTO" or "Data" suffix for generic DTOs (e.g., UserDTO)';
    }
  }

  bool _shouldBeDTOForBoundary(String typeName, ArchitecturalLayer layer) {
    return _isEntityType(typeName) || _isFrameworkType(typeName);
  }

  bool _isInappropriateDTOImport(String importUri) {
    final inappropriateImports = ['/domain/entities/', '/domain/services/', '/infrastructure/', '/database/', '/http/'];
    return inappropriateImports.any((import) => importUri.contains(import));
  }

  bool _modifiesState(MethodDeclaration method) {
    final body = method.body;
    final bodyString = body.toString();
    return bodyString.contains('this.') && bodyString.contains(' = ');
  }

  bool _isTransformationMethod(String methodName) {
    final transformationMethods = ['toDTO', 'fromDTO', 'toEntity', 'fromEntity', 'transform', 'convert', 'map'];
    return transformationMethods.any((method) => methodName.contains(method));
  }

  bool _needsDTOTransformation(MethodDeclaration method, ArchitecturalLayer layer) {
    // Check if method crosses boundaries but doesn't transform data
    return _isBoundaryMethod(layer, method.name.lexeme) && !_hasTransformationLogic(method);
  }

  bool _hasTransformationLogic(MethodDeclaration method) {
    final body = method.body;
    final bodyString = body.toString();
    final transformationPatterns = ['toDTO', 'fromDTO', 'toEntity', 'fromEntity'];
    return transformationPatterns.any((pattern) => bodyString.contains(pattern));
  }

  bool _hasValidationInConstructor(ConstructorDeclaration constructor) {
    final body = constructor.body;
    final bodyString = body.toString();
    final validationPatterns = ['if (', 'throw ', 'assert', 'validate', 'check'];
    return validationPatterns.any((pattern) => bodyString.contains(pattern));
  }

  bool _isUsedForBoundaryCrossing(ClassDeclaration node, ArchitecturalLayer layer) {
    // This would require more complex analysis to determine actual usage
    // For now, we'll use heuristics based on class structure
    final methods = node.members.whereType<MethodDeclaration>();
    return methods.any((method) => _isBoundaryMethod(layer, method.name.lexeme));
  }

  void _validateTransformationImplementation(
    MethodDeclaration method,
    ErrorReporter reporter,
    String methodName,
  ) {
    // Validate that transformation methods follow proper patterns
    final body = method.body;
    final bodyString = body.toString();

    if (!_hasProperTransformationPattern(bodyString)) {
      final code = LintCode(
        name: 'dto_boundary_pattern',
        problemMessage: 'Transformation method $methodName lacks proper transformation pattern',
        correctionMessage: 'Implement proper field-by-field transformation between DTO and entity.',
      );
      reporter.atNode(method, code);
    }
  }

  bool _hasProperTransformationPattern(String bodyString) {
    // Check for field assignments or constructor calls
    return bodyString.contains('=') || bodyString.contains('(');
  }

  // Placeholder methods for DTO type-specific validations
  void _checkRequestDTOFields(ClassDeclaration node, ErrorReporter reporter, String className) {}
  void _checkResponseDTOFields(ClassDeclaration node, ErrorReporter reporter, String className) {}
  void _checkCommandDTOStructure(ClassDeclaration node, ErrorReporter reporter, String className) {}
  void _checkQueryDTOStructure(ClassDeclaration node, ErrorReporter reporter, String className) {}
  void _checkEventDTOStructure(ClassDeclaration node, ErrorReporter reporter, String className) {}
  void _checkGenericDTOStructure(ClassDeclaration node, ErrorReporter reporter, String className) {}
}

class ArchitecturalLayer {
  final String name;
  final int level;

  ArchitecturalLayer(this.name, this.level);
}

enum DTOType {
  request,
  response,
  command,
  query,
  event,
  generic,
}
