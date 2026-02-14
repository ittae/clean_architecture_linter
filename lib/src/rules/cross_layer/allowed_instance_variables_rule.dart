import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../clean_architecture_linter_base.dart';

/// A lint rule that validates instance variables in UseCase, Repository, and DataSource classes
/// to ensure they only contain allowed dependencies according to Clean Architecture principles.
///
/// **Rules:**
/// - **UseCase**: Can only have `final` fields of types ending with `Repository`
/// - **Repository**: Can only have `final` fields of types ending with `DataSource`
/// - **DataSource**: Can only have `final` infrastructure dependencies (HTTP clients, DB clients, etc.)
///
/// **Examples:**
///
/// ✅ **Valid UseCase:**
/// ```dart
/// class GetTodoUseCase {
///   final TodoRepository repository;  // ✅ Repository dependency
///   const GetTodoUseCase(this.repository);
/// }
/// ```
///
/// ❌ **Invalid UseCase:**
/// ```dart
/// class GetTodoUseCase {
///   final TodoDataSource dataSource;  // ❌ Direct DataSource dependency
///   int callCount = 0;                 // ❌ Mutable state variable
/// }
/// ```
///
/// ✅ **Valid Repository:**
/// ```dart
/// class TodoRepositoryImpl implements TodoRepository {
///   final TodoRemoteDataSource remoteDataSource;  // ✅ DataSource dependency
///   final TodoLocalDataSource localDataSource;    // ✅ DataSource dependency
/// }
/// ```
///
/// ❌ **Invalid Repository:**
/// ```dart
/// class TodoRepositoryImpl implements TodoRepository {
///   final GetTodoUseCase useCase;  // ❌ UseCase dependency (wrong direction)
///   User? _cachedUser;             // ❌ Mutable state variable
/// }
/// ```
///
/// ✅ **Valid DataSource:**
/// ```dart
/// class TodoRemoteDataSource {
///   final Dio client;       // ✅ HTTP client
///   final String baseUrl;   // ✅ Configuration value
/// }
/// ```
class AllowedInstanceVariablesRule extends CleanArchitectureLintRule {
  const AllowedInstanceVariablesRule() : super(code: _defaultCode);

  // Default code, will be replaced with specific messages
  static const _defaultCode = LintCode(
    name: 'allowed_instance_variables',
    problemMessage: 'Invalid instance variable detected',
    correctionMessage:
        'Use correct dependencies per layer and ensure fields are final/const.',
  );

  @override
  void runRule(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((node) {
      _checkClassFields(node, reporter, resolver);
    });
  }

  void _checkClassFields(
    ClassDeclaration node,
    DiagnosticReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;

    // Skip generated, test files
    if (CleanArchitectureUtils.shouldExcludeFile(filePath)) return;

    final className = node.name.lexeme;

    // Identify class type
    final isUseCase = CleanArchitectureUtils.isUseCaseClass(className);
    final isRepository = CleanArchitectureUtils.isRepositoryImplClass(
      className,
    );
    final isDataSource =
        CleanArchitectureUtils.isDataSourceClass(className) &&
        node.abstractKeyword == null; // Only concrete DataSources

    if (!isUseCase && !isRepository && !isDataSource) return;

    // Check each field in the class
    for (final member in node.members) {
      if (member is FieldDeclaration) {
        // Check if field is final or const (both are immutable)
        final isFinal = member.fields.isFinal;
        final isConst = member.fields.isConst;
        final isImmutable = isFinal || isConst;

        for (final variable in member.fields.variables) {
          final fieldType = member.fields.type;

          if (fieldType is NamedType) {
            final typeName = fieldType.name.lexeme;

            // Validate based on class type
            if (isUseCase) {
              _validateUseCaseField(
                variable,
                typeName,
                isImmutable,
                reporter,
                className,
              );
            } else if (isRepository) {
              _validateRepositoryField(
                variable,
                typeName,
                isImmutable,
                reporter,
                className,
              );
            } else if (isDataSource) {
              _validateDataSourceField(
                variable,
                typeName,
                isImmutable,
                reporter,
                className,
              );
            }
          } else if (!isImmutable) {
            // Non-final fields without explicit type (var, dynamic)
            final classType =
                isUseCase
                    ? 'UseCase'
                    : isRepository
                    ? 'Repository'
                    : 'DataSource';
            final fieldName = variable.name.lexeme;

            final code = LintCode(
              name: 'allowed_instance_variables',
              problemMessage:
                  '$classType "$className" has mutable state variable "$fieldName". $classType classes must be stateless',
              correctionMessage:
                  'Use final/const. State belongs in Presentation layer.',
            );

            reporter.atNode(variable, code);
          }
        }
      }
    }
  }

  void _validateUseCaseField(
    VariableDeclaration variable,
    String typeName,
    bool isImmutable,
    DiagnosticReporter reporter,
    String className,
  ) {
    // UseCase should only have Repository and Service dependencies
    // Explicitly check for DataSource/Datasource to provide clear error
    final hasDataSourceDependency =
        typeName.endsWith('DataSource') || typeName.endsWith('Datasource');
    final hasRepositoryDependency = typeName.endsWith('Repository');
    final hasServiceDependency = typeName.endsWith('Service');

    // Allow Repository and Service (Domain layer services)
    if (!isImmutable ||
        (!hasRepositoryDependency && !hasServiceDependency) ||
        hasDataSourceDependency) {
      final fieldName = variable.name.lexeme;
      final problemMsg =
          isImmutable
              ? 'UseCase "$className" should only have Repository or Service dependencies. Found field "$fieldName" of type "$typeName"'
              : 'UseCase "$className" has mutable state variable "$fieldName" of type "$typeName". UseCase classes must be stateless';

      final code = LintCode(
        name: 'allowed_instance_variables',
        problemMessage: problemMsg,
        correctionMessage:
            'UseCase should depend on Repository or Service only. Use final/const.',
      );

      reporter.atNode(variable, code);
    }
  }

  void _validateRepositoryField(
    VariableDeclaration variable,
    String typeName,
    bool isImmutable,
    DiagnosticReporter reporter,
    String className,
  ) {
    // Repository should only have DataSource dependencies
    // Check both DataSource and Datasource variants (case variations)
    final hasUseCaseDependency =
        typeName.endsWith('UseCase') || typeName.endsWith('Usecase');
    final hasDataSourceDependency =
        typeName.endsWith('DataSource') || typeName.endsWith('Datasource');
    final isPrimitiveOrInfra = _isPrimitiveOrInfrastructureType(typeName);

    // Allow DataSource, primitives, and infrastructure types
    if (!isImmutable ||
        (!hasDataSourceDependency && !isPrimitiveOrInfra) ||
        hasUseCaseDependency) {
      final fieldName = variable.name.lexeme;
      final problemMsg =
          isImmutable
              ? 'Repository "$className" should only have DataSource or infrastructure dependencies. Found field "$fieldName" of type "$typeName"'
              : 'Repository "$className" has mutable state variable "$fieldName" of type "$typeName". Repository classes must be stateless';

      final code = LintCode(
        name: 'allowed_instance_variables',
        problemMessage: problemMsg,
        correctionMessage:
            'Repository should depend on DataSource or infrastructure only. Use final/const.',
      );

      reporter.atNode(variable, code);
    }
  }

  void _validateDataSourceField(
    VariableDeclaration variable,
    String typeName,
    bool isImmutable,
    DiagnosticReporter reporter,
    String className,
  ) {
    // DataSource should not have domain/business logic dependencies
    final isDisallowed = _isDisallowedDataSourceDependency(typeName);

    // Skip mutable state validation for Mock/Fake implementations
    final isMockOrFake =
        className.startsWith('Mock') || className.startsWith('Fake');

    // Allow mutable state for infrastructure SDK types
    // Reason: Some SDKs (Google Mobile Ads, in_app_purchase) require
    // holding references to SDK objects for lifecycle management
    final isInfrastructureType = _isPrimitiveOrInfrastructureType(typeName);

    // Error conditions:
    // 1. Mutable state that is NOT infrastructure type (and not Mock/Fake)
    // 2. Final field of disallowed type
    if ((!isImmutable && !isMockOrFake && !isInfrastructureType) ||
        (isImmutable && isDisallowed)) {
      final fieldName = variable.name.lexeme;
      final problemMsg =
          isImmutable
              ? 'DataSource "$className" should only have infrastructure dependencies. Found field "$fieldName" of type "$typeName"'
              : 'DataSource "$className" has mutable state variable "$fieldName" of type "$typeName". DataSource classes must be stateless';

      final code = LintCode(
        name: 'allowed_instance_variables',
        problemMessage: problemMsg,
        correctionMessage:
            'DataSource should depend on infrastructure only. Use final/const.',
      );

      reporter.atNode(variable, code);
    }
  }

  /// Checks if a type is a primitive or common infrastructure type
  bool _isPrimitiveOrInfrastructureType(String typeName) {
    // Dart primitives
    const primitives = {
      'String',
      'int',
      'double',
      'bool',
      'num',
      'List',
      'Map',
      'Set',
      'Iterable',
    };

    if (primitives.contains(typeName)) return true;

    // Common infrastructure types (Stream, Future, HTTP, DB, Firebase, etc.)
    const infrastructurePatterns = [
      'Stream',
      'Future',
      'Completer',
      'Sink',
      'Subscription', // StreamSubscription, etc.
      'Dio',
      'Client',
      'Firebase',
      'Firestore',
      'Database',
      'Cache',
      'Storage',
      'Messaging',
      'Http',
      // Google Mobile Ads SDK types
      'BannerAd',
      'InterstitialAd',
      'RewardedAd',
      'NativeAd',
      'AppOpenAd',
      'AdWidget',
      // In-App Purchase SDK types
      'InAppPurchase',
      'ProductDetails',
      'PurchaseDetails',
    ];

    return infrastructurePatterns.any((pattern) => typeName.contains(pattern));
  }

  /// Checks if a type is disallowed in DataSource classes
  bool _isDisallowedDataSourceDependency(String typeName) {
    // Allow primitives and infrastructure types
    if (_isPrimitiveOrInfrastructureType(typeName)) {
      return false;
    }

    // Disallow domain layer types (check both uppercase and lowercase variants)
    if (typeName.endsWith('UseCase') ||
        typeName.endsWith('Usecase') ||
        typeName.endsWith('Repository') ||
        typeName.endsWith('Entity') ||
        typeName.endsWith('DataSource') ||
        typeName.endsWith('Datasource')) {
      return true;
    }

    // Disallow business logic types (these should not be in DataSource)
    if (typeName.endsWith('Service') ||
        typeName.endsWith('Manager') ||
        typeName.endsWith('Controller')) {
      return true;
    }

    return false;
  }

  @override
  List<Fix> getFixes() => [];
}
