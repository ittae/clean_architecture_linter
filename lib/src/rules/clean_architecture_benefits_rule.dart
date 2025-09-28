import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../clean_architecture_linter_base.dart';

/// Validates that Clean Architecture benefits are preserved in the system.
///
/// Uncle Bob: "By separating the software into layers, and conforming to The
/// Dependency Rule, you will create a system that is intrinsically testable,
/// with all the benefits that implies. When any of the external parts of the
/// system become obsolete, like the database, or the web framework, you can
/// replace those obsolete elements with a minimum of fuss."
///
/// This rule ensures the system maintains:
/// - Intrinsic testability through proper separation
/// - Framework independence for easy replacement
/// - Database independence for technology changes
/// - UI independence for interface evolution
/// - External agency independence for service changes
/// - Minimal coupling between architectural layers
///
/// Benefits validated:
/// - Business logic is testable without external dependencies
/// - External components can be replaced without affecting core logic
/// - System remains flexible and maintainable
/// - Architecture supports long-term evolution
/// - Clean boundaries enable independent development
class CleanArchitectureBenefitsRule extends CleanArchitectureLintRule {
  const CleanArchitectureBenefitsRule() : super(code: _code);

  static const _code = LintCode(
    name: 'clean_architecture_benefits',
    problemMessage: 'Clean Architecture benefit violation: {0}',
    correctionMessage: 'Maintain Clean Architecture benefits by preserving proper layer separation.',
  );

  @override
  void runRule(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((node) {
      _analyzeClassArchitecturalBenefits(node, reporter, resolver);
    });

    context.registry.addMethodDeclaration((node) {
      _analyzeMethodTestability(node, reporter, resolver);
    });

    context.registry.addConstructorDeclaration((node) {
      _analyzeConstructorDependencies(node, reporter, resolver);
    });

    context.registry.addImportDirective((node) {
      _analyzeImportIndependence(node, reporter, resolver);
    });
  }

  void _analyzeClassArchitecturalBenefits(
    ClassDeclaration node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    final className = node.name.lexeme;
    final layer = _detectLayer(filePath);

    if (layer == null) return;

    // Check testability benefits
    _validateTestability(node, reporter, layer, className);

    // Check framework independence
    _validateFrameworkIndependence(node, reporter, layer, className);

    // Check replaceability of external components
    _validateExternalComponentReplaceability(node, reporter, layer, className);

    // Check business logic isolation
    _validateBusinessLogicIsolation(node, reporter, layer, className);
  }

  void _analyzeMethodTestability(
    MethodDeclaration method,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    final layer = _detectLayer(filePath);
    if (layer == null) return;

    final methodName = method.name.lexeme;

    // Check if business logic methods are intrinsically testable
    if (_isBusinessLogicMethod(method, layer)) {
      _validateIntrinsicTestability(method, reporter, layer, methodName);
    }

    // Check for hard-to-test patterns
    _checkHardToTestPatterns(method, reporter, layer, methodName);
  }

  void _analyzeConstructorDependencies(
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
      _validateConstructorForTestability(constructor, reporter, layer, className);
    }
  }

  void _analyzeImportIndependence(
    ImportDirective node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    final layer = _detectLayer(filePath);
    if (layer == null) return;

    final importUri = node.uri.stringValue;
    if (importUri == null) return;

    // Check for violations of independence benefits
    _validateImportIndependence(node, reporter, layer, importUri);
  }

  void _validateTestability(
    ClassDeclaration node,
    ErrorReporter reporter,
    ArchitecturalLayer layer,
    String className,
  ) {
    // Check if business logic classes are testable
    if (_containsBusinessLogic(node, layer)) {
      _checkBusinessLogicTestability(node, reporter, layer, className);
    }

    // Check for external dependencies that hurt testability
    _checkExternalDependenciesImpactOnTestability(node, reporter, layer, className);

    // Check for static dependencies that prevent testing
    _checkStaticDependencies(node, reporter, layer, className);
  }

  void _validateFrameworkIndependence(
    ClassDeclaration node,
    ErrorReporter reporter,
    ArchitecturalLayer layer,
    String className,
  ) {
    // Check for framework coupling in business logic
    if (_isBusinessLogicLayer(layer)) {
      _checkFrameworkCouplingInBusinessLogic(node, reporter, className);
    }

    // Check for framework-specific patterns that prevent replacement
    _checkFrameworkReplacementBarriers(node, reporter, layer, className);
  }

  void _validateExternalComponentReplaceability(
    ClassDeclaration node,
    ErrorReporter reporter,
    ArchitecturalLayer layer,
    String className,
  ) {
    // Check if external components can be replaced with minimum fuss
    if (_isExternalComponent(layer)) {
      _checkExternalComponentDesign(node, reporter, className);
    }

    // Check for tight coupling that prevents replacement
    _checkTightCouplingToExternals(node, reporter, layer, className);
  }

  void _validateBusinessLogicIsolation(
    ClassDeclaration node,
    ErrorReporter reporter,
    ArchitecturalLayer layer,
    String className,
  ) {
    // Ensure business logic is isolated and protected
    if (_isBusinessLogicLayer(layer)) {
      _checkBusinessLogicIsolation(node, reporter, className);
    }

    // Check for business logic leakage to external layers
    _checkBusinessLogicLeakage(node, reporter, layer, className);
  }

  void _validateIntrinsicTestability(
    MethodDeclaration method,
    ErrorReporter reporter,
    ArchitecturalLayer layer,
    String methodName,
  ) {
    // Check if method can be tested without external dependencies
    if (!_isIntrinsicallyTestable(method)) {
      final code = LintCode(
        name: 'clean_architecture_benefits',
        problemMessage: 'Business logic method $methodName is not intrinsically testable',
        correctionMessage: 'Remove external dependencies to make business logic testable in isolation.',
      );
      reporter.atNode(method, code);
    }

    // Check for testability anti-patterns
    _checkTestabilityAntiPatterns(method, reporter, layer, methodName);
  }

  void _checkHardToTestPatterns(
    MethodDeclaration method,
    ErrorReporter reporter,
    ArchitecturalLayer layer,
    String methodName,
  ) {
    final body = method.body;

    final bodyString = body.toString();

    // Check for hard-coded dependencies
    if (_hasHardCodedDependencies(bodyString)) {
      final code = LintCode(
        name: 'clean_architecture_benefits',
        problemMessage: 'Method $methodName has hard-coded dependencies that hurt testability',
        correctionMessage: 'Use dependency injection to improve testability.',
      );
      reporter.atNode(method, code);
    }

    // Check for static method calls to external services
    if (_hasStaticExternalCalls(bodyString)) {
      final code = LintCode(
        name: 'clean_architecture_benefits',
        problemMessage: 'Method $methodName uses static calls that prevent testing',
        correctionMessage: 'Inject dependencies instead of using static calls.',
      );
      reporter.atNode(method, code);
    }

    // Check for global state access
    if (_accessesGlobalState(bodyString)) {
      final code = LintCode(
        name: 'clean_architecture_benefits',
        problemMessage: 'Method $methodName accesses global state, hurting testability',
        correctionMessage: 'Pass state as parameters or inject as dependencies.',
      );
      reporter.atNode(method, code);
    }
  }

  void _validateConstructorForTestability(
    ConstructorDeclaration constructor,
    ErrorReporter reporter,
    ArchitecturalLayer layer,
    String className,
  ) {
    final parameters = constructor.parameters.parameters;

    // Check if constructor allows for test doubles
    if (_isBusinessLogicLayer(layer) && !_allowsTestDoubles(parameters)) {
      final code = LintCode(
        name: 'clean_architecture_benefits',
        problemMessage: 'Constructor of $className doesn\'t allow test doubles for external dependencies',
        correctionMessage: 'Accept interfaces instead of concrete classes to enable mocking.',
      );
      reporter.atNode(constructor, code);
    }

    // Check for constructor complexity that hurts testability
    if (_hasComplexConstructorLogic(constructor)) {
      final code = LintCode(
        name: 'clean_architecture_benefits',
        problemMessage: 'Constructor of $className has complex logic that hurts testability',
        correctionMessage: 'Move complex logic to methods and keep constructor simple.',
      );
      reporter.atNode(constructor, code);
    }
  }

  void _validateImportIndependence(
    ImportDirective node,
    ErrorReporter reporter,
    ArchitecturalLayer layer,
    String importUri,
  ) {
    // Check for imports that violate independence benefits
    if (_violatesFrameworkIndependence(layer, importUri)) {
      final code = LintCode(
        name: 'clean_architecture_benefits',
        problemMessage: 'Import $importUri violates framework independence in ${layer.name} layer',
        correctionMessage: 'Remove framework dependency to maintain replaceability.',
      );
      reporter.atNode(node, code);
    }

    if (_violatesDatabaseIndependence(layer, importUri)) {
      final code = LintCode(
        name: 'clean_architecture_benefits',
        problemMessage: 'Import $importUri violates database independence in ${layer.name} layer',
        correctionMessage: 'Use repository abstractions instead of direct database imports.',
      );
      reporter.atNode(node, code);
    }

    if (_violatesUIIndependence(layer, importUri)) {
      final code = LintCode(
        name: 'clean_architecture_benefits',
        problemMessage: 'Import $importUri violates UI independence in ${layer.name} layer',
        correctionMessage: 'Keep UI dependencies in presentation layer only.',
      );
      reporter.atNode(node, code);
    }
  }

  void _checkBusinessLogicTestability(
    ClassDeclaration node,
    ErrorReporter reporter,
    ArchitecturalLayer layer,
    String className,
  ) {
    // Check if business logic can be tested without external systems
    final externalDependencies = _getExternalDependencies(node);

    if (externalDependencies.isNotEmpty) {
      for (final dependency in externalDependencies) {
        if (!_isAbstractDependency(dependency)) {
          final code = LintCode(
            name: 'clean_architecture_benefits',
            problemMessage: 'Business logic class $className depends on concrete external component: $dependency',
            correctionMessage: 'Use interface to maintain testability and replaceability.',
          );
          reporter.atNode(node, code);
        }
      }
    }
  }

  void _checkExternalDependenciesImpactOnTestability(
    ClassDeclaration node,
    ErrorReporter reporter,
    ArchitecturalLayer layer,
    String className,
  ) {
    if (_isBusinessLogicLayer(layer)) {
      final fields = node.members.whereType<FieldDeclaration>();

      for (final field in fields) {
        final type = field.fields.type;
        if (type is NamedType) {
          final typeName = type.name2.lexeme;

          if (_isExternalDependencyType(typeName)) {
            final code = LintCode(
              name: 'clean_architecture_benefits',
              problemMessage:
                  'Business logic class $className has external dependency $typeName that hurts testability',
              correctionMessage: 'Inject interface instead of concrete external dependency.',
            );
            reporter.atNode(field, code);
          }
        }
      }
    }
  }

  void _checkStaticDependencies(
    ClassDeclaration node,
    ErrorReporter reporter,
    ArchitecturalLayer layer,
    String className,
  ) {
    if (_isBusinessLogicLayer(layer)) {
      final methods = node.members.whereType<MethodDeclaration>();

      for (final method in methods) {
        if (_usesStaticDependencies(method)) {
          final code = LintCode(
            name: 'clean_architecture_benefits',
            problemMessage: 'Method ${method.name.lexeme} in $className uses static dependencies that prevent testing',
            correctionMessage: 'Inject dependencies instead of using static references.',
          );
          reporter.atNode(method, code);
        }
      }
    }
  }

  void _checkFrameworkCouplingInBusinessLogic(
    ClassDeclaration node,
    ErrorReporter reporter,
    String className,
  ) {
    // Check for framework-specific annotations or inheritance
    final annotations = node.metadata;
    for (final annotation in annotations) {
      if (_isFrameworkAnnotation(annotation)) {
        final code = LintCode(
          name: 'clean_architecture_benefits',
          problemMessage: 'Business logic class $className uses framework annotation',
          correctionMessage: 'Remove framework coupling to maintain independence and replaceability.',
        );
        reporter.atNode(annotation, code);
      }
    }

    // Check inheritance from framework classes
    final extendsClause = node.extendsClause;
    if (extendsClause != null) {
      final superclassName = extendsClause.superclass.name2.lexeme;
      if (_isFrameworkClass(superclassName)) {
        final code = LintCode(
          name: 'clean_architecture_benefits',
          problemMessage: 'Business logic class $className extends framework class $superclassName',
          correctionMessage: 'Use composition instead of inheritance to maintain framework independence.',
        );
        reporter.atNode(extendsClause, code);
      }
    }
  }

  void _checkFrameworkReplacementBarriers(
    ClassDeclaration node,
    ErrorReporter reporter,
    ArchitecturalLayer layer,
    String className,
  ) {
    // Check for patterns that make framework replacement difficult
    if (_hasFrameworkSpecificPatterns(node)) {
      final code = LintCode(
        name: 'clean_architecture_benefits',
        problemMessage: 'Class $className has framework-specific patterns that prevent easy replacement',
        correctionMessage: 'Use generic patterns to enable framework replacement with minimum fuss.',
      );
      reporter.atNode(node, code);
    }
  }

  void _checkExternalComponentDesign(
    ClassDeclaration node,
    ErrorReporter reporter,
    String className,
  ) {
    // Check if external component is designed for easy replacement
    if (!_isDesignedForReplacement(node)) {
      final code = LintCode(
        name: 'clean_architecture_benefits',
        problemMessage: 'External component $className is not designed for easy replacement',
        correctionMessage: 'Implement clear interfaces and minimize coupling for replaceability.',
      );
      reporter.atNode(node, code);
    }
  }

  void _checkTightCouplingToExternals(
    ClassDeclaration node,
    ErrorReporter reporter,
    ArchitecturalLayer layer,
    String className,
  ) {
    // Check for tight coupling that prevents replacement
    if (_hasTightCouplingToExternals(node, layer)) {
      final code = LintCode(
        name: 'clean_architecture_benefits',
        problemMessage: 'Class $className has tight coupling to external components',
        correctionMessage: 'Reduce coupling to enable easy replacement of external components.',
      );
      reporter.atNode(node, code);
    }
  }

  void _checkBusinessLogicIsolation(
    ClassDeclaration node,
    ErrorReporter reporter,
    String className,
  ) {
    // Check if business logic is properly isolated
    if (!_isProperlyIsolated(node)) {
      final code = LintCode(
        name: 'clean_architecture_benefits',
        problemMessage: 'Business logic in $className is not properly isolated',
        correctionMessage: 'Isolate business logic from external concerns for better testability.',
      );
      reporter.atNode(node, code);
    }
  }

  void _checkBusinessLogicLeakage(
    ClassDeclaration node,
    ErrorReporter reporter,
    ArchitecturalLayer layer,
    String className,
  ) {
    if (!_isBusinessLogicLayer(layer) && _containsBusinessLogic(node, layer)) {
      final code = LintCode(
        name: 'clean_architecture_benefits',
        problemMessage: 'Business logic leaked to ${layer.name} layer in class $className',
        correctionMessage: 'Move business logic to appropriate inner layer for better isolation.',
      );
      reporter.atNode(node, code);
    }
  }

  void _checkTestabilityAntiPatterns(
    MethodDeclaration method,
    ErrorReporter reporter,
    ArchitecturalLayer layer,
    String methodName,
  ) {
    final body = method.body;

    // Check for singleton usage
    if (_usesSingleton(body)) {
      final code = LintCode(
        name: 'clean_architecture_benefits',
        problemMessage: 'Method $methodName uses singleton pattern that hurts testability',
        correctionMessage: 'Inject dependencies instead of using singletons.',
      );
      reporter.atNode(method, code);
    }

    // Check for new keyword in business logic
    if (_isBusinessLogicLayer(layer) && _instantiatesDirectly(body)) {
      final code = LintCode(
        name: 'clean_architecture_benefits',
        problemMessage: 'Business logic method $methodName directly instantiates dependencies',
        correctionMessage: 'Use dependency injection or factory pattern for better testability.',
      );
      reporter.atNode(method, code);
    }
  }

  // Helper methods for layer and pattern detection
  ArchitecturalLayer? _detectLayer(String filePath) {
    if (filePath.contains('/domain/')) return ArchitecturalLayer('domain', 4, true);
    if (filePath.contains('/usecases/') || filePath.contains('/use_cases/')) {
      return ArchitecturalLayer('use_case', 3, true);
    }
    if (filePath.contains('/controllers/')) return ArchitecturalLayer('controller', 2, false);
    if (filePath.contains('/presenters/')) return ArchitecturalLayer('presenter', 2, false);
    if (filePath.contains('/adapters/')) return ArchitecturalLayer('adapter', 2, false);
    if (filePath.contains('/infrastructure/')) return ArchitecturalLayer('infrastructure', 1, false);
    if (filePath.contains('/data/')) return ArchitecturalLayer('data', 1, false);
    return null;
  }

  bool _isBusinessLogicMethod(MethodDeclaration method, ArchitecturalLayer layer) {
    return _isBusinessLogicLayer(layer) && _containsBusinessLogicPatterns(method.name.lexeme);
  }

  bool _isBusinessLogicLayer(ArchitecturalLayer layer) {
    return layer.isBusinessLogic;
  }

  bool _isExternalComponent(ArchitecturalLayer layer) {
    return layer.name == 'infrastructure' || layer.name == 'data';
  }

  bool _containsBusinessLogic(ClassDeclaration node, ArchitecturalLayer layer) {
    final methods = node.members.whereType<MethodDeclaration>();
    return methods.any((method) => _containsBusinessLogicPatterns(method.name.lexeme));
  }

  bool _containsBusinessLogicPatterns(String name) {
    final businessPatterns = ['calculate', 'validate', 'process', 'apply', 'execute', 'perform', 'handle', 'manage'];
    return businessPatterns.any((pattern) => name.toLowerCase().contains(pattern));
  }

  bool _isIntrinsicallyTestable(MethodDeclaration method) {
    final body = method.body;
    final bodyString = body.toString();

    // Method is testable if it doesn't depend on external systems
    return !_hasExternalDependencies(bodyString) &&
        !_hasStaticDependencies(bodyString) &&
        !_hasGlobalStateAccess(bodyString);
  }

  bool _hasHardCodedDependencies(String bodyString) {
    return bodyString.contains('new ') &&
        !bodyString.contains('List(') &&
        !bodyString.contains('Map(') &&
        !bodyString.contains('String(');
  }

  bool _hasStaticExternalCalls(String bodyString) {
    final staticPatterns = ['Database.', 'HttpClient.', 'File.', 'Directory.', 'Logger.', 'Config.', 'System.'];
    return staticPatterns.any((pattern) => bodyString.contains(pattern));
  }

  bool _accessesGlobalState(String bodyString) {
    final globalPatterns = ['global', 'Global', 'getInstance()', 'instance.', 'current.', 'shared.'];
    return globalPatterns.any((pattern) => bodyString.contains(pattern));
  }

  bool _allowsTestDoubles(List<FormalParameter> parameters) {
    return parameters.any((param) {
      if (param is SimpleFormalParameter) {
        final type = param.type;
        if (type is NamedType) {
          final typeName = type.name2.lexeme;
          return _isAbstractType(typeName);
        }
      }
      return false;
    });
  }

  bool _hasComplexConstructorLogic(ConstructorDeclaration constructor) {
    final body = constructor.body;
    final bodyString = body.toString();

    // Check for complex logic indicators
    return bodyString.contains('if (') ||
        bodyString.contains('for (') ||
        bodyString.contains('while (') ||
        bodyString.contains('switch (') ||
        bodyString.split('\n').length > 10;
  }

  bool _violatesFrameworkIndependence(ArchitecturalLayer layer, String importUri) {
    if (_isBusinessLogicLayer(layer)) {
      final frameworkImports = [
        'package:flutter/',
        'package:angular/',
        'package:react/',
        'package:spring/',
        'package:express/'
      ];
      return frameworkImports.any((framework) => importUri.startsWith(framework));
    }
    return false;
  }

  bool _violatesDatabaseIndependence(ArchitecturalLayer layer, String importUri) {
    if (_isBusinessLogicLayer(layer)) {
      final databaseImports = [
        'package:sqflite/',
        'package:mysql/',
        'package:postgres/',
        'package:mongodb/',
        'package:redis/'
      ];
      return databaseImports.any((db) => importUri.startsWith(db));
    }
    return false;
  }

  bool _violatesUIIndependence(ArchitecturalLayer layer, String importUri) {
    if (_isBusinessLogicLayer(layer)) {
      final uiImports = ['package:flutter/widgets', 'package:flutter/material', '/ui/', '/widgets/', '/components/'];
      return uiImports.any((ui) => importUri.contains(ui));
    }
    return false;
  }

  List<String> _getExternalDependencies(ClassDeclaration node) {
    final dependencies = <String>[];
    final fields = node.members.whereType<FieldDeclaration>();

    for (final field in fields) {
      final type = field.fields.type;
      if (type is NamedType) {
        final typeName = type.name2.lexeme;
        if (_isExternalDependencyType(typeName)) {
          dependencies.add(typeName);
        }
      }
    }

    return dependencies;
  }

  bool _isAbstractDependency(String typeName) {
    return _isAbstractType(typeName) || _isInterfaceType(typeName);
  }

  bool _isAbstractType(String typeName) {
    return typeName.startsWith('I') ||
        typeName.contains('Interface') ||
        typeName.contains('Abstract') ||
        typeName.contains('Contract');
  }

  bool _isInterfaceType(String typeName) {
    return typeName.startsWith('I') && typeName.length > 1 || typeName.contains('Interface');
  }

  bool _isExternalDependencyType(String typeName) {
    final externalTypes = [
      'Database',
      'HttpClient',
      'FileSystem',
      'Logger',
      'Cache',
      'Queue',
      'EmailService',
      'NotificationService'
    ];
    return externalTypes.any((type) => typeName.contains(type));
  }

  bool _usesStaticDependencies(MethodDeclaration method) {
    final body = method.body;
    return _hasStaticDependencies(body.toString());
  }

  bool _hasStaticDependencies(String bodyString) {
    final staticPatterns = ['.getInstance()', '.current', '.shared', '.global'];
    return staticPatterns.any((pattern) => bodyString.contains(pattern));
  }

  bool _isFrameworkAnnotation(Annotation annotation) {
    final frameworkAnnotations = ['Component', 'Service', 'Controller', 'Entity', 'Repository', 'Autowired', 'Inject'];
    return frameworkAnnotations.any((annot) => annotation.toString().contains(annot));
  }

  bool _isFrameworkClass(String className) {
    final frameworkClasses = ['Component', 'Service', 'Controller', 'HttpServlet', 'Activity', 'Fragment', 'Widget'];
    return frameworkClasses.any((cls) => className.contains(cls));
  }

  bool _hasFrameworkSpecificPatterns(ClassDeclaration node) {
    // Check for framework-specific method names or patterns
    final methods = node.members.whereType<MethodDeclaration>();
    final frameworkMethodPatterns = ['onCreate', 'onDestroy', 'viewDidLoad', 'componentDidMount'];

    return methods.any((method) => frameworkMethodPatterns.any((pattern) => method.name.lexeme.contains(pattern)));
  }

  bool _isDesignedForReplacement(ClassDeclaration node) {
    // Check if class implements interfaces for replaceability
    final implementsClause = node.implementsClause;
    return implementsClause != null && implementsClause.interfaces.isNotEmpty;
  }

  bool _hasTightCouplingToExternals(ClassDeclaration node, ArchitecturalLayer layer) {
    // Check for direct dependencies on external concrete classes
    final fields = node.members.whereType<FieldDeclaration>();

    return fields.any((field) {
      final type = field.fields.type;
      if (type is NamedType) {
        final typeName = type.name2.lexeme;
        return _isExternalDependencyType(typeName) && !_isAbstractType(typeName);
      }
      return false;
    });
  }

  bool _isProperlyIsolated(ClassDeclaration node) {
    // Check if business logic class is isolated from external concerns
    final dependencies = _getExternalDependencies(node);
    return dependencies.every((dep) => _isAbstractDependency(dep));
  }

  bool _hasExternalDependencies(String bodyString) {
    final externalPatterns = ['Database.', 'HttpClient.', 'File.', 'Network.', 'System.', 'Environment.'];
    return externalPatterns.any((pattern) => bodyString.contains(pattern));
  }

  bool _hasGlobalStateAccess(String bodyString) {
    return _accessesGlobalState(bodyString);
  }

  bool _usesSingleton(FunctionBody body) {
    final bodyString = body.toString();
    return bodyString.contains('getInstance()') ||
        bodyString.contains('.instance') ||
        bodyString.contains('Singleton.');
  }

  bool _instantiatesDirectly(FunctionBody body) {
    final bodyString = body.toString();
    return bodyString.contains('new ') && !bodyString.contains('List(') && !bodyString.contains('Map(');
  }
}

class ArchitecturalLayer {
  final String name;
  final int level;
  final bool isBusinessLogic;

  ArchitecturalLayer(this.name, this.level, this.isBusinessLogic);
}
