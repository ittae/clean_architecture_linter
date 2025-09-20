import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Enforces proper dependency injection patterns in UI components.
///
/// This rule ensures that UI components follow Clean Architecture principles
/// by receiving dependencies through proper injection mechanisms rather than
/// creating them directly.
///
/// Violations detected:
/// - Direct instantiation of domain/data layer classes in UI
/// - Missing dependency injection setup
/// - Improper service locator usage
/// - Hard-coded dependencies
///
/// Recommended patterns:
/// - Constructor injection
/// - Provider pattern (provider package)
/// - Service locator pattern (get_it package)
/// - Riverpod dependency injection
/// - Injectable/auto_route DI
/// - Manual dependency passing through widget tree
///
/// UI components should:
/// - Receive dependencies through constructors
/// - Use dependency injection frameworks
/// - Access services through proper abstractions
/// - Avoid direct instantiation of business logic
class UiDependencyInjectionRule extends DartLintRule {
  const UiDependencyInjectionRule() : super(code: _code);

  static const _code = LintCode(
    name: 'ui_dependency_injection',
    problemMessage:
        'UI component violates dependency injection principles.',
    correctionMessage:
        'Use proper dependency injection patterns for accessing business logic.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((node) {
      _checkUIConstructorUsage(node, reporter, resolver);
    });

    context.registry.addClassDeclaration((node) {
      _checkDependencyInjectionSetup(node, reporter, resolver);
    });

    context.registry.addMethodInvocation((node) {
      _checkServiceLocatorUsage(node, reporter, resolver);
    });

    context.registry.addImportDirective((node) {
      _checkDependencyImports(node, reporter, resolver);
    });
  }

  void _checkUIConstructorUsage(
    InstanceCreationExpression node,
    DiagnosticReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;

    // Only check files in presentation layer
    if (!_isPresentationLayerFile(filePath)) return;

    final constructorName = node.constructorName.type.name.lexeme;

    // Check if creating instances of domain or data layer classes directly
    if (_isDomainOrDataLayerClass(constructorName)) {
      final violationType = _getViolationType(constructorName);
      final code = _createSpecificLintCode(violationType, constructorName);
      reporter.atNode(node, code);
    }
  }

  void _checkDependencyInjectionSetup(
    ClassDeclaration node,
    DiagnosticReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    if (!_isPresentationLayerFile(filePath)) return;

    final className = node.name.lexeme;
    if (!_isUIComponent(className, node)) return;

    final analysis = _analyzeDependencyInjection(node);

    // Check if UI component has business dependencies but no DI setup
    if (analysis.hasBusinessDependencies && !analysis.hasDependencyInjection) {
      final code = LintCode(
        name: 'ui_dependency_injection',
        problemMessage: 'UI component "$className" has business dependencies without proper DI setup',
        correctionMessage: 'Set up dependency injection using Provider, GetIt, Riverpod, or constructor injection.',
      );
      reporter.atNode(node, code);
    }

    // Check for hard-coded dependencies
    for (final violation in analysis.hardCodedDependencies) {
      final code = LintCode(
        name: 'ui_dependency_injection',
        problemMessage: 'Hard-coded dependency: ${violation.dependencyName}',
        correctionMessage: 'Inject "${violation.dependencyName}" through dependency injection instead of hard-coding.',
      );
      reporter.atNode(violation.node, code);
    }
  }

  void _checkServiceLocatorUsage(
    MethodInvocation node,
    DiagnosticReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    if (!_isPresentationLayerFile(filePath)) return;

    final methodName = node.methodName.name;
    final target = node.target?.toString() ?? '';

    // Check for improper service locator usage
    if (_isServiceLocatorCall(methodName, target)) {
      // Check if it's in build method (not recommended)
      if (_isInBuildMethod(node)) {
        final code = LintCode(
          name: 'ui_dependency_injection',
          problemMessage: 'Service locator call in build method: $methodName',
          correctionMessage: 'Move service locator calls to initState() or use Provider.of() in build method.',
        );
        reporter.atNode(node, code);
      }

      // Check for missing error handling
      if (!_hasProperErrorHandling(node)) {
        final code = LintCode(
          name: 'ui_dependency_injection',
          problemMessage: 'Service locator call without error handling',
          correctionMessage: 'Add try-catch or use service locator with proper error handling.',
        );
        reporter.atNode(node, code);
      }
    }
  }

  void _checkDependencyImports(
    ImportDirective node,
    DiagnosticReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    if (!_isPresentationLayerFile(filePath)) return;

    final importUri = node.uri.stringValue;
    if (importUri == null) return;

    // Check for direct domain/data imports in widget files
    if (_isWidgetFile(filePath) && _isBusinessLayerImport(importUri)) {
      // Allow if it's for type annotations only
      if (!_isTypeOnlyImport(node)) {
        final code = LintCode(
          name: 'ui_dependency_injection',
          problemMessage: 'Widget directly imports business layer: $importUri',
          correctionMessage: 'Access business logic through dependency injection, not direct imports.',
        );
        reporter.atNode(node, code);
      }
    }
  }

  bool _isPresentationLayerFile(String filePath) {
    return filePath.contains('/presentation/') ||
        filePath.contains('\\presentation\\') ||
        filePath.contains('/ui/') ||
        filePath.contains('\\ui\\') ||
        filePath.contains('/widgets/') ||
        filePath.contains('\\widgets\\') ||
        filePath.contains('/pages/') ||
        filePath.contains('\\pages\\') ||
        filePath.contains('/screens/') ||
        filePath.contains('\\screens\\');
  }

  DependencyInjectionAnalysis _analyzeDependencyInjection(ClassDeclaration node) {
    final fields = <FieldDeclaration>[];
    final constructors = <ConstructorDeclaration>[];
    final hardCodedDependencies = <HardCodedDependency>[];
    bool hasBusinessDependencies = false;
    bool hasDependencyInjection = false;

    for (final member in node.members) {
      if (member is FieldDeclaration) {
        fields.add(member);

        // Check if field is a business dependency
        final type = member.fields.type;
        if (type is NamedType && _isBusinessDependencyType(type.name.lexeme)) {
          hasBusinessDependencies = true;

          // Check if it's properly injected or hard-coded
          for (final variable in member.fields.variables) {
            final initializer = variable.initializer;
            if (initializer is InstanceCreationExpression) {
              hardCodedDependencies.add(HardCodedDependency(
                dependencyName: type.name.lexeme,
                node: initializer,
              ));
            }
          }
        }

        // Check for DI framework fields
        if (_isDependencyInjectionField(member)) {
          hasDependencyInjection = true;
        }
      } else if (member is ConstructorDeclaration) {
        constructors.add(member);

        // Check constructor parameters for dependency injection
        if (_hasInjectedParameters(member)) {
          hasDependencyInjection = true;
        }
      }
    }

    return DependencyInjectionAnalysis(
      hasBusinessDependencies: hasBusinessDependencies,
      hasDependencyInjection: hasDependencyInjection,
      hardCodedDependencies: hardCodedDependencies,
      fields: fields,
      constructors: constructors,
    );
  }

  bool _isDomainOrDataLayerClass(String className) {
    // Common patterns for domain/data layer classes that shouldn't be instantiated in UI
    final domainDataPatterns = [
      'UseCase', 'Repository', 'DataSource', 'Service',
      'ApiService', 'NetworkService', 'DatabaseService',
      'AuthService', 'StorageService', 'CacheService'
    ];

    return domainDataPatterns.any((pattern) => className.contains(pattern)) ||
        _isHttpClientClass(className) ||
        _isDatabaseClass(className);
  }

  bool _isHttpClientClass(String className) {
    final httpClientPatterns = ['HttpClient', 'Dio', 'Client', 'ApiClient', 'RestClient'];
    return httpClientPatterns.any((pattern) => className.contains(pattern));
  }

  bool _isDatabaseClass(String className) {
    final databasePatterns = ['Database', 'Dao', 'Hive', 'Sqlite', 'Realm'];
    return databasePatterns.any((pattern) => className.contains(pattern));
  }

  bool _isBusinessDependencyType(String typeName) {
    return _isDomainOrDataLayerClass(typeName);
  }

  bool _isDependencyInjectionField(FieldDeclaration field) {
    // Check for DI framework annotations or types
    final annotations = field.metadata;
    for (final annotation in annotations) {
      final annotationName = annotation.name.name;
      if (_isDIAnnotation(annotationName)) {
        return true;
      }
    }

    // Check field type for DI patterns
    final type = field.fields.type;
    if (type is NamedType) {
      final typeName = type.name.lexeme;
      return _isDIType(typeName);
    }

    return false;
  }

  bool _isDIAnnotation(String annotationName) {
    final diAnnotations = ['Inject', 'Injectable', 'Singleton', 'LazySingleton'];
    return diAnnotations.contains(annotationName);
  }

  bool _isDIType(String typeName) {
    final diTypes = ['Provider', 'Consumer', 'Selector', 'StateProvider'];
    return diTypes.any((type) => typeName.contains(type));
  }

  bool _hasInjectedParameters(ConstructorDeclaration constructor) {
    final parameters = constructor.parameters;

    for (final param in parameters.parameters) {
      if (param is SimpleFormalParameter) {
        final type = param.type;
        if (type is NamedType && _isBusinessDependencyType(type.name.lexeme)) {
          return true;
        }
      }
    }
    return false;
  }

  bool _isUIComponent(String className, ClassDeclaration node) {
    // Check class name patterns
    final uiSuffixes = ['Widget', 'Page', 'Screen', 'View', 'Component', 'Dialog'];
    if (uiSuffixes.any((suffix) => className.endsWith(suffix))) {
      return true;
    }

    // Check inheritance
    final extendsClause = node.extendsClause;
    if (extendsClause != null) {
      final superclass = extendsClause.superclass.name.lexeme;
      return _isFlutterWidgetClass(superclass);
    }

    return false;
  }

  bool _isFlutterWidgetClass(String className) {
    final widgetClasses = [
      'StatelessWidget', 'StatefulWidget', 'InheritedWidget',
      'PreferredSizeWidget', 'SingleChildRenderObjectWidget',
      'MultiChildRenderObjectWidget', 'LeafRenderObjectWidget'
    ];
    return widgetClasses.contains(className) || className.endsWith('Widget');
  }

  DependencyViolationType _getViolationType(String className) {
    if (_isHttpClientClass(className)) {
      return DependencyViolationType.httpClient;
    } else if (_isDatabaseClass(className)) {
      return DependencyViolationType.database;
    } else if (className.contains('Repository')) {
      return DependencyViolationType.repository;
    } else if (className.contains('UseCase')) {
      return DependencyViolationType.useCase;
    } else if (className.contains('Service')) {
      return DependencyViolationType.service;
    }
    return DependencyViolationType.general;
  }

  LintCode _createSpecificLintCode(DependencyViolationType type, String className) {
    switch (type) {
      case DependencyViolationType.httpClient:
        return LintCode(
          name: 'ui_dependency_injection',
          problemMessage: 'Direct HTTP client instantiation in UI: $className',
          correctionMessage: 'Inject HTTP client through DI container or use repository pattern.',
        );
      case DependencyViolationType.database:
        return LintCode(
          name: 'ui_dependency_injection',
          problemMessage: 'Direct database instantiation in UI: $className',
          correctionMessage: 'Access database through repository pattern with proper DI.',
        );
      case DependencyViolationType.repository:
        return LintCode(
          name: 'ui_dependency_injection',
          problemMessage: 'Direct repository instantiation in UI: $className',
          correctionMessage: 'Inject repository through constructor or DI container.',
        );
      case DependencyViolationType.useCase:
        return LintCode(
          name: 'ui_dependency_injection',
          problemMessage: 'Direct UseCase instantiation in UI: $className',
          correctionMessage: 'Inject UseCase through dependency injection.',
        );
      case DependencyViolationType.service:
        return LintCode(
          name: 'ui_dependency_injection',
          problemMessage: 'Direct service instantiation in UI: $className',
          correctionMessage: 'Inject service through DI container or service locator.',
        );
      case DependencyViolationType.general:
        return LintCode(
          name: 'ui_dependency_injection',
          problemMessage: 'Direct business layer instantiation in UI: $className',
          correctionMessage: 'Use dependency injection instead of direct instantiation.',
        );
    }
  }

  bool _isServiceLocatorCall(String methodName, String target) {
    // GetIt pattern
    if (target.contains('GetIt') || target.contains('getIt') || target.contains('sl')) {
      return ['get', 'call', '[]'].contains(methodName);
    }

    // Provider pattern service locator calls
    if (methodName == 'read' || methodName == 'watch') {
      return true;
    }

    return false;
  }

  bool _isInBuildMethod(MethodInvocation node) {
    var parent = node.parent;
    while (parent != null) {
      if (parent is MethodDeclaration && parent.name.lexeme == 'build') {
        return true;
      }
      parent = parent.parent;
    }
    return false;
  }

  bool _hasProperErrorHandling(MethodInvocation node) {
    // Check if the call is wrapped in try-catch or has null safety
    var parent = node.parent;
    while (parent != null) {
      if (parent is TryStatement) {
        return true;
      }
      parent = parent.parent;
    }

    // Check for null-aware operators
    final parentExpression = node.parent;
    if (parentExpression is PropertyAccess && parentExpression.operator.lexeme == '?.') {
      return true;
    }

    return false;
  }

  bool _isWidgetFile(String filePath) {
    return filePath.contains('widget') ||
           filePath.contains('page') ||
           filePath.contains('screen') ||
           filePath.contains('view');
  }

  bool _isBusinessLayerImport(String importUri) {
    return importUri.contains('/domain/') ||
           importUri.contains('/data/') ||
           importUri.contains('repository') ||
           importUri.contains('usecase') ||
           importUri.contains('service');
  }

  bool _isTypeOnlyImport(ImportDirective importDirective) {
    // Check if import has 'show' clause with only type names
    for (final combinator in importDirective.combinators) {
      if (combinator is ShowCombinator) {
        // If all shown names are type names (start with capital letter), it's likely type-only
        return combinator.shownNames.every((name) =>
          name.name.startsWith(RegExp(r'[A-Z]'))
        );
      }
    }

    return false;
  }
}

/// Analysis classes and enums
class DependencyInjectionAnalysis {
  final bool hasBusinessDependencies;
  final bool hasDependencyInjection;
  final List<HardCodedDependency> hardCodedDependencies;
  final List<FieldDeclaration> fields;
  final List<ConstructorDeclaration> constructors;

  DependencyInjectionAnalysis({
    required this.hasBusinessDependencies,
    required this.hasDependencyInjection,
    required this.hardCodedDependencies,
    required this.fields,
    required this.constructors,
  });
}

class HardCodedDependency {
  final String dependencyName;
  final AstNode node;

  HardCodedDependency({
    required this.dependencyName,
    required this.node,
  });
}

enum DependencyViolationType {
  httpClient,
  database,
  repository,
  useCase,
  service,
  general,
}

