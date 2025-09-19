import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Enforces that database details remain isolated in the framework layer.
///
/// This rule ensures that database is treated as a detail:
/// - Database-specific code should only exist in framework layer
/// - SQL should be restricted to framework layer
/// - Database schemas should not leak to inner layers
/// - Database connections should be managed in framework layer
/// - Inner layers should use abstractions, never direct database access
///
/// Database as a detail means:
/// - No SQL in business logic
/// - No database schema knowledge in inner layers
/// - No database connection management in business logic
/// - Database can be replaced without affecting inner layers
class DatabaseDetailRule extends DartLintRule {
  const DatabaseDetailRule() : super(code: _code);

  static const _code = LintCode(
    name: 'database_detail',
    problemMessage:
        'Database is a detail and must be isolated to framework layer.',
    correctionMessage:
        'Move database-specific code to framework layer. Use repository abstractions in inner layers.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addImportDirective((node) {
      _checkDatabaseImports(node, reporter, resolver);
    });

    context.registry.addClassDeclaration((node) {
      _checkDatabaseClass(node, reporter, resolver);
    });

    context.registry.addMethodDeclaration((node) {
      _checkDatabaseMethod(node, reporter, resolver);
    });

    context.registry.addVariableDeclaration((node) {
      _checkDatabaseVariable(node, reporter, resolver);
    });
  }

  void _checkDatabaseImports(
    ImportDirective node,
    DiagnosticReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    final importUri = node.uri.stringValue;
    if (importUri == null) return;

    if (_isDatabaseImport(importUri)) {
      if (!_isFrameworkLayer(filePath)) {
        final layerType = _getLayerType(filePath);
        final code = LintCode(
          name: 'database_detail',
          problemMessage: 'Database import leaked into $layerType layer: $importUri',
          correctionMessage:
              'Move database dependencies to framework layer. Use repository abstractions in $layerType layer.',
        );
        reporter.atNode(node, code);
      }
    }
  }

  void _checkDatabaseClass(
    ClassDeclaration node,
    DiagnosticReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    final className = node.name.lexeme;

    if (_isFrameworkLayer(filePath)) {
      // In framework layer - check for business logic leakage
      _checkFrameworkDatabaseClass(node, reporter);
    } else {
      // In inner layers - check for database details
      _checkInnerLayerDatabaseClass(node, reporter, filePath);
    }
  }

  void _checkDatabaseMethod(
    MethodDeclaration method,
    DiagnosticReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    final methodName = method.name.lexeme;

    if (!_isFrameworkLayer(filePath)) {
      // Check for SQL or database operations in inner layers
      if (_containsSQLOperation(method, methodName)) {
        final layerType = _getLayerType(filePath);
        final code = LintCode(
          name: 'database_detail',
          problemMessage: 'SQL operation found in $layerType layer: $methodName',
          correctionMessage:
              'Move SQL operations to framework layer. Use repository methods in $layerType layer.',
        );
        reporter.atNode(method, code);
      }

      if (_containsDatabaseOperation(method, methodName)) {
        final layerType = _getLayerType(filePath);
        final code = LintCode(
          name: 'database_detail',
          problemMessage: 'Database operation found in $layerType layer: $methodName',
          correctionMessage:
              'Move database operations to framework layer. Use abstractions in $layerType layer.',
        );
        reporter.atNode(method, code);
      }
    } else {
      // In framework layer - check for business logic in database code
      if (_containsBusinessLogicInDatabase(method, methodName)) {
        final code = LintCode(
          name: 'database_detail',
          problemMessage: 'Business logic found in database code: $methodName',
          correctionMessage:
              'Move business logic to appropriate inner layer. Database code should only handle persistence.',
        );
        reporter.atNode(method, code);
      }
    }
  }

  void _checkDatabaseVariable(
    VariableDeclaration node,
    DiagnosticReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;

    if (!_isFrameworkLayer(filePath)) {
      // Check for SQL strings in inner layers
      final initializer = node.initializer;
      if (initializer is StringLiteral) {
        final value = initializer.stringValue;
        if (value != null && _containsSQL(value)) {
          final layerType = _getLayerType(filePath);
          final code = LintCode(
            name: 'database_detail',
            problemMessage: 'SQL string found in $layerType layer',
            correctionMessage:
                'Move SQL strings to framework layer. Use repository methods instead.',
          );
          reporter.atNode(node, code);
        }
      }
    }
  }

  void _checkFrameworkDatabaseClass(
    ClassDeclaration node,
    DiagnosticReporter reporter,
  ) {
    // Check for business logic in database classes
    for (final member in node.members) {
      if (member is MethodDeclaration) {
        final methodName = member.name.lexeme;

        if (_containsBusinessLogicInDatabase(member, methodName)) {
          final code = LintCode(
            name: 'database_detail',
            problemMessage: 'Database class contains business logic: $methodName',
            correctionMessage:
                'Move business logic to inner layers. Database should only handle persistence details.',
          );
          reporter.atNode(member, code);
        }
      }
    }

    // Check for domain knowledge in database schema
    _checkDatabaseSchemaDesign(node, reporter);
  }

  void _checkInnerLayerDatabaseClass(
    ClassDeclaration node,
    DiagnosticReporter reporter,
    String filePath,
  ) {
    final className = node.name.lexeme;
    final layerType = _getLayerType(filePath);

    // Check for database class names in inner layers
    if (_isDatabaseClassName(className)) {
      final code = LintCode(
        name: 'database_detail',
        problemMessage: 'Database class found in $layerType layer: $className',
        correctionMessage:
            'Move database classes to framework layer. Use repository abstractions in $layerType layer.',
      );
      reporter.atNode(node, code);
    }

    // Check for database field dependencies
    for (final member in node.members) {
      if (member is FieldDeclaration) {
        final type = member.fields.type;
        if (type is NamedType) {
          final typeName = type.name.lexeme;
          if (_isDatabaseType(typeName)) {
            final code = LintCode(
              name: 'database_detail',
              problemMessage: '$layerType class depends on database type: $typeName',
              correctionMessage:
                  'Use repository abstractions instead of direct database dependencies.',
            );
            reporter.atNode(type, code);
          }
        }
      }
    }
  }

  void _checkDatabaseSchemaDesign(
    ClassDeclaration node,
    DiagnosticReporter reporter,
  ) {
    // Check if database schema reflects domain model too closely
    for (final member in node.members) {
      if (member is MethodDeclaration) {
        final methodName = member.name.lexeme;

        // Look for domain-specific validation in database layer
        if (_containsDomainValidation(member, methodName)) {
          final code = LintCode(
            name: 'database_detail',
            problemMessage: 'Database contains domain validation: $methodName',
            correctionMessage:
                'Move domain validation to entity or use case. Database should only enforce storage constraints.',
          );
          reporter.atNode(member, code);
        }
      }
    }
  }

  bool _containsSQLOperation(MethodDeclaration method, String methodName) {
    final sqlPatterns = [
      'select', 'insert', 'update', 'delete',
      'create', 'drop', 'alter', 'sql',
      'query', 'execute',
    ];

    final hasSQLName = sqlPatterns.any((pattern) =>
        methodName.toLowerCase().contains(pattern));

    if (hasSQLName) return true;

    // Check method body for SQL
    final body = method.body;
    if (body is BlockFunctionBody) {
      final bodyString = body.toString().toLowerCase();
      return _containsSQL(bodyString);
    }

    return false;
  }

  bool _containsDatabaseOperation(MethodDeclaration method, String methodName) {
    final dbOperationPatterns = [
      'connection', 'transaction', 'commit', 'rollback',
      'database', 'table', 'schema', 'index',
      'migrate', 'migration', 'seed',
    ];

    return dbOperationPatterns.any((pattern) =>
        methodName.toLowerCase().contains(pattern));
  }

  bool _containsBusinessLogicInDatabase(MethodDeclaration method, String methodName) {
    final businessLogicPatterns = [
      'validate', 'calculate', 'process', 'apply',
      'business', 'rule', 'policy', 'workflow',
      'approve', 'reject', 'authorize',
    ];

    return businessLogicPatterns.any((pattern) =>
        methodName.toLowerCase().contains(pattern));
  }

  bool _containsDomainValidation(MethodDeclaration method, String methodName) {
    final domainValidationPatterns = [
      'validateBusinessRule', 'checkDomainRule',
      'validateInvariant', 'enforcePolicy',
      'businessValidation', 'domainValidation',
    ];

    return domainValidationPatterns.any((pattern) =>
        methodName.toLowerCase().contains(pattern));
  }

  bool _containsSQL(String text) {
    final sqlKeywords = [
      'select ', 'from ', 'where ', 'insert into',
      'update ', 'delete from', 'create table',
      'drop table', 'alter table', 'join ',
      'inner join', 'left join', 'right join',
      'group by', 'order by', 'having ',
    ];

    final lowerText = text.toLowerCase();
    return sqlKeywords.any((keyword) => lowerText.contains(keyword));
  }

  bool _isDatabaseImport(String importUri) {
    final databaseImports = [
      'package:sqflite/',
      'package:drift/',
      'package:floor/',
      'package:hive/',
      'package:isar/',
      'package:realm/',
      'package:objectbox/',
      'package:mongo_dart/',
      'package:mysql1/',
      'package:postgres/',
      'package:sqlite3/',
    ];

    return databaseImports.any((db) => importUri.startsWith(db));
  }

  bool _isDatabaseClassName(String className) {
    final databaseClassNames = [
      'Database', 'Connection', 'Transaction',
      'Table', 'Schema', 'Migration',
      'SqlDatabase', 'NoSqlDatabase',
      'DatabaseManager', 'DatabaseHelper',
      'DatabaseClient', 'DatabaseAdapter',
    ];

    return databaseClassNames.any((name) => className.contains(name));
  }

  bool _isDatabaseType(String typeName) {
    final databaseTypes = [
      'Database', 'Connection', 'Transaction', 'Statement',
      'ResultSet', 'DataReader', 'DataWriter',
      'QueryBuilder', 'SqlBuilder', 'DatabaseContext',
      'Box', 'IsarCollection', 'RealmObject',
    ];

    return databaseTypes.any((type) => typeName.contains(type));
  }

  bool _isFrameworkLayer(String filePath) {
    final frameworkPaths = [
      '/framework/', '\\framework\\',
      '/frameworks/', '\\frameworks\\',
      '/infrastructure/', '\\infrastructure\\',
      '/persistence/', '\\persistence\\',
      '/database/', '\\database\\',
      '/storage/', '\\storage\\',
    ];

    return frameworkPaths.any((path) => filePath.contains(path));
  }

  String _getLayerType(String filePath) {
    if (filePath.contains('/domain/') || filePath.contains('\\domain\\')) {
      return 'domain';
    }
    if (filePath.contains('/adapters/') || filePath.contains('\\adapters\\') ||
        filePath.contains('/interface_adapters/') || filePath.contains('\\interface_adapters\\')) {
      return 'adapter';
    }
    if (filePath.contains('/data/') || filePath.contains('\\data\\')) {
      return 'data';
    }
    if (filePath.contains('/presentation/') || filePath.contains('\\presentation\\') ||
        filePath.contains('/ui/') || filePath.contains('\\ui\\')) {
      return 'presentation';
    }
    return 'unknown';
  }
}