import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Enforces proper DataSource implementation patterns in the data layer.
///
/// This rule ensures that DataSource classes:
/// - Follow proper naming conventions
/// - Implement external system communication patterns
/// - Return data models (not domain entities)
/// - Handle network/database/cache operations appropriately
/// - Properly handle errors and exceptions
///
/// DataSources are responsible for:
/// - Fetching data from external sources (API, Database, Cache)
/// - Converting external responses to data models
/// - Handling low-level errors and retries
/// - Managing connection and authentication details
class DataSourceNamingRule extends DartLintRule {
  const DataSourceNamingRule() : super(code: _code);

  static const _code = LintCode(
    name: 'datasource_implementation',
    problemMessage:
        'DataSource must properly implement external system communication patterns.',
    correctionMessage:
        'Ensure DataSource handles external communications, returns data models, and follows naming conventions.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((node) {
      _checkDataSourceImplementation(node, reporter, resolver);
    });

    context.registry.addImportDirective((node) {
      _checkDataSourceImports(node, reporter, resolver);
    });
  }

  void _checkDataSourceImplementation(
    ClassDeclaration node,
    DiagnosticReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;

    // Only check files in data layer datasource directory
    if (!_isDataSourceFile(filePath)) return;

    final className = node.name.lexeme;

    // Check naming convention
    if (!_hasValidDataSourceSuffix(className)) {
      final code = LintCode(
        name: 'datasource_implementation',
        problemMessage: 'DataSource class "$className" doesn\'t follow naming convention',
        correctionMessage: 'Use suffix like "RemoteDataSource", "LocalDataSource", or "CacheDataSource"',
      );
      reporter.atNode(node, code);
    }

    // Analyze DataSource implementation
    final analysis = _analyzeDataSourceClass(node);

    // Check for external communication patterns
    _checkExternalCommunication(analysis, reporter, className);

    // Check return types (should be data models, not entities)
    _checkReturnTypes(analysis, reporter, className);

    // Check for proper error handling
    _checkErrorHandling(analysis, reporter, className);
  }

  void _checkDataSourceImports(
    ImportDirective node,
    DiagnosticReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    if (!_isDataSourceFile(filePath)) return;

    final importUri = node.uri.stringValue;
    if (importUri == null) return;

    // DataSource should not import domain entities directly
    if (importUri.contains('/domain/entities/') ||
        importUri.contains('/domain/models/')) {
      final code = LintCode(
        name: 'datasource_implementation',
        problemMessage: 'DataSource should not import domain entities directly',
        correctionMessage: 'Use data models instead of domain entities in DataSource',
      );
      reporter.atNode(node, code);
    }
  }

  DataSourceAnalysis _analyzeDataSourceClass(ClassDeclaration node) {
    final methods = <MethodDeclaration>[];
    final fields = <FieldDeclaration>[];
    bool hasHttpClient = false;
    bool hasDatabase = false;
    bool hasCache = false;
    bool hasErrorHandling = false;

    for (final member in node.members) {
      if (member is MethodDeclaration) {
        methods.add(member);

        // Check for error handling patterns
        final bodyString = member.body.toString();
        if (bodyString.contains('try') ||
            bodyString.contains('catch') ||
            bodyString.contains('.catchError')) {
          hasErrorHandling = true;
        }
      } else if (member is FieldDeclaration) {
        fields.add(member);

        final type = member.fields.type;
        if (type is NamedType) {
          final typeName = type.name.lexeme;
          if (_isHttpClientType(typeName)) hasHttpClient = true;
          if (_isDatabaseType(typeName)) hasDatabase = true;
          if (_isCacheType(typeName)) hasCache = true;
        }
      }
    }

    return DataSourceAnalysis(
      methods: methods,
      fields: fields,
      hasHttpClient: hasHttpClient,
      hasDatabase: hasDatabase,
      hasCache: hasCache,
      hasErrorHandling: hasErrorHandling,
    );
  }

  void _checkExternalCommunication(
    DataSourceAnalysis analysis,
    DiagnosticReporter reporter,
    String className,
  ) {
    // Check if DataSource has any external communication mechanism
    if (!analysis.hasHttpClient && !analysis.hasDatabase && !analysis.hasCache) {
      bool hasExternalCalls = false;

      // Check methods for external communication patterns
      for (final method in analysis.methods) {
        final bodyString = method.body.toString();
        if (_containsExternalCommunication(bodyString)) {
          hasExternalCalls = true;
          break;
        }
      }

      if (!hasExternalCalls) {
        final code = LintCode(
          name: 'datasource_implementation',
          problemMessage: 'DataSource "$className" doesn\'t communicate with external systems',
          correctionMessage: 'DataSource should fetch data from API, Database, or Cache',
        );
        reporter.atNode(analysis.methods.firstOrNull ?? analysis.fields.first, code);
      }
    }
  }

  void _checkReturnTypes(
    DataSourceAnalysis analysis,
    DiagnosticReporter reporter,
    String className,
  ) {
    for (final method in analysis.methods) {
      final returnType = method.returnType;
      if (returnType is NamedType) {
        final typeName = returnType.name.lexeme;

        // Check if returning domain entities instead of data models
        if (_isDomainEntityType(typeName)) {
          final code = LintCode(
            name: 'datasource_implementation',
            problemMessage: 'DataSource method returns domain entity: $typeName',
            correctionMessage: 'Return data models instead of domain entities from DataSource',
          );
          reporter.atNode(returnType, code);
        }
      }
    }
  }

  void _checkErrorHandling(
    DataSourceAnalysis analysis,
    DiagnosticReporter reporter,
    String className,
  ) {
    if (!analysis.hasErrorHandling && analysis.methods.isNotEmpty) {
      final code = LintCode(
        name: 'datasource_implementation',
        problemMessage: 'DataSource "$className" lacks proper error handling',
        correctionMessage: 'Add try-catch blocks to handle network/database errors',
      );
      reporter.atNode(analysis.methods.first, code);
    }
  }

  bool _isDataSourceFile(String filePath) {
    return (filePath.contains('/data/') || filePath.contains('\\data\\')) &&
        (filePath.contains('/datasources/') ||
            filePath.contains('\\datasources\\') ||
            filePath.contains('datasource'));
  }

  bool _hasValidDataSourceSuffix(String className) {
    final validSuffixes = [
      'DataSource',
      'RemoteDataSource',
      'LocalDataSource',
      'ApiDataSource',
      'CacheDataSource',
      'DatabaseDataSource',
    ];

    return validSuffixes.any((suffix) => className.endsWith(suffix));
  }

  bool _isHttpClientType(String typeName) {
    final httpTypes = [
      'Client', 'HttpClient', 'Dio', 'Http',
      'RestClient', 'ApiClient', 'NetworkClient'
    ];
    return httpTypes.any((type) => typeName.contains(type));
  }

  bool _isDatabaseType(String typeName) {
    final dbTypes = [
      'Database', 'DB', 'Sqlite', 'Hive', 'Box',
      'DatabaseExecutor', 'DatabaseClient'
    ];
    return dbTypes.any((type) => typeName.contains(type));
  }

  bool _isCacheType(String typeName) {
    final cacheTypes = [
      'Cache', 'SharedPreferences', 'Storage',
      'CacheManager', 'CacheClient'
    ];
    return cacheTypes.any((type) => typeName.contains(type));
  }

  bool _containsExternalCommunication(String bodyString) {
    final patterns = [
      '.get(', '.post(', '.put(', '.delete(', '.patch(',
      'http.', 'dio.', 'client.',
      'query(', 'rawQuery(', 'execute(',
      'getApplicationDocumentsDirectory',
      'SharedPreferences.getInstance',
    ];
    return patterns.any((pattern) => bodyString.contains(pattern));
  }

  bool _isDomainEntityType(String typeName) {
    // Check if type name suggests it's a domain entity
    return typeName.endsWith('Entity') ||
           typeName.endsWith('ValueObject') ||
           typeName.endsWith('DomainModel') ||
           (!typeName.endsWith('Model') &&
            !typeName.endsWith('DTO') &&
            !typeName.endsWith('Response') &&
            !typeName.endsWith('Request') &&
            !typeName.contains('List') &&
            !typeName.contains('Map') &&
            !typeName.contains('Future') &&
            !typeName.contains('Stream'));
  }
}

class DataSourceAnalysis {
  final List<MethodDeclaration> methods;
  final List<FieldDeclaration> fields;
  final bool hasHttpClient;
  final bool hasDatabase;
  final bool hasCache;
  final bool hasErrorHandling;

  DataSourceAnalysis({
    required this.methods,
    required this.fields,
    required this.hasHttpClient,
    required this.hasDatabase,
    required this.hasCache,
    required this.hasErrorHandling,
  });
}
