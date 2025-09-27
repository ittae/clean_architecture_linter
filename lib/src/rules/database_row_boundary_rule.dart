import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Prevents database row structures from violating boundary crossing rules.
///
/// Uncle Bob: "For example, many database frameworks return a convenient data
/// format in response to a query. We might call this a RowStructure. We don't
/// want to pass that row structure inwards across a boundary. That would
/// violate The Dependency Rule because it would force an inner circle to know
/// something about an outer circle."
///
/// This rule enforces:
/// - Database rows don't cross inward boundaries
/// - RowStructure objects are converted before passing inward
/// - Query results are transformed to domain-convenient formats
/// - Database-specific types remain in infrastructure layer
/// - ORM objects don't leak to inner layers
/// - ResultSet objects are converted to DTOs
///
/// Specific violations detected:
/// - RowStructure passed to use cases
/// - ResultSet objects in domain layer
/// - ORM entities crossing boundaries
/// - Database query results in controllers
/// - Raw database objects in presenters
class DatabaseRowBoundaryRule extends DartLintRule {
  const DatabaseRowBoundaryRule() : super(code: _code);

  static const _code = LintCode(
    name: 'database_row_boundary',
    problemMessage: 'Database row boundary violation: {0}',
    correctionMessage: 'Convert database row to format convenient for inner circle.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((node) {
      _analyzeMethodDatabaseRowUsage(node, reporter, resolver);
    });

    context.registry.addVariableDeclaration((node) {
      _analyzeVariableDatabaseRowUsage(node, reporter, resolver);
    });

    context.registry.addFieldDeclaration((node) {
      _analyzeFieldDatabaseRowUsage(node, reporter, resolver);
    });

    context.registry.addMethodInvocation((node) {
      _analyzeMethodCallDatabaseRowPassing(node, reporter, resolver);
    });

    context.registry.addClassDeclaration((node) {
      _analyzeClassDatabaseRowDependency(node, reporter, resolver);
    });
  }

  void _analyzeMethodDatabaseRowUsage(
    MethodDeclaration method,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    final layer = _detectLayer(filePath);
    if (layer == null) return;

    final methodName = method.name.lexeme;

    // Check method parameters for database row violations
    _checkMethodParametersForDatabaseRows(method, reporter, layer, methodName);

    // Check return type for database row violations
    _checkMethodReturnTypeForDatabaseRows(method, reporter, layer, methodName);

    // Check method body for database row handling
    _checkMethodBodyDatabaseRowHandling(method, reporter, layer, methodName);
  }

  void _analyzeVariableDatabaseRowUsage(
    VariableDeclaration variable,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    final layer = _detectLayer(filePath);
    if (layer == null) return;

    final parent = variable.parent;
    if (parent is VariableDeclarationList) {
      final type = parent.type;
      if (type is NamedType) {
        final typeName = type.name2.lexeme;

        if (_isDatabaseRowType(typeName) && _isInnerLayer(layer)) {
          final code = LintCode(
            name: 'database_row_boundary',
            problemMessage: 'Database row type $typeName used in ${layer.name} layer variable',
            correctionMessage: 'Convert database row to appropriate DTO for ${layer.name} layer.',
          );
          reporter.atNode(variable, code);
        }
      }
    }
  }

  void _analyzeFieldDatabaseRowUsage(
    FieldDeclaration field,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    final layer = _detectLayer(filePath);
    if (layer == null) return;

    final type = field.fields.type;
    if (type is NamedType) {
      final typeName = type.name2.lexeme;

      if (_isDatabaseRowType(typeName) && _isInnerLayer(layer)) {
        final code = LintCode(
          name: 'database_row_boundary',
          problemMessage: 'Database row type $typeName used as field in ${layer.name} layer',
          correctionMessage: 'Store converted data instead of raw database row.',
        );
        reporter.atNode(field, code);
      }

      if (_isORMEntityType(typeName) && _isInnerLayer(layer)) {
        final code = LintCode(
          name: 'database_row_boundary',
          problemMessage: 'ORM entity $typeName used as field in ${layer.name} layer',
          correctionMessage: 'Use domain entity or DTO instead of ORM entity.',
        );
        reporter.atNode(field, code);
      }
    }
  }

  void _analyzeMethodCallDatabaseRowPassing(
    MethodInvocation node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    final layer = _detectLayer(filePath);
    if (layer == null) return;

    final methodName = node.methodName.name;

    // Check for database row objects being passed to inner layers
    _checkDatabaseRowArgumentPassing(node, reporter, layer, methodName);

    // Check for database query method calls in wrong layers
    _checkDatabaseQueryCallsInWrongLayer(node, reporter, layer, methodName);
  }

  void _analyzeClassDatabaseRowDependency(
    ClassDeclaration node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    final className = node.name.lexeme;
    final layer = _detectLayer(filePath);

    if (layer == null) return;

    // Check if class handles database rows inappropriately
    _checkInappropriateDatabaseRowHandling(node, reporter, layer, className);

    // Check for ORM entity usage in wrong layers
    _checkORMEntityUsage(node, reporter, layer, className);

    // Check for database result processing in wrong layer
    _checkDatabaseResultProcessing(node, reporter, layer, className);
  }

  void _checkMethodParametersForDatabaseRows(
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

          if (_isDatabaseRowType(typeName)) {
            final violation = _getRowViolationType(layer, methodName);
            if (violation != null) {
              final code = LintCode(
                name: 'database_row_boundary',
                problemMessage: '${violation.description}: Database row $typeName in parameter $paramName',
                correctionMessage: violation.correction,
              );
              reporter.atNode(param, code);
            }
          }

          if (_isResultSetType(typeName) && _isInnerLayer(layer)) {
            final code = LintCode(
              name: 'database_row_boundary',
              problemMessage: 'ResultSet $typeName passed to ${layer.name} layer',
              correctionMessage: 'Convert ResultSet to DTOs before passing to inner layer.',
            );
            reporter.atNode(param, code);
          }

          if (_isQueryResultType(typeName) && _isInnerLayer(layer)) {
            final code = LintCode(
              name: 'database_row_boundary',
              problemMessage: 'Query result $typeName passed to ${layer.name} layer',
              correctionMessage: 'Transform query result to domain-convenient format.',
            );
            reporter.atNode(param, code);
          }
        }
      }
    }
  }

  void _checkMethodReturnTypeForDatabaseRows(
    MethodDeclaration method,
    ErrorReporter reporter,
    ArchitecturalLayer layer,
    String methodName,
  ) {
    final returnType = method.returnType;
    if (returnType is NamedType) {
      final typeName = returnType.name2.lexeme;

      if (_isDatabaseRowType(typeName) && _isInnerLayer(layer)) {
        final code = LintCode(
          name: 'database_row_boundary',
          problemMessage: 'Method returns database row $typeName from ${layer.name} layer',
          correctionMessage: 'Return DTO or domain object instead of database row.',
        );
        reporter.atNode(method, code);
      }

      if (_isORMEntityType(typeName) && _isInnerLayer(layer)) {
        final code = LintCode(
          name: 'database_row_boundary',
          problemMessage: 'Method returns ORM entity $typeName from ${layer.name} layer',
          correctionMessage: 'Convert ORM entity to domain entity or DTO before returning.',
        );
        reporter.atNode(method, code);
      }

      if (_isDatabaseCollectionType(typeName) && _isInnerLayer(layer)) {
        final code = LintCode(
          name: 'database_row_boundary',
          problemMessage: 'Method returns database collection $typeName from ${layer.name} layer',
          correctionMessage: 'Convert database collection to domain-appropriate collection type.',
        );
        reporter.atNode(method, code);
      }
    }
  }

  void _checkMethodBodyDatabaseRowHandling(
    MethodDeclaration method,
    ErrorReporter reporter,
    ArchitecturalLayer layer,
    String methodName,
  ) {
    final body = method.body;
    final bodyString = body.toString();

    // Check for direct RowStructure usage
    if (_containsRowStructureUsage(bodyString) && _isInnerLayer(layer)) {
      final code = LintCode(
        name: 'database_row_boundary',
        problemMessage: 'Method $methodName uses RowStructure directly in ${layer.name} layer',
        correctionMessage: 'Convert RowStructure to appropriate data format for inner layer.',
      );
      reporter.atNode(method, code);
    }

    // Check for ResultSet manipulation in wrong layer
    if (_containsResultSetManipulation(bodyString) && _isInnerLayer(layer)) {
      final code = LintCode(
        name: 'database_row_boundary',
        problemMessage: 'Method $methodName manipulates ResultSet in ${layer.name} layer',
        correctionMessage: 'Handle ResultSet in infrastructure layer, pass converted data.',
      );
      reporter.atNode(method, code);
    }

    // Check for database cursor operations
    if (_containsCursorOperations(bodyString) && _isInnerLayer(layer)) {
      final code = LintCode(
        name: 'database_row_boundary',
        problemMessage: 'Method $methodName performs cursor operations in ${layer.name} layer',
        correctionMessage: 'Handle database cursors in infrastructure layer only.',
      );
      reporter.atNode(method, code);
    }

    // Check for ORM query operations in wrong layer
    if (_containsORMQueryOperations(bodyString) && _isInnerLayer(layer)) {
      final code = LintCode(
        name: 'database_row_boundary',
        problemMessage: 'Method $methodName performs ORM operations in ${layer.name} layer',
        correctionMessage: 'Keep ORM operations in infrastructure layer, use repository pattern.',
      );
      reporter.atNode(method, code);
    }
  }

  void _checkDatabaseRowArgumentPassing(
    MethodInvocation node,
    ErrorReporter reporter,
    ArchitecturalLayer layer,
    String methodName,
  ) {
    // Check for obvious database row passing patterns
    final arguments = node.argumentList.arguments;

    for (final arg in arguments) {
      final argString = arg.toString();

      if (_isRowStructureArgument(argString) && _isCrossingInward(layer)) {
        final code = LintCode(
          name: 'database_row_boundary',
          problemMessage: 'RowStructure passed inward in method call: $methodName',
          correctionMessage: 'Convert RowStructure to DTO before passing to inner layer.',
        );
        reporter.atNode(arg, code);
      }

      if (_isResultSetArgument(argString) && _isInnerLayer(layer)) {
        final code = LintCode(
          name: 'database_row_boundary',
          problemMessage: 'ResultSet passed to inner layer method: $methodName',
          correctionMessage: 'Process ResultSet and pass extracted data instead.',
        );
        reporter.atNode(arg, code);
      }
    }
  }

  void _checkDatabaseQueryCallsInWrongLayer(
    MethodInvocation node,
    ErrorReporter reporter,
    ArchitecturalLayer layer,
    String methodName,
  ) {
    if (_isInnerLayer(layer) && _isDatabaseQueryMethod(methodName)) {
      final code = LintCode(
        name: 'database_row_boundary',
        problemMessage: 'Database query method $methodName called in ${layer.name} layer',
        correctionMessage: 'Use repository interface instead of direct database queries.',
      );
      reporter.atNode(node, code);
    }
  }

  void _checkInappropriateDatabaseRowHandling(
    ClassDeclaration node,
    ErrorReporter reporter,
    ArchitecturalLayer layer,
    String className,
  ) {
    if (_isInnerLayer(layer)) {
      // Check for database row processing methods
      final methods = node.members.whereType<MethodDeclaration>();

      for (final method in methods) {
        final methodName = method.name.lexeme;

        if (_isRowProcessingMethod(methodName)) {
          final code = LintCode(
            name: 'database_row_boundary',
            problemMessage: 'Class $className in ${layer.name} layer processes database rows: $methodName',
            correctionMessage: 'Move database row processing to infrastructure layer.',
          );
          reporter.atNode(method, code);
        }
      }
    }
  }

  void _checkORMEntityUsage(
    ClassDeclaration node,
    ErrorReporter reporter,
    ArchitecturalLayer layer,
    String className,
  ) {
    if (_isInnerLayer(layer)) {
      // Check for ORM entity dependencies
      final fields = node.members.whereType<FieldDeclaration>();

      for (final field in fields) {
        final type = field.fields.type;
        if (type is NamedType) {
          final typeName = type.name2.lexeme;

          if (_isORMEntityType(typeName)) {
            final code = LintCode(
              name: 'database_row_boundary',
              problemMessage: 'Class $className depends on ORM entity $typeName in ${layer.name} layer',
              correctionMessage: 'Use domain entity or DTO instead of ORM entity.',
            );
            reporter.atNode(field, code);
          }

          if (_isORMCollectionType(typeName)) {
            final code = LintCode(
              name: 'database_row_boundary',
              problemMessage: 'Class $className uses ORM collection $typeName in ${layer.name} layer',
              correctionMessage: 'Convert ORM collection to domain collection type.',
            );
            reporter.atNode(field, code);
          }
        }
      }
    }
  }

  void _checkDatabaseResultProcessing(
    ClassDeclaration node,
    ErrorReporter reporter,
    ArchitecturalLayer layer,
    String className,
  ) {
    if (_isInnerLayer(layer)) {
      // Check for methods that suggest database result processing
      final methods = node.members.whereType<MethodDeclaration>();

      for (final method in methods) {
        final methodName = method.name.lexeme;

        if (_isDatabaseResultProcessingMethod(methodName)) {
          final code = LintCode(
            name: 'database_row_boundary',
            problemMessage: 'Class $className processes database results in ${layer.name} layer: $methodName',
            correctionMessage: 'Handle database result processing in infrastructure layer.',
          );
          reporter.atNode(method, code);
        }
      }
    }
  }

  RowViolationType? _getRowViolationType(ArchitecturalLayer layer, String methodName) {
    if (_isInnerLayer(layer)) {
      switch (layer.name) {
        case 'use_case':
          return RowViolationType(
            'Use case receives database row',
            'Convert database row to domain DTO in repository implementation',
          );
        case 'domain':
          return RowViolationType(
            'Domain layer receives database row',
            'Never pass database rows to domain - use pure domain objects',
          );
        case 'controller':
          return RowViolationType(
            'Controller receives database row',
            'Convert database row to request DTO in adapter layer',
          );
        case 'presenter':
          return RowViolationType(
            'Presenter receives database row',
            'Convert database row to response DTO before presenter',
          );
      }
    }
    return null;
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

  bool _isInnerLayer(ArchitecturalLayer layer) {
    return layer.level >= 2; // Controller level and above
  }

  bool _isCrossingInward(ArchitecturalLayer layer) {
    return layer.name == 'adapter' || layer.name == 'infrastructure';
  }

  bool _isDatabaseRowType(String typeName) {
    final rowTypes = ['Row', 'RowStructure', 'DataRow', 'DatabaseRow', 'TableRow', 'QueryRow', 'RecordRow'];
    return rowTypes.any((type) => typeName.contains(type));
  }

  bool _isResultSetType(String typeName) {
    final resultSetTypes = ['ResultSet', 'QueryResult', 'DatabaseResult', 'DataReader', 'RecordSet', 'CursorResult'];
    return resultSetTypes.any((type) => typeName.contains(type));
  }

  bool _isQueryResultType(String typeName) {
    final queryResultTypes = ['QueryResult', 'SqlResult', 'DatabaseQueryResult', 'SelectResult', 'FetchResult'];
    return queryResultTypes.any((type) => typeName.contains(type));
  }

  bool _isORMEntityType(String typeName) {
    final ormEntityTypes = [
      'Entity',
      'Model',
      'ActiveRecord',
      'DataModel',
      'PersistentObject',
      'ManagedObject',
      'JpaEntity'
    ];

    // ORM entities usually have ORM-specific annotations or patterns
    return ormEntityTypes.any((type) => typeName.contains(type)) && !_isDomainEntity(typeName);
  }

  bool _isDomainEntity(String typeName) {
    // Domain entities are usually in domain package/namespace
    return typeName.contains('Domain') || typeName.endsWith('Entity') && !typeName.contains('Data');
  }

  bool _isDatabaseCollectionType(String typeName) {
    return (typeName.startsWith('List<') || typeName.startsWith('Set<') || typeName.startsWith('Collection<')) &&
        _containsDatabaseRowType(typeName);
  }

  bool _isORMCollectionType(String typeName) {
    return (typeName.startsWith('List<') || typeName.startsWith('Set<') || typeName.startsWith('Collection<')) &&
        _containsORMEntityType(typeName);
  }

  bool _containsDatabaseRowType(String typeName) {
    final genericMatch = RegExp(r'<(\w+)>').firstMatch(typeName);
    if (genericMatch != null) {
      final genericType = genericMatch.group(1)!;
      return _isDatabaseRowType(genericType);
    }
    return false;
  }

  bool _containsORMEntityType(String typeName) {
    final genericMatch = RegExp(r'<(\w+)>').firstMatch(typeName);
    if (genericMatch != null) {
      final genericType = genericMatch.group(1)!;
      return _isORMEntityType(genericType);
    }
    return false;
  }

  bool _containsRowStructureUsage(String bodyString) {
    final rowPatterns = ['RowStructure', 'row.', 'dataRow.', 'tableRow.', 'rowData', 'rowValue'];
    return rowPatterns.any((pattern) => bodyString.contains(pattern));
  }

  bool _containsResultSetManipulation(String bodyString) {
    final resultSetPatterns = ['resultSet.', 'rs.next()', 'rs.getString(', 'result.next()', 'cursor.move'];
    return resultSetPatterns.any((pattern) => bodyString.contains(pattern));
  }

  bool _containsCursorOperations(String bodyString) {
    final cursorPatterns = ['cursor.', 'moveToNext()', 'moveToFirst()', 'getColumnIndex(', 'cursor.getPosition()'];
    return cursorPatterns.any((pattern) => bodyString.contains(pattern));
  }

  bool _containsORMQueryOperations(String bodyString) {
    final ormPatterns = ['em.find(', 'entityManager.', 'hibernate.', 'session.get(', 'query.from(', 'criteria.'];
    return ormPatterns.any((pattern) => bodyString.contains(pattern));
  }

  bool _isRowStructureArgument(String argString) {
    return argString.contains('RowStructure') || argString.contains('row') || argString.contains('dataRow');
  }

  bool _isResultSetArgument(String argString) {
    return argString.contains('ResultSet') || argString.contains('resultSet') || argString.contains('queryResult');
  }

  bool _isDatabaseQueryMethod(String methodName) {
    final queryMethods = ['query', 'select', 'find', 'search', 'fetch', 'execute', 'rawQuery', 'sqlQuery'];
    return queryMethods.any((method) => methodName.toLowerCase().contains(method));
  }

  bool _isRowProcessingMethod(String methodName) {
    final processingMethods = ['processRow', 'handleRow', 'convertRow', 'parseRow', 'extractRow', 'mapRow'];
    return processingMethods.any((method) => methodName.contains(method));
  }

  bool _isDatabaseResultProcessingMethod(String methodName) {
    final processingMethods = [
      'processResult',
      'handleResult',
      'convertResult',
      'parseResult',
      'extractResult',
      'mapResult',
      'processResultSet',
      'handleResultSet'
    ];
    return processingMethods.any((method) => methodName.contains(method));
  }
}

class ArchitecturalLayer {
  final String name;
  final int level;

  ArchitecturalLayer(this.name, this.level);
}

class RowViolationType {
  final String description;
  final String correction;

  RowViolationType(this.description, this.correction);
}
