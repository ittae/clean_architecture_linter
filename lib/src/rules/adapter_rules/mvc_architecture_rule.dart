import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Enforces proper MVC architecture in Interface Adapter layer.
///
/// This rule ensures that MVC components are properly separated:
/// - Controllers: Handle user input, coordinate with use cases
/// - Views: Display data, handle UI rendering only
/// - Presenters: Format data for views, handle presentation logic
/// - Models: Simple data structures passed between layers
///
/// MVC Components should:
/// - Controllers: Accept input, call use cases, pass results to presenters
/// - Views: Render UI, delegate user actions to controllers
/// - Presenters: Format data from use cases for views
/// - Models: Be simple DTOs without business logic
class MVCArchitectureRule extends DartLintRule {
  const MVCArchitectureRule() : super(code: _code);

  static const _code = LintCode(
    name: 'mvc_architecture',
    problemMessage:
        'MVC component must follow its architectural responsibilities.',
    correctionMessage:
        'Separate concerns: Controllers handle input, Views render UI, Presenters format data, Models hold data.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((node) {
      _checkMVCComponent(node, reporter, resolver);
    });
  }

  void _checkMVCComponent(
    ClassDeclaration node,
    DiagnosticReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    if (!_isAdapterLayerFile(filePath)) return;

    final className = node.name.lexeme;

    if (_isController(className)) {
      _checkControllerResponsibilities(node, reporter);
    } else if (_isView(className)) {
      _checkViewResponsibilities(node, reporter);
    } else if (_isPresenter(className)) {
      _checkPresenterResponsibilities(node, reporter);
    } else if (_isModel(className)) {
      _checkModelResponsibilities(node, reporter);
    }
  }

  void _checkControllerResponsibilities(
    ClassDeclaration node,
    DiagnosticReporter reporter,
  ) {
    final className = node.name.lexeme;

    // Controllers should coordinate, not implement business logic
    for (final member in node.members) {
      if (member is MethodDeclaration) {
        final methodName = member.name.lexeme;

        // Check for business logic implementation
        if (_implementsBusinessLogic(member, methodName)) {
          final code = LintCode(
            name: 'mvc_architecture',
            problemMessage: 'Controller implements business logic: $methodName in $className',
            correctionMessage:
                'Move business logic to use case. Controller should only coordinate.',
          );
          reporter.atNode(member, code);
        }

        // Check for UI rendering
        if (_implementsUIRendering(member, methodName)) {
          final code = LintCode(
            name: 'mvc_architecture',
            problemMessage: 'Controller implements UI rendering: $methodName in $className',
            correctionMessage:
                'Move UI rendering to View. Controller should only handle input and coordination.',
          );
          reporter.atNode(member, code);
        }

        // Check for data formatting
        if (_implementsDataFormatting(member, methodName)) {
          final code = LintCode(
            name: 'mvc_architecture',
            problemMessage: 'Controller implements data formatting: $methodName in $className',
            correctionMessage:
                'Move data formatting to Presenter. Controller should delegate to presenter.',
          );
          reporter.atNode(member, code);
        }
      }
    }

    // Check controller dependencies
    _checkControllerDependencies(node, reporter);
  }

  void _checkViewResponsibilities(
    ClassDeclaration node,
    DiagnosticReporter reporter,
  ) {
    final className = node.name.lexeme;

    for (final member in node.members) {
      if (member is MethodDeclaration) {
        final methodName = member.name.lexeme;

        // Views should not implement business logic
        if (_implementsBusinessLogic(member, methodName)) {
          final code = LintCode(
            name: 'mvc_architecture',
            problemMessage: 'View implements business logic: $methodName in $className',
            correctionMessage:
                'Move business logic to use case. View should only render UI.',
          );
          reporter.atNode(member, code);
        }

        // Views should not handle complex data processing
        if (_implementsDataProcessing(member, methodName)) {
          final code = LintCode(
            name: 'mvc_architecture',
            problemMessage: 'View implements data processing: $methodName in $className',
            correctionMessage:
                'Move data processing to Presenter. View should receive formatted data.',
          );
          reporter.atNode(member, code);
        }

        // Views should not directly call use cases
        if (_callsUseCases(member, methodName)) {
          final code = LintCode(
            name: 'mvc_architecture',
            problemMessage: 'View directly calls use cases: $methodName in $className',
            correctionMessage:
                'Use Controller to call use cases. View should delegate user actions.',
          );
          reporter.atNode(member, code);
        }
      }
    }
  }

  void _checkPresenterResponsibilities(
    ClassDeclaration node,
    DiagnosticReporter reporter,
  ) {
    final className = node.name.lexeme;

    for (final member in node.members) {
      if (member is MethodDeclaration) {
        final methodName = member.name.lexeme;

        // Presenters should not implement business logic
        if (_implementsBusinessLogic(member, methodName)) {
          final code = LintCode(
            name: 'mvc_architecture',
            problemMessage: 'Presenter implements business logic: $methodName in $className',
            correctionMessage:
                'Move business logic to use case. Presenter should only format data for display.',
          );
          reporter.atNode(member, code);
        }

        // Presenters should not render UI
        if (_implementsUIRendering(member, methodName)) {
          final code = LintCode(
            name: 'mvc_architecture',
            problemMessage: 'Presenter renders UI: $methodName in $className',
            correctionMessage:
                'Move UI rendering to View. Presenter should only format data.',
          );
          reporter.atNode(member, code);
        }

        // Presenters should not handle user input
        if (_handlesUserInput(member, methodName)) {
          final code = LintCode(
            name: 'mvc_architecture',
            problemMessage: 'Presenter handles user input: $methodName in $className',
            correctionMessage:
                'Move input handling to Controller. Presenter should only format output.',
          );
          reporter.atNode(member, code);
        }
      }
    }
  }

  void _checkModelResponsibilities(
    ClassDeclaration node,
    DiagnosticReporter reporter,
  ) {
    final className = node.name.lexeme;

    for (final member in node.members) {
      if (member is MethodDeclaration) {
        final methodName = member.name.lexeme;

        // Models should not implement business logic
        if (_implementsBusinessLogic(member, methodName)) {
          final code = LintCode(
            name: 'mvc_architecture',
            problemMessage: 'Model implements business logic: $methodName in $className',
            correctionMessage:
                'Models should be simple DTOs. Move business logic to entities or use cases.',
          );
          reporter.atNode(member, code);
        }

        // Models should not have UI logic
        if (_implementsUILogic(member, methodName)) {
          final code = LintCode(
            name: 'mvc_architecture',
            problemMessage: 'Model implements UI logic: $methodName in $className',
            correctionMessage:
                'Models should be data containers. Move UI logic to View or Presenter.',
          );
          reporter.atNode(member, code);
        }

        // Models should not have persistence logic
        if (_implementsPersistenceLogic(member, methodName)) {
          final code = LintCode(
            name: 'mvc_architecture',
            problemMessage: 'Model implements persistence logic: $methodName in $className',
            correctionMessage:
                'Models should be data containers. Move persistence logic to repository.',
          );
          reporter.atNode(member, code);
        }
      }
    }
  }

  void _checkControllerDependencies(
    ClassDeclaration node,
    DiagnosticReporter reporter,
  ) {
    for (final member in node.members) {
      if (member is FieldDeclaration) {
        final type = member.fields.type;
        if (type is NamedType) {
          final typeName = type.name.lexeme;

          // Controllers should depend on use cases and presenters
          if (!_isValidControllerDependency(typeName)) {
            final code = LintCode(
              name: 'mvc_architecture',
              problemMessage: 'Controller has invalid dependency: $typeName',
              correctionMessage:
                  'Controllers should depend on use cases and presenters, not entities or infrastructure.',
            );
            reporter.atNode(type, code);
          }
        }
      }
    }
  }

  bool _implementsBusinessLogic(MethodDeclaration method, String methodName) {
    final businessLogicPatterns = [
      'validate', 'calculate', 'process', 'apply',
      'enforce', 'check', 'verify', 'ensure',
      'business', 'rule', 'policy', 'constraint',
    ];

    return businessLogicPatterns.any((pattern) =>
        methodName.toLowerCase().contains(pattern));
  }

  bool _implementsUIRendering(MethodDeclaration method, String methodName) {
    final uiPatterns = [
      'render', 'draw', 'paint', 'display',
      'show', 'hide', 'animate', 'transition',
      'build', 'create', 'widget', 'component',
    ];

    return uiPatterns.any((pattern) =>
        methodName.toLowerCase().contains(pattern));
  }

  bool _implementsDataFormatting(MethodDeclaration method, String methodName) {
    final formattingPatterns = [
      'format', 'parse', 'convert', 'transform',
      'serialize', 'deserialize', 'encode', 'decode',
      'toString', 'toDisplay', 'toView',
    ];

    return formattingPatterns.any((pattern) =>
        methodName.toLowerCase().contains(pattern));
  }

  bool _implementsDataProcessing(MethodDeclaration method, String methodName) {
    final processingPatterns = [
      'process', 'transform', 'aggregate', 'filter',
      'sort', 'group', 'reduce', 'map',
      'calculate', 'compute', 'analyze',
    ];

    return processingPatterns.any((pattern) =>
        methodName.toLowerCase().contains(pattern));
  }

  bool _callsUseCases(MethodDeclaration method, String methodName) {
    final body = method.body;
    if (body is BlockFunctionBody) {
      final bodyString = body.toString();
      final useCasePatterns = [
        'UseCase', 'execute(', 'call(',
        'Service', 'Interactor',
      ];

      return useCasePatterns.any((pattern) =>
          bodyString.contains(pattern));
    }
    return false;
  }

  bool _handlesUserInput(MethodDeclaration method, String methodName) {
    final inputPatterns = [
      'onClick', 'onTap', 'onPress', 'onSubmit',
      'handle', 'input', 'action', 'event',
      'gesture', 'touch', 'click', 'tap',
    ];

    return inputPatterns.any((pattern) =>
        methodName.toLowerCase().contains(pattern));
  }

  bool _implementsUILogic(MethodDeclaration method, String methodName) {
    final uiLogicPatterns = [
      'navigation', 'navigate', 'route',
      'dialog', 'popup', 'modal', 'alert',
      'theme', 'style', 'color', 'layout',
    ];

    return uiLogicPatterns.any((pattern) =>
        methodName.toLowerCase().contains(pattern));
  }

  bool _implementsPersistenceLogic(MethodDeclaration method, String methodName) {
    final persistencePatterns = [
      'save', 'load', 'store', 'retrieve',
      'database', 'db', 'sql', 'query',
      'insert', 'update', 'delete', 'select',
    ];

    return persistencePatterns.any((pattern) =>
        methodName.toLowerCase().contains(pattern));
  }

  bool _isValidControllerDependency(String typeName) {
    final validDependencies = [
      'UseCase', 'Service', 'Interactor',
      'Presenter', 'Formatter', 'Mapper',
      'Repository', 'Gateway', // Abstractions only
    ];

    return validDependencies.any((dep) => typeName.contains(dep)) ||
           typeName.startsWith('I') || // Interface prefix
           typeName.endsWith('Interface'); // Interface suffix
  }

  bool _isController(String className) {
    return className.endsWith('Controller') ||
           className.contains('Controller');
  }

  bool _isView(String className) {
    return className.endsWith('View') ||
           className.endsWith('Widget') ||
           className.endsWith('Screen') ||
           className.endsWith('Page');
  }

  bool _isPresenter(String className) {
    return className.endsWith('Presenter') ||
           className.endsWith('ViewModel') ||
           className.endsWith('Formatter');
  }

  bool _isModel(String className) {
    return className.endsWith('Model') ||
           className.endsWith('DTO') ||
           className.endsWith('Data') ||
           className.endsWith('Info');
  }

  bool _isAdapterLayerFile(String filePath) {
    final adapterPaths = [
      '/adapters/', '\\adapters\\',
      '/interface_adapters/', '\\interface_adapters\\',
      '/controllers/', '\\controllers\\',
      '/presenters/', '\\presenters\\',
      '/views/', '\\views\\',
      '/ui/', '\\ui\\',
      '/presentation/', '\\presentation\\',
    ];

    return adapterPaths.any((path) => filePath.contains(path));
  }
}