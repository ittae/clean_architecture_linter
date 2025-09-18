import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Enforces Single Responsibility Principle in UseCase classes.
///
/// This rule ensures that UseCase classes follow the Single Responsibility Principle:
/// - Each UseCase should handle exactly one business operation
/// - Should have only one public execution method (call() or execute())
/// - Should not contain multiple business concerns
/// - Should be focused and cohesive
///
/// Benefits of single responsibility UseCases:
/// - Better testability and maintainability
/// - Clear separation of business operations
/// - Easier to understand and modify
/// - Promotes composition over complex inheritance
/// - Enables better dependency injection patterns
class UseCaseSingleResponsibilityRule extends DartLintRule {
  const UseCaseSingleResponsibilityRule() : super(code: _code);

  static const _code = LintCode(
    name: 'usecase_single_responsibility',
    problemMessage:
        'UseCase must follow Single Responsibility Principle with one focused business operation.',
    correctionMessage:
        'Split complex UseCase into multiple focused UseCases, each handling a single business operation.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((node) {
      _checkUseCaseResponsibility(node, reporter, resolver);
    });
  }

  void _checkUseCaseResponsibility(
    ClassDeclaration node,
    DiagnosticReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;

    // Only check files in domain layer
    if (!_isDomainLayerFile(filePath)) return;

    final className = node.name.lexeme;

    // Check if this is a UseCase class
    if (!_isUseCaseClass(className, filePath)) return;

    // Analyze the UseCase for various SRP violations
    final analysis = _analyzeUseCaseStructure(node);

    // Check for multiple public methods (classic SRP violation)
    _checkMethodCount(analysis, reporter);

    // Check for complex business logic patterns
    _checkBusinessLogicComplexity(analysis, reporter);

    // Check for multiple concerns within the UseCase
    _checkMultipleConcerns(analysis, reporter);

    // Check for proper UseCase naming and structure
    _checkUseCaseNaming(node, reporter);
  }

  UseCaseAnalysis _analyzeUseCaseStructure(ClassDeclaration node) {
    final publicMethods = <MethodDeclaration>[];
    final privateMethods = <MethodDeclaration>[];
    final fields = <FieldDeclaration>[];

    for (final member in node.members) {
      if (member is MethodDeclaration) {
        if (member.name.lexeme.startsWith('_')) {
          privateMethods.add(member);
        } else if (!member.isGetter && !member.isSetter && !member.isStatic) {
          publicMethods.add(member);
        }
      } else if (member is FieldDeclaration) {
        fields.add(member);
      }
    }

    final mainMethods = publicMethods.where((method) {
      final name = method.name.lexeme;
      return name == 'call' || name == 'execute';
    }).toList();

    return UseCaseAnalysis(
      className: node.name.lexeme,
      publicMethods: publicMethods,
      privateMethods: privateMethods,
      fields: fields,
      mainMethods: mainMethods,
    );
  }

  void _checkMethodCount(
    UseCaseAnalysis analysis,
    DiagnosticReporter reporter,
  ) {
    if (analysis.mainMethods.isEmpty) {
      final code = LintCode(
        name: 'usecase_single_responsibility',
        problemMessage:
            'UseCase missing main execution method (call() or execute())',
        correctionMessage:
            'Add a call() or execute() method as the main entry point for the UseCase.',
      );
      // Report on the first public method or class if no public methods
      final target = analysis.publicMethods.isNotEmpty
          ? analysis.publicMethods.first
          : null;
      if (target != null) {
        reporter.atNode(target, code);
      }
    }

    if (analysis.mainMethods.length > 1) {
      for (int i = 1; i < analysis.mainMethods.length; i++) {
        final code = LintCode(
          name: 'usecase_single_responsibility',
          problemMessage: 'Multiple main execution methods detected',
          correctionMessage:
              'Keep only one call() or execute() method per UseCase.',
        );
        reporter.atNode(analysis.mainMethods[i], code);
      }
    }

    // Check for extra public methods beyond the main execution method
    final extraMethods = analysis.publicMethods.where((method) {
      final name = method.name.lexeme;
      return name != 'call' && name != 'execute';
    }).toList();

    for (final method in extraMethods) {
      if (!_isAllowedAuxiliaryMethod(method.name.lexeme)) {
        final code = LintCode(
          name: 'usecase_single_responsibility',
          problemMessage:
              'Extra public method violates Single Responsibility: ${method.name.lexeme}',
          correctionMessage:
              'Move this method to a separate UseCase or make it private if it\'s a helper method.',
        );
        reporter.atNode(method, code);
      }
    }
  }

  void _checkBusinessLogicComplexity(
    UseCaseAnalysis analysis,
    DiagnosticReporter reporter,
  ) {
    // Check if the main method is too complex (indication of multiple responsibilities)
    for (final method in analysis.mainMethods) {
      final complexity = _calculateMethodComplexity(method);
      if (complexity.isHighlyComplex) {
        final code = LintCode(
          name: 'usecase_single_responsibility',
          problemMessage:
              'UseCase main method is too complex, suggesting multiple responsibilities',
          correctionMessage:
              'Break down complex logic into smaller, focused UseCases or extract private helper methods.',
        );
        reporter.atNode(method, code);
      }
    }
  }

  void _checkMultipleConcerns(
    UseCaseAnalysis analysis,
    DiagnosticReporter reporter,
  ) {
    // Check if UseCase has too many dependencies (indication of multiple concerns)
    final dependencies = _countDependencies(analysis.fields);
    if (dependencies > 3) {
      final code = LintCode(
        name: 'usecase_single_responsibility',
        problemMessage:
            'UseCase has too many dependencies ($dependencies), suggesting multiple concerns',
        correctionMessage:
            'Consider splitting into multiple focused UseCases with fewer dependencies each.',
      );
      // Report on constructor or first field
      if (analysis.fields.isNotEmpty) {
        reporter.atNode(analysis.fields.first, code);
      }
    }
  }

  void _checkUseCaseNaming(ClassDeclaration node, DiagnosticReporter reporter) {
    final className = node.name.lexeme;

    // Check if UseCase name is too generic or suggests multiple responsibilities
    if (_isGenericUseCaseName(className)) {
      final code = LintCode(
        name: 'usecase_single_responsibility',
        problemMessage: 'UseCase name is too generic: $className',
        correctionMessage:
            'Use specific, action-oriented names like "CreateUserUseCase" or "ValidateEmailUseCase".',
      );
      reporter.atNode(node, code);
    }

    // Check for compound action names suggesting multiple responsibilities
    if (_hasMultipleActions(className)) {
      final code = LintCode(
        name: 'usecase_single_responsibility',
        problemMessage: 'UseCase name suggests multiple actions: $className',
        correctionMessage:
            'Split into separate UseCases for each action (e.g., CreateAndValidateUser → CreateUser + ValidateUser).',
      );
      reporter.atNode(node, code);
    }
  }

  bool _isAllowedAuxiliaryMethod(String methodName) {
    // Allow certain auxiliary methods that don't violate SRP
    final allowedMethods = [
      'toString', 'hashCode', 'operator==',
      // Validation methods that support the main operation
      'validate', 'isValid',
    ];
    return allowedMethods.contains(methodName) ||
        methodName.startsWith('validate') ||
        methodName.startsWith('isValid');
  }

  MethodComplexity _calculateMethodComplexity(MethodDeclaration method) {
    var cyclomaticComplexity = 1; // Base complexity
    var statementCount = 0;

    void countComplexity(AstNode node) {
      if (node is IfStatement) cyclomaticComplexity++;
      if (node is WhileStatement) cyclomaticComplexity++;
      if (node is ForStatement) cyclomaticComplexity++;
      if (node is SwitchStatement) cyclomaticComplexity += node.members.length;
      if (node is TryStatement) cyclomaticComplexity++;
      if (node is ExpressionStatement) statementCount++;

      for (var child in node.childEntities) {
        if (child is AstNode) countComplexity(child);
      }
    }

    countComplexity(method);

    return MethodComplexity(
      cyclomaticComplexity: cyclomaticComplexity,
      statementCount: statementCount,
      isHighlyComplex: cyclomaticComplexity > 10 || statementCount > 20,
    );
  }

  int _countDependencies(List<FieldDeclaration> fields) {
    return fields.where((field) => field.fields.isFinal).length;
  }

  bool _isGenericUseCaseName(String className) {
    final genericNames = [
      'UseCase',
      'BusinessUseCase',
      'DomainUseCase',
      'ServiceUseCase',
      'ManagerUseCase',
      'HandlerUseCase',
    ];
    return genericNames.contains(className);
  }

  bool _hasMultipleActions(String className) {
    final multipleActionPatterns = [
      'And',
      'Or',
      'Plus',
      'With',
      'CreateAndUpdate',
      'SaveAndValidate',
      'FetchAndProcess',
    ];
    return multipleActionPatterns.any((pattern) => className.contains(pattern));
  }

  bool _isDomainLayerFile(String filePath) {
    return filePath.contains('/domain/') || filePath.contains('\\domain\\');
  }

  bool _isUseCaseClass(String className, String filePath) {
    return className.endsWith('UseCase') ||
        className.endsWith('Usecase') ||
        filePath.contains('/usecases/') ||
        filePath.contains('\\usecases\\');
  }
}

/// Analysis result for a UseCase class structure
class UseCaseAnalysis {
  final String className;
  final List<MethodDeclaration> publicMethods;
  final List<MethodDeclaration> privateMethods;
  final List<FieldDeclaration> fields;
  final List<MethodDeclaration> mainMethods;

  const UseCaseAnalysis({
    required this.className,
    required this.publicMethods,
    required this.privateMethods,
    required this.fields,
    required this.mainMethods,
  });
}

/// Method complexity analysis for UseCase methods
class MethodComplexity {
  final int cyclomaticComplexity;
  final int statementCount;
  final bool isHighlyComplex;

  const MethodComplexity({
    required this.cyclomaticComplexity,
    required this.statementCount,
    required this.isHighlyComplex,
  });
}
