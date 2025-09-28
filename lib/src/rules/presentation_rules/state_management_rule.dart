import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../clean_architecture_linter_base.dart';

/// Enforces proper state management patterns in Flutter Clean Architecture.
///
/// This rule validates that presentation layer follows proper state management:
/// - UI widgets should not contain business logic or state management
/// - State should be managed through recognized patterns (Provider, Bloc, Riverpod)
/// - Direct repository/UseCase calls should go through state management
/// - setState should be used appropriately in StatefulWidgets
/// - Complex state logic should be delegated to dedicated classes
///
/// Supported state management patterns:
/// - Provider/ChangeNotifier pattern
/// - Riverpod providers
/// - BLoC pattern (flutter_bloc)
/// - Custom state management with proper separation
class StateManagementRule extends CleanArchitectureLintRule {
  const StateManagementRule() : super(code: _code);

  static const _code = LintCode(
    name: 'state_management_pattern',
    problemMessage: 'State management violates Clean Architecture principles.',
    correctionMessage: 'Use proper state management patterns and separate business logic from UI components.',
  );

  @override
  void runRule(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((node) {
      _checkStateManagementPattern(node, reporter, resolver);
    });

    context.registry.addMethodInvocation((node) {
      _checkStateMethodUsage(node, reporter, resolver);
    });

    context.registry.addImportDirective((node) {
      _checkStateManagementImports(node, reporter, resolver);
    });
  }

  void _checkStateManagementPattern(
    ClassDeclaration node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {

    final className = node.name.lexeme;
    final analysis = _analyzeClassForStateManagement(node);

    // Check different types of classes
    if (_isWidgetClass(className, node)) {
      _checkWidgetStateManagement(analysis, reporter, node);
    } else if (_isStateManagementClass(className, node)) {
      _checkStateManagementClassCompliance(analysis, reporter, node);
    }
  }

  void _checkStateMethodUsage(
    MethodInvocation node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {

    final methodName = node.methodName.name;

    // Check for inappropriate setState usage
    if (methodName == 'setState' && _isInappropriateSetStateUsage(node)) {
      final code = LintCode(
        name: 'state_management_pattern',
        problemMessage: 'setState called with business logic or complex operations',
        correctionMessage:
            'Move business logic to state management classes. Use setState only for simple UI state changes.',
      );
      reporter.atNode(node, code);
    }

    // Check for direct business calls without state management
    if (_isBusinessLogicCall(methodName, node) && _isDirectlyInWidget(node)) {
      final code = LintCode(
        name: 'state_management_pattern',
        problemMessage: 'Direct business logic call in widget: $methodName',
        correctionMessage: 'Handle business logic through state management patterns (Provider, Bloc, Riverpod).',
      );
      reporter.atNode(node, code);
    }
  }

  void _checkStateManagementImports(
    ImportDirective node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;

    final importUri = node.uri.stringValue;
    if (importUri == null) return;

    // Check if widget files are importing domain/data layers directly
    if (_isWidgetFile(filePath) && _isBusinessLayerImport(importUri)) {
      final code = LintCode(
        name: 'state_management_pattern',
        problemMessage: 'Widget file importing business layer directly',
        correctionMessage: 'Widgets should access business logic through state management, not direct imports.',
      );
      reporter.atNode(node, code);
    }
  }


  bool _isWidgetClass(String className, ClassDeclaration node) {
    // Check if extends StatefulWidget or StatelessWidget
    final extendsClause = node.extendsClause;
    if (extendsClause != null) {
      final superclass = extendsClause.superclass.name2.lexeme;
      return superclass == 'StatefulWidget' || superclass == 'StatelessWidget' || superclass.endsWith('Widget');
    }

    // Check for common widget naming patterns
    final widgetSuffixes = [
      'Widget',
      'Page',
      'Screen',
      'Dialog',
      'Modal',
      'Popup',
      'Sheet',
      'BottomSheet',
      'Card',
      'Item',
      'Tile',
      'View',
      'Component'
    ];

    return widgetSuffixes.any((suffix) => className.endsWith(suffix));
  }

  StateManagementAnalysis _analyzeClassForStateManagement(ClassDeclaration node) {
    final methods = <MethodDeclaration>[];
    final fields = <FieldDeclaration>[];
    bool hasBusinessLogicCalls = false;
    bool hasStateManagementPattern = false;
    bool hasComplexStateLogic = false;
    bool extendsStateManagementClass = false;

    // Check inheritance
    final extendsClause = node.extendsClause;
    if (extendsClause != null) {
      final superclass = extendsClause.superclass.name2.lexeme;
      extendsStateManagementClass = _isRecognizedStateManagementClass(superclass);
    }

    // Analyze members
    for (final member in node.members) {
      if (member is MethodDeclaration) {
        methods.add(member);
        if (_hasBusinessLogicInMethod(member)) {
          hasBusinessLogicCalls = true;
        }
        if (_hasComplexStateManipulation(member)) {
          hasComplexStateLogic = true;
        }
      } else if (member is FieldDeclaration) {
        fields.add(member);
        if (_isStateManagementField(member)) {
          hasStateManagementPattern = true;
        }
      }
    }

    return StateManagementAnalysis(
      className: node.name.lexeme,
      methods: methods,
      fields: fields,
      hasBusinessLogicCalls: hasBusinessLogicCalls,
      hasStateManagementPattern: hasStateManagementPattern || extendsStateManagementClass,
      hasComplexStateLogic: hasComplexStateLogic,
      extendsStateManagementClass: extendsStateManagementClass,
    );
  }

  void _checkWidgetStateManagement(
    StateManagementAnalysis analysis,
    ErrorReporter reporter,
    ClassDeclaration node,
  ) {
    // Skip simple UI components that don't need state management
    if (_isSimpleUIComponent(analysis.className)) {
      return;
    }

    // Widget should not have complex business logic
    if (analysis.hasBusinessLogicCalls && !analysis.hasStateManagementPattern) {
      final code = LintCode(
        name: 'state_management_pattern',
        problemMessage: 'Widget "${analysis.className}" has business logic without proper state management',
        correctionMessage: 'Use Provider, Bloc, or Riverpod to manage business logic separate from UI.',
      );
      reporter.atNode(node, code);
    }

    // Check for complex state logic in widgets
    if (analysis.hasComplexStateLogic) {
      final code = LintCode(
        name: 'state_management_pattern',
        problemMessage: 'Widget "${analysis.className}" contains complex state management logic',
        correctionMessage: 'Extract complex state logic to dedicated state management classes.',
      );
      reporter.atNode(node, code);
    }

    // Check specific methods
    for (final method in analysis.methods) {
      final methodName = method.name.lexeme;

      if (methodName == 'build' && _hasSideEffectsInBuild(method)) {
        final code = LintCode(
          name: 'state_management_pattern',
          problemMessage: 'Build method contains side effects or business logic',
          correctionMessage: 'Build method should be pure. Move side effects to lifecycle methods or state management.',
        );
        reporter.atNode(method, code);
      }
    }
  }

  void _checkStateManagementClassCompliance(
    StateManagementAnalysis analysis,
    ErrorReporter reporter,
    ClassDeclaration node,
  ) {
    // State management classes should follow proper patterns
    if (!analysis.extendsStateManagementClass && !_implementsStateManagementInterface(node)) {
      final code = LintCode(
        name: 'state_management_pattern',
        problemMessage: 'State management class "${analysis.className}" should extend recognized pattern',
        correctionMessage:
            'Extend ChangeNotifier, StateNotifier, Bloc, or implement proper state management interface.',
      );
      reporter.atNode(node, code);
    }
  }

  bool _hasBusinessLogicInMethod(MethodDeclaration method) {
    final visitor = _EnhancedBusinessLogicVisitor();
    method.accept(visitor);
    return visitor.hasBusinessLogic;
  }

  bool _hasComplexStateManipulation(MethodDeclaration method) {
    final visitor = _StateComplexityVisitor();
    method.accept(visitor);
    return visitor.hasComplexState;
  }

  bool _hasSideEffectsInBuild(MethodDeclaration method) {
    final visitor = _SideEffectVisitor();
    method.accept(visitor);
    return visitor.hasSideEffects;
  }

  bool _isStateManagementField(FieldDeclaration field) {
    final type = field.fields.type;
    if (type is NamedType) {
      final typeName = type.name2.lexeme;
      return _isRecognizedStateManagementType(typeName);
    }
    return false;
  }

  bool _isStateManagementClass(String className, ClassDeclaration node) {
    // Check class naming patterns
    final stateManagementSuffixes = [
      'Provider',
      'Notifier',
      'Controller',
      'Bloc',
      'Cubit',
      'Store',
      'ViewModel',
      'Manager',
      'StateManager'
    ];

    if (stateManagementSuffixes.any((suffix) => className.endsWith(suffix))) {
      return true;
    }

    // Check inheritance
    final extendsClause = node.extendsClause;
    if (extendsClause != null) {
      final superclass = extendsClause.superclass.name2.lexeme;
      return _isRecognizedStateManagementClass(superclass);
    }

    return false;
  }

  bool _isRecognizedStateManagementClass(String className) {
    final recognizedClasses = [
      'ChangeNotifier',
      'ValueNotifier',
      'StateNotifier',
      'Bloc',
      'Cubit',
      'Store',
      'GetxController'
    ];
    return recognizedClasses.contains(className);
  }

  bool _isRecognizedStateManagementType(String typeName) {
    final recognizedTypes = [
      'ChangeNotifier',
      'ValueNotifier',
      'StateNotifier',
      'Provider',
      'Bloc',
      'Cubit',
      'StateProvider',
      'FutureProvider',
      'StreamProvider'
    ];
    return recognizedTypes.any((type) => typeName.contains(type));
  }

  bool _implementsStateManagementInterface(ClassDeclaration node) {
    final implementsClause = node.implementsClause;
    if (implementsClause != null) {
      for (final interface in implementsClause.interfaces) {
        final interfaceName = interface.name2.lexeme;
        if (_isRecognizedStateManagementClass(interfaceName)) {
          return true;
        }
      }
    }
    return false;
  }

  bool _isInappropriateSetStateUsage(MethodInvocation node) {
    final argumentList = node.argumentList;
    if (argumentList.arguments.isNotEmpty) {
      final callback = argumentList.arguments.first;

      // Check if the callback contains business logic
      final visitor = _EnhancedBusinessLogicVisitor();
      callback.accept(visitor);
      return visitor.hasBusinessLogic;
    }
    return false;
  }

  bool _isBusinessLogicCall(String methodName, MethodInvocation node) {
    // First check if this is a UI utility class - these are not business logic
    final target = node.target;
    if (target is SimpleIdentifier) {
      final targetName = target.name;
      if (_isUIUtilityClass(targetName)) {
        return false;
      }

      // Check if target is a business object
      final targetNameLower = targetName.toLowerCase();
      if (targetNameLower.contains('usecase') ||
          targetNameLower.contains('repository') ||
          targetNameLower.contains('service')) {
        return true;
      }
    }

    // Check if method name indicates UI utility (should not be business logic)
    if (_isUIUtilityMethod(methodName)) {
      return false;
    }

    // More specific business method patterns
    final businessMethods = [
      'save',
      'update',
      'delete',
      'create',
      'fetch',
      'load',
      'post',
      'put',
      'patch',
      'call',
      'execute'
    ];

    // Check for exact matches or starts with pattern (more precise than contains)
    final methodNameLower = methodName.toLowerCase();
    if (businessMethods.any((method) =>
        methodNameLower == method ||
        methodNameLower.startsWith(method) && methodNameLower.length > method.length)) {
      return true;
    }

    // Special handling for 'get' - only consider it business logic if it's data-related
    if (methodNameLower.startsWith('get')) {
      // UI-related getters are not business logic
      if (methodNameLower.contains('color') ||
          methodNameLower.contains('theme') ||
          methodNameLower.contains('style') ||
          methodNameLower.contains('config') ||
          methodNameLower.contains('button') ||
          methodNameLower.contains('icon') ||
          methodNameLower.contains('font') ||
          methodNameLower.contains('size') ||
          methodNameLower.contains('padding') ||
          methodNameLower.contains('margin')) {
        return false;
      }

      // Data-related getters are business logic
      if (methodNameLower.contains('user') ||
          methodNameLower.contains('data') ||
          methodNameLower.contains('model') ||
          methodNameLower.contains('entity') ||
          methodNameLower.contains('list') ||
          methodNameLower.contains('item') ||
          methodNameLower.contains('record')) {
        return true;
      }
    }

    return false;
  }

  bool _isUIUtilityClass(String className) {
    final uiUtilityPatterns = [
      'UIConfig',
      'Theme',
      'Style',
      'Colors',
      'Color',
      'Assets',
      'Icons',
      'Fonts',
      'Decoration',
      'TextStyle',
      'ButtonStyle',
      'AppBar',
      'Scaffold'
    ];

    return uiUtilityPatterns.any((pattern) => className.contains(pattern));
  }

  bool _isUIUtilityMethod(String methodName) {
    final uiMethodPatterns = [
      'getColor',
      'getTheme',
      'getStyle',
      'getIcon',
      'getFont',
      'getDecoration',
      'getButtonColors',
      'getTextStyle',
      'getButtonStyle',
      'getPadding',
      'getMargin',
      'getSize',
      'getHeight',
      'getWidth'
    ];

    return uiMethodPatterns.any((pattern) =>
        methodName == pattern || methodName.startsWith(pattern));
  }

  bool _isSimpleUIComponent(String className) {
    // Simple UI components that typically don't need complex state management
    final simpleComponentSuffixes = [
      'Dialog',
      'Modal',
      'Popup',
      'Sheet',
      'BottomSheet',
      'AlertDialog',
      'ConfirmationDialog',
      'Card',
      'Item',
      'Tile',
      'Button',
      'Icon',
      'Text',
      'Image',
      'Avatar',
      'Badge',
      'Chip',
      'Tag',
      'Label',
      'Divider',
      'Spacer'
    ];

    // Also check for patterns that indicate simple components
    final simplePatterns = [
      'Confirmation',
      'Alert',
      'Info',
      'Warning',
      'Error',
      'Success'
    ];

    return simpleComponentSuffixes.any((suffix) => className.endsWith(suffix)) ||
           simplePatterns.any((pattern) => className.contains(pattern));
  }

  bool _isDirectlyInWidget(MethodInvocation node) {
    // Check if this call is directly in a widget class, not through state management
    var parent = node.parent;
    while (parent != null) {
      if (parent is ClassDeclaration) {
        final className = parent.name.lexeme;
        return _isWidgetClass(className, parent) && !_isStateManagementClass(className, parent);
      }
      parent = parent.parent;
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
        importUri.contains('usecase');
  }
}

/// Analysis result for state management compliance
class StateManagementAnalysis {
  final String className;
  final List<MethodDeclaration> methods;
  final List<FieldDeclaration> fields;
  final bool hasBusinessLogicCalls;
  final bool hasStateManagementPattern;
  final bool hasComplexStateLogic;
  final bool extendsStateManagementClass;

  StateManagementAnalysis({
    required this.className,
    required this.methods,
    required this.fields,
    required this.hasBusinessLogicCalls,
    required this.hasStateManagementPattern,
    required this.hasComplexStateLogic,
    required this.extendsStateManagementClass,
  });
}

class _EnhancedBusinessLogicVisitor extends RecursiveAstVisitor<void> {
  bool hasBusinessLogic = false;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final methodName = node.methodName.name;
    final target = node.target;

    // Check for business logic method calls
    if (_isBusinessLogicMethod(methodName)) {
      hasBusinessLogic = true;
    }

    // Check for UseCase/Repository calls
    if (target is SimpleIdentifier) {
      final targetName = target.name.toLowerCase();
      if (targetName.contains('usecase') ||
          targetName.contains('repository') ||
          targetName.contains('service') ||
          targetName.contains('datasource')) {
        hasBusinessLogic = true;
      }
    }

    // Check for HTTP client calls
    if (_isHttpClientCall(methodName, target)) {
      hasBusinessLogic = true;
    }

    super.visitMethodInvocation(node);
  }

  bool _isBusinessLogicMethod(String methodName) {
    final businessLogicMethods = [
      'save',
      'update',
      'delete',
      'create',
      'fetch',
      'load',
      'post',
      'get',
      'put',
      'patch',
      'call',
      'execute',
      'validate',
      'calculate',
      'compute',
      'process'
    ];

    return businessLogicMethods.any(
      (method) => methodName.toLowerCase().contains(method),
    );
  }

  bool _isHttpClientCall(String methodName, Expression? target) {
    final httpMethods = ['get', 'post', 'put', 'patch', 'delete'];
    if (!httpMethods.contains(methodName.toLowerCase())) return false;

    if (target is SimpleIdentifier) {
      final targetName = target.name.toLowerCase();
      return targetName.contains('client') || targetName.contains('dio') || targetName.contains('http');
    }
    return false;
  }
}

class _StateComplexityVisitor extends RecursiveAstVisitor<void> {
  bool hasComplexState = false;
  int stateModificationCount = 0;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final methodName = node.methodName.name;

    // Count state modifications
    if (_isStateModification(methodName)) {
      stateModificationCount++;
      if (stateModificationCount > 2) {
        hasComplexState = true;
      }
    }

    super.visitMethodInvocation(node);
  }

  @override
  void visitIfStatement(IfStatement node) {
    // Complex conditional state logic
    final condition = node.expression.toString();
    if (condition.length > 50) {
      // Arbitrary complexity threshold
      hasComplexState = true;
    }
    super.visitIfStatement(node);
  }

  bool _isStateModification(String methodName) {
    final stateModificationMethods = [
      'setstate',
      'notifylisteners',
      'emit',
      'add',
      'sink',
      'update',
      'refresh',
      'invalidate'
    ];
    return stateModificationMethods.any((method) => methodName.toLowerCase().contains(method));
  }
}

class _SideEffectVisitor extends RecursiveAstVisitor<void> {
  bool hasSideEffects = false;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final methodName = node.methodName.name;

    // Check for side effects in build method
    if (_isSideEffect(methodName)) {
      hasSideEffects = true;
    }

    super.visitMethodInvocation(node);
  }

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    // Only consider assignments to external state as side effects
    // Local variable declarations and computations are not side effects
    final leftSide = node.leftHandSide;

    // Skip local variable declarations (final/var assignments)
    if (leftSide is SimpleIdentifier) {
      final parent = node.parent;
      if (parent is VariableDeclaration) {
        // This is a local variable declaration, not a side effect
        super.visitAssignmentExpression(node);
        return;
      }

      // Check if this is modifying external state/fields
      if (_isExternalStateModification(leftSide.name)) {
        hasSideEffects = true;
      }
    } else {
      // Property assignments (obj.property = value) are side effects
      hasSideEffects = true;
    }

    super.visitAssignmentExpression(node);
  }

  bool _isSideEffect(String methodName) {
    final sideEffectMethods = [
      'setstate',
      'add',
      'remove',
      'clear',
      'update',
      'post',
      'get',
      'fetch',
      'save',
      'delete',
      'print',
      'log',
      'debug'
    ];
    return sideEffectMethods.any((method) => methodName.toLowerCase().contains(method));
  }

  bool _isExternalStateModification(String variableName) {
    // Check if this is modifying widget state/fields that would be side effects
    final externalStatePatterns = [
      '_', // Private fields that might be widget state
      'widget.', // Widget properties
      'state.', // State properties
    ];

    // Skip if it looks like a local variable (starts with lowercase, no underscores for private)
    if (variableName.isNotEmpty &&
        variableName[0] == variableName[0].toLowerCase() &&
        !variableName.startsWith('_')) {
      return false;
    }

    return externalStatePatterns.any((pattern) => variableName.startsWith(pattern));
  }
}
