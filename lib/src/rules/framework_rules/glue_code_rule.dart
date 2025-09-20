import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Enforces proper glue code patterns in the framework layer.
///
/// This rule ensures that framework layer contains only glue code:
/// - Minimal code that connects frameworks to inner layers
/// - Configuration and setup code for frameworks
/// - Dependency injection wiring
/// - Framework initialization and bootstrapping
/// - No business logic in glue code
/// - No complex algorithmic logic in glue code
///
/// Glue code should:
/// - Be simple and straightforward
/// - Focus on connecting components
/// - Handle framework-specific configuration
/// - Bootstrap the application
/// - Delegate to inner layers for any logic
class GlueCodeRule extends DartLintRule {
  const GlueCodeRule() : super(code: _code);

  static const _code = LintCode(
    name: 'glue_code',
    problemMessage:
        'Framework layer should contain only simple glue code that connects frameworks to inner layers.',
    correctionMessage:
        'Keep framework code simple. Move complex logic to appropriate inner layers.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((node) {
      _checkGlueCodeClass(node, reporter, resolver);
    });

    context.registry.addMethodDeclaration((node) {
      _checkGlueCodeMethod(node, reporter, resolver);
    });

    context.registry.addFunctionDeclaration((node) {
      _checkGlueCodeFunction(node, reporter, resolver);
    });
  }

  void _checkGlueCodeClass(
    ClassDeclaration node,
    DiagnosticReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    if (!_isFrameworkLayer(filePath)) return;

    final className = node.name.lexeme;

    // Check if class is appropriate for framework layer
    if (!_isAppropriateFrameworkClass(className)) {
      final code = LintCode(
        name: 'glue_code',
        problemMessage: 'Complex class found in framework layer: $className',
        correctionMessage:
            'Framework layer should contain only configuration, bootstrap, and glue classes.',
      );
      reporter.atNode(node, code);
    }

    // Check class complexity
    final complexity = _analyzeClassComplexity(node);
    if (complexity.isComplexForGlueCode) {
      final code = LintCode(
        name: 'glue_code',
        problemMessage: 'Framework class is too complex: $className',
        correctionMessage:
            'Simplify framework class or move complex logic to inner layers.',
      );
      reporter.atNode(node, code);
    }

    // Check for business logic in framework class
    _checkFrameworkClassForBusinessLogic(node, reporter);
  }

  void _checkGlueCodeMethod(
    MethodDeclaration method,
    DiagnosticReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    if (!_isFrameworkLayer(filePath)) return;

    final methodName = method.name.lexeme;

    // Check if method is appropriate for framework layer
    if (!_isAppropriateGlueMethod(methodName)) {
      final code = LintCode(
        name: 'glue_code',
        problemMessage: 'Complex method found in framework layer: $methodName',
        correctionMessage:
            'Framework methods should only handle setup, configuration, and delegation.',
      );
      reporter.atNode(method, code);
    }

    // Check method complexity
    final complexity = _analyzeMethodComplexity(method);
    if (complexity.isComplexForGlueCode) {
      final code = LintCode(
        name: 'glue_code',
        problemMessage: 'Framework method is too complex: $methodName',
        correctionMessage:
            'Simplify glue code or delegate complex logic to inner layers.',
      );
      reporter.atNode(method, code);
    }

    // Check for specific anti-patterns
    _checkGlueMethodAntiPatterns(method, reporter);
  }

  void _checkGlueCodeFunction(
    FunctionDeclaration function,
    DiagnosticReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    if (!_isFrameworkLayer(filePath)) return;

    final functionName = function.name.lexeme;

    // Check function complexity
    final complexity = _analyzeMethodComplexity(function.functionExpression);
    if (complexity.isComplexForGlueCode) {
      final code = LintCode(
        name: 'glue_code',
        problemMessage: 'Framework function is too complex: $functionName',
        correctionMessage:
            'Keep framework functions simple. Move complex logic to inner layers.',
      );
      reporter.atNode(function, code);
    }
  }

  void _checkFrameworkClassForBusinessLogic(
    ClassDeclaration node,
    DiagnosticReporter reporter,
  ) {
    for (final member in node.members) {
      if (member is MethodDeclaration) {
        final methodName = member.name.lexeme;

        if (_containsBusinessLogic(member, methodName)) {
          final code = LintCode(
            name: 'glue_code',
            problemMessage: 'Business logic found in framework class: $methodName',
            correctionMessage:
                'Move business logic to use case or entity. Framework should only contain glue code.',
          );
          reporter.atNode(member, code);
        }

        if (_containsComplexAlgorithm(member, methodName)) {
          final code = LintCode(
            name: 'glue_code',
            problemMessage: 'Complex algorithm found in framework class: $methodName',
            correctionMessage:
                'Move complex algorithms to appropriate inner layer. Keep framework code simple.',
          );
          reporter.atNode(member, code);
        }
      }
    }
  }

  void _checkGlueMethodAntiPatterns(
    MethodDeclaration method,
    DiagnosticReporter reporter,
  ) {
    final methodName = method.name.lexeme;

    // Check for data processing in glue code
    if (_containsDataProcessing(method, methodName)) {
      final code = LintCode(
        name: 'glue_code',
        problemMessage: 'Data processing found in glue code: $methodName',
        correctionMessage:
            'Move data processing to adapter layer. Glue code should only connect components.',
      );
      reporter.atNode(method, code);
    }

    // Check for validation logic
    if (_containsValidationLogic(method, methodName)) {
      final code = LintCode(
        name: 'glue_code',
        problemMessage: 'Validation logic found in glue code: $methodName',
        correctionMessage:
            'Move validation logic to entity or use case. Glue code should delegate validation.',
      );
      reporter.atNode(method, code);
    }

    // Check for calculation logic
    if (_containsCalculationLogic(method, methodName)) {
      final code = LintCode(
        name: 'glue_code',
        problemMessage: 'Calculation logic found in glue code: $methodName',
        correctionMessage:
            'Move calculation logic to entity or use case. Glue code should only coordinate.',
      );
      reporter.atNode(method, code);
    }
  }

  GlueCodeComplexity _analyzeClassComplexity(ClassDeclaration node) {
    final methods = node.members.whereType<MethodDeclaration>().toList();
    final fields = node.members.whereType<FieldDeclaration>().toList();

    final methodCount = methods.length;
    final fieldCount = fields.length;
    final totalLines = _estimateLines(node);

    return GlueCodeComplexity(
      methodCount: methodCount,
      fieldCount: fieldCount,
      totalLines: totalLines,
      isComplexForGlueCode: methodCount > 25 || fieldCount > 15 || totalLines > 300,
    );
  }

  GlueCodeComplexity _analyzeMethodComplexity(dynamic methodOrFunction) {
    MethodDeclaration? method;
    FunctionExpression? function;

    if (methodOrFunction is MethodDeclaration) {
      method = methodOrFunction;
    } else if (methodOrFunction is FunctionExpression) {
      function = methodOrFunction;
    }

    final body = method?.body ?? function?.body;
    if (body == null) {
      return GlueCodeComplexity(
        methodCount: 0,
        fieldCount: 0,
        totalLines: 0,
        isComplexForGlueCode: false,
      );
    }

    final cyclomaticComplexity = _calculateCyclomaticComplexity(body);
    final statementCount = _countStatements(body);
    final totalLines = _estimateLines(body);

    return GlueCodeComplexity(
      methodCount: 1,
      fieldCount: 0,
      totalLines: totalLines,
      cyclomaticComplexity: cyclomaticComplexity,
      statementCount: statementCount,
      isComplexForGlueCode: cyclomaticComplexity > 8 ||
                           statementCount > 25 ||
                           totalLines > 75,
    );
  }

  int _calculateCyclomaticComplexity(AstNode node) {
    var complexity = 1; // Base complexity

    void countComplexity(AstNode node) {
      if (node is IfStatement) complexity++;
      if (node is WhileStatement) complexity++;
      if (node is ForStatement) complexity++;
      if (node is SwitchStatement) complexity += node.members.length;
      if (node is TryStatement) complexity++;
      if (node is ConditionalExpression) complexity++;

      for (var child in node.childEntities) {
        if (child is AstNode) countComplexity(child);
      }
    }

    countComplexity(node);
    return complexity;
  }

  int _countStatements(AstNode node) {
    var count = 0;

    void countStatements(AstNode node) {
      if (node is ExpressionStatement) count++;
      if (node is ReturnStatement) count++;
      if (node is VariableDeclarationStatement) count++;
      if (node is IfStatement) count++;
      if (node is WhileStatement) count++;
      if (node is ForStatement) count++;

      for (var child in node.childEntities) {
        if (child is AstNode) countStatements(child);
      }
    }

    countStatements(node);
    return count;
  }

  int _estimateLines(AstNode node) {
    final sourceText = node.toString();
    return sourceText.split('\n').length;
  }

  bool _isAppropriateFrameworkClass(String className) {
    final appropriateClassPatterns = [
      'App', 'Main', 'Server', 'Bootstrap',
      'Configuration', 'Config', 'Setup',
      'Launcher', 'Runner', 'Starter',
      'Container', 'Module', 'Plugin',
      'Factory', 'Builder', 'Creator',
      // Flutter-specific patterns
      'MaterialApp', 'CupertinoApp', 'WidgetsApp',
      'GetMaterialApp', 'Phoenix', 'AppWidget',
      // DI Container patterns
      'ServiceLocator', 'DIContainer', 'Injector',
      'GetItModule', 'ProviderModule', 'RiverpodModule',
    ];

    return appropriateClassPatterns.any((pattern) => className.contains(pattern)) ||
           className == 'main' ||
           className.endsWith('Module') ||
           className.endsWith('Config') ||
           className.endsWith('App') ||
           _isFlutterAppClass(className);
  }

  bool _isFlutterAppClass(String className) {
    final flutterAppPatterns = [
      'MaterialApp', 'CupertinoApp', 'WidgetsApp',
      'GetMaterialApp', 'Phoenix', 'AppWidget'
    ];
    return flutterAppPatterns.any((pattern) => className == pattern);
  }

  bool _isAppropriateGlueMethod(String methodName) {
    final appropriateMethodPatterns = [
      'main', 'run', 'start', 'launch', 'execute',
      'configure', 'setup', 'initialize', 'init',
      'bootstrap', 'wire', 'bind', 'register',
      'create', 'build', 'make', 'factory',
      'connect', 'attach', 'mount', 'install',
      // Flutter-specific patterns
      'runapp', 'ensureinitialized', 'setpreferred',
      'configureapp', 'setupapp', 'initializeapp',
      // DI setup patterns
      'setupgetit', 'configuredependencies', 'setupservices',
      'registerservices', 'wireup', 'setupinjection',
      // Route setup patterns
      'setuproutes', 'configurerouting', 'initroutes',
    ];

    return appropriateMethodPatterns.any((pattern) =>
        methodName.toLowerCase().contains(pattern)) ||
        _isFlutterSetupMethod(methodName);
  }

  bool _isFlutterSetupMethod(String methodName) {
    final flutterSetupMethods = [
      'runApp', 'ensureInitialized', 'setPreferredOrientations',
      'configureApp', 'setupApp', 'initializeApp'
    ];
    return flutterSetupMethods.any((method) => methodName == method);
  }

  bool _containsBusinessLogic(MethodDeclaration method, String methodName) {
    final businessLogicPatterns = [
      'validate', 'calculate', 'process', 'apply',
      'business', 'rule', 'policy', 'workflow',
      'approve', 'reject', 'authorize', 'verify',
    ];

    return businessLogicPatterns.any((pattern) =>
        methodName.toLowerCase().contains(pattern));
  }

  bool _containsComplexAlgorithm(MethodDeclaration method, String methodName) {
    final algorithmPatterns = [
      'sort', 'search', 'filter', 'transform',
      'algorithm', 'compute', 'optimize',
      'parse', 'analyze', 'decode', 'encode',
    ];

    final hasAlgorithmName = algorithmPatterns.any((pattern) =>
        methodName.toLowerCase().contains(pattern));

    if (hasAlgorithmName) return true;

    // Check method body for algorithmic complexity
    final complexity = _analyzeMethodComplexity(method);
    return complexity.cyclomaticComplexity > 8;
  }

  bool _containsDataProcessing(MethodDeclaration method, String methodName) {
    final dataProcessingPatterns = [
      'convert', 'map', 'transform', 'adapt',
      'serialize', 'deserialize', 'parse',
      'format', 'normalize', 'sanitize',
    ];

    // Allow simple Flutter app configuration data processing
    if (_isFlutterConfigurationMethod(methodName)) {
      return false;
    }

    return dataProcessingPatterns.any((pattern) =>
        methodName.toLowerCase().contains(pattern));
  }

  bool _isFlutterConfigurationMethod(String methodName) {
    final flutterConfigMethods = [
      'configureApp', 'setupTheme', 'buildTheme',
      'createRoute', 'generateRoute', 'parseRoute'
    ];
    return flutterConfigMethods.any((method) => methodName.contains(method));
  }

  bool _containsValidationLogic(MethodDeclaration method, String methodName) {
    final validationPatterns = [
      'validate', 'isValid', 'check', 'verify',
      'ensure', 'assert', 'confirm', 'test',
    ];

    return validationPatterns.any((pattern) =>
        methodName.toLowerCase().contains(pattern));
  }

  bool _containsCalculationLogic(MethodDeclaration method, String methodName) {
    final calculationPatterns = [
      'calculate', 'compute', 'sum', 'total',
      'add', 'subtract', 'multiply', 'divide',
      'count', 'average', 'min', 'max',
    ];

    return calculationPatterns.any((pattern) =>
        methodName.toLowerCase().contains(pattern));
  }

  bool _isFrameworkLayer(String filePath) {
    final frameworkPaths = [
      '/framework/', '\\framework\\',
      '/frameworks/', '\\frameworks\\',
      '/infrastructure/', '\\infrastructure\\',
      '/main.dart', '\\main.dart',
      '/bootstrap/', '\\bootstrap\\',
      '/config/', '\\config\\',
      '/setup/', '\\setup\\',
      '/app.dart', '\\app.dart',
      '/application/', '\\application\\',
      '/launcher/', '\\launcher\\',
    ];

    return frameworkPaths.any((path) => filePath.contains(path)) ||
           _isTestFile(filePath); // Allow complexity in test files
  }

  bool _isTestFile(String filePath) {
    return filePath.contains('/test/') ||
           filePath.contains('\\test\\') ||
           filePath.endsWith('_test.dart') ||
           filePath.contains('/test_') ||
           filePath.contains('\\test_');
  }
}

class GlueCodeComplexity {
  final int methodCount;
  final int fieldCount;
  final int totalLines;
  final int cyclomaticComplexity;
  final int statementCount;
  final bool isComplexForGlueCode;

  const GlueCodeComplexity({
    required this.methodCount,
    required this.fieldCount,
    required this.totalLines,
    this.cyclomaticComplexity = 0,
    this.statementCount = 0,
    required this.isComplexForGlueCode,
  });
}