import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Consolidated rule for UseCase validation in Clean Architecture.
///
/// This rule combines multiple UseCase checks:
/// 1. **Single Responsibility**: One business operation per UseCase
/// 2. **Independence**: No external framework dependencies
/// 3. **Orchestration**: Proper entity and repository coordination
/// 4. **Application Rules**: Contains application-specific logic only
///
/// UseCases should:
/// - Have exactly one public execution method (call() or execute())
/// - Depend only on entities and abstract repositories
/// - Orchestrate business flow without containing enterprise rules
/// - Be independent of UI, database, and framework concerns
/// - Be easily testable with mock dependencies
class ConsolidatedUseCaseRule extends DartLintRule {
  const ConsolidatedUseCaseRule() : super(code: _code);

  static const _code = LintCode(
    name: 'consolidated_usecase_rule',
    problemMessage: 'UseCase violates Clean Architecture principles',
    correctionMessage:
        'Ensure UseCase has single responsibility, proper orchestration, and remains independent of external concerns',
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((node) {
      _validateUseCase(node, reporter, resolver);
    });

    context.registry.addImportDirective((node) {
      _validateImports(node, reporter, resolver);
    });
  }

  void _validateUseCase(
    ClassDeclaration node,
    DiagnosticReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    if (!_isUseCaseFile(filePath)) return;

    final className = node.name.lexeme;
    final violations = <UseCaseViolation>[];

    // Analyze UseCase structure
    final analysis = _analyzeUseCaseClass(node);

    // 1. Check Single Responsibility
    violations.addAll(_checkSingleResponsibility(analysis, className));

    // 2. Check Independence from external concerns
    violations.addAll(_checkIndependence(node));

    // 3. Check Orchestration pattern
    violations.addAll(_checkOrchestration(analysis));

    // 4. Check Application-specific rules
    violations.addAll(_checkApplicationRules(analysis));

    // Report violations
    for (final violation in violations) {
      final code = _createLintCode(violation);
      reporter.atNode(violation.node ?? node, code);
    }
  }

  void _validateImports(
    ImportDirective node,
    DiagnosticReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    if (!_isUseCaseFile(filePath)) return;

    final importUri = node.uri.stringValue;
    if (importUri == null) return;

    final violation = _checkImportViolation(importUri);
    if (violation != null) {
      final code = _createLintCode(violation);
      reporter.atNode(node, code);
    }
  }

  UseCaseAnalysis _analyzeUseCaseClass(ClassDeclaration node) {
    final publicMethods = <MethodDeclaration>[];
    final privateMethods = <MethodDeclaration>[];
    final fields = <FieldDeclaration>[];
    final constructorParams = <FormalParameter>[];
    bool hasRepositoryDep = false;
    bool hasEntityUsage = false;
    bool hasExternalDep = false;

    for (final member in node.members) {
      if (member is MethodDeclaration) {
        if (member.name.lexeme.startsWith('_')) {
          privateMethods.add(member);
        } else if (!member.isGetter && !member.isSetter && !member.isStatic) {
          publicMethods.add(member);
        }

        // Check for entity usage and external dependencies
        final bodyString = member.body.toString();
        if (_containsEntityUsage(bodyString)) hasEntityUsage = true;
        if (_containsExternalDependency(bodyString)) hasExternalDep = true;
      } else if (member is FieldDeclaration) {
        fields.add(member);

        final type = member.fields.type;
        if (type is NamedType) {
          final typeName = type.name.lexeme;
          if (typeName.contains('Repository')) hasRepositoryDep = true;
          if (_isExternalDependencyType(typeName)) hasExternalDep = true;
        }
      } else if (member is ConstructorDeclaration) {
        constructorParams.addAll(member.parameters.parameters);
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
      constructorParams: constructorParams,
      hasRepositoryDep: hasRepositoryDep,
      hasEntityUsage: hasEntityUsage,
      hasExternalDep: hasExternalDep,
    );
  }

  List<UseCaseViolation> _checkSingleResponsibility(
    UseCaseAnalysis analysis,
    String className,
  ) {
    final violations = <UseCaseViolation>[];

    // Must have exactly one main execution method
    if (analysis.mainMethods.isEmpty) {
      violations.add(UseCaseViolation(
        type: ViolationType.singleResponsibility,
        message: 'UseCase missing main execution method (call() or execute())',
        suggestion: 'Add a call() or execute() method as the single entry point',
      ));
    } else if (analysis.mainMethods.length > 1) {
      violations.add(UseCaseViolation(
        type: ViolationType.singleResponsibility,
        message: 'UseCase has multiple main execution methods',
        suggestion: 'Keep only one call() or execute() method',
        node: analysis.mainMethods[1],
      ));
    }

    // Check for extra public methods beyond main execution
    final extraMethods = analysis.publicMethods.where((method) {
      final name = method.name.lexeme;
      return name != 'call' && name != 'execute' && !_isAllowedMethod(name);
    }).toList();

    for (final method in extraMethods) {
      violations.add(UseCaseViolation(
        type: ViolationType.singleResponsibility,
        message: 'Extra public method violates single responsibility: ${method.name.lexeme}',
        suggestion: 'Move to separate UseCase or make private',
        node: method,
      ));
    }

    // Check for too many dependencies (complexity indicator)
    if (analysis.fields.length > 3) {
      violations.add(UseCaseViolation(
        type: ViolationType.singleResponsibility,
        message: 'Too many dependencies (${analysis.fields.length}) suggests multiple responsibilities',
        suggestion: 'Consider splitting into multiple UseCases',
      ));
    }

    return violations;
  }

  List<UseCaseViolation> _checkIndependence(ClassDeclaration node) {
    final violations = <UseCaseViolation>[];

    // Check inheritance - UseCase should not extend framework classes
    final extendsClause = node.extendsClause;
    if (extendsClause != null) {
      final superclass = extendsClause.superclass;
      final superName = superclass.name.lexeme;
      if (_isFrameworkClass(superName)) {
        violations.add(UseCaseViolation(
          type: ViolationType.independence,
          message: 'UseCase extends framework class: $superName',
          suggestion: 'UseCase should not extend framework-specific classes',
          node: superclass,
        ));
      }
    }

    // Check implementations
    final implementsClause = node.implementsClause;
    if (implementsClause != null) {
      for (final interface in implementsClause.interfaces) {
        final interfaceName = interface.name.lexeme;
        if (_isFrameworkInterface(interfaceName)) {
          violations.add(UseCaseViolation(
            type: ViolationType.independence,
            message: 'UseCase implements framework interface: $interfaceName',
            suggestion: 'UseCase should not implement framework-specific interfaces',
            node: interface,
          ));
        }
      }
    }

    return violations;
  }

  List<UseCaseViolation> _checkOrchestration(UseCaseAnalysis analysis) {
    final violations = <UseCaseViolation>[];

    // UseCase should have repository dependencies for data operations
    if (!analysis.hasRepositoryDep && analysis.mainMethods.isNotEmpty) {
      // Check if it's a simple UseCase that might not need repository
      bool needsRepository = false;
      for (final method in analysis.mainMethods) {
        final bodyString = method.body.toString();
        if (_suggestsDataOperation(bodyString)) {
          needsRepository = true;
          break;
        }
      }

      if (needsRepository) {
        violations.add(UseCaseViolation(
          type: ViolationType.orchestration,
          message: 'UseCase appears to need data but has no repository dependency',
          suggestion: 'Inject repository abstractions for data operations',
        ));
      }
    }

    // Check for direct infrastructure calls
    for (final method in analysis.publicMethods) {
      final bodyString = method.body.toString();
      if (_containsDirectInfrastructureCall(bodyString)) {
        violations.add(UseCaseViolation(
          type: ViolationType.orchestration,
          message: 'Direct infrastructure call in UseCase method: ${method.name.lexeme}',
          suggestion: 'Use repository abstractions instead of direct infrastructure calls',
          node: method,
        ));
      }
    }

    return violations;
  }

  List<UseCaseViolation> _checkApplicationRules(UseCaseAnalysis analysis) {
    final violations = <UseCaseViolation>[];

    // Check for enterprise-wide business rules (should be in entities)
    for (final method in analysis.privateMethods) {
      final methodName = method.name.lexeme;
      if (_isEnterpriseRule(methodName)) {
        violations.add(UseCaseViolation(
          type: ViolationType.applicationRules,
          message: 'Enterprise-wide business rule in UseCase: $methodName',
          suggestion: 'Move enterprise rules to entities',
          node: method,
        ));
      }
    }

    // Check for UI/presentation logic
    for (final method in analysis.publicMethods) {
      final bodyString = method.body.toString();
      if (_containsPresentationLogic(bodyString)) {
        violations.add(UseCaseViolation(
          type: ViolationType.applicationRules,
          message: 'Presentation logic in UseCase: ${method.name.lexeme}',
          suggestion: 'Remove UI/presentation concerns from UseCase',
          node: method,
        ));
      }
    }

    return violations;
  }

  UseCaseViolation? _checkImportViolation(String importUri) {
    // UI framework imports
    final uiFrameworks = [
      'package:flutter/',
      'dart:ui',
      'dart:html',
    ];
    for (final framework in uiFrameworks) {
      if (importUri.startsWith(framework)) {
        return UseCaseViolation(
          type: ViolationType.independence,
          message: 'UseCase imports UI framework: $importUri',
          suggestion: 'Remove UI dependencies from UseCase',
        );
      }
    }

    // Direct infrastructure imports
    final infraLibs = [
      'package:http/',
      'package:dio/',
      'package:sqflite/',
      'dart:io',
    ];
    for (final lib in infraLibs) {
      if (importUri.startsWith(lib)) {
        return UseCaseViolation(
          type: ViolationType.independence,
          message: 'UseCase imports infrastructure directly: $importUri',
          suggestion: 'Use repository abstractions instead',
        );
      }
    }

    // State management (should not be in UseCase)
    final stateLibs = [
      'package:provider/',
      'package:riverpod/',
      'package:bloc/',
      'package:get/',
    ];
    for (final lib in stateLibs) {
      if (importUri.startsWith(lib)) {
        return UseCaseViolation(
          type: ViolationType.independence,
          message: 'UseCase imports state management: $importUri',
          suggestion: 'State management belongs in presentation layer',
        );
      }
    }

    return null;
  }

  LintCode _createLintCode(UseCaseViolation violation) {
    return LintCode(
      name: 'consolidated_usecase_rule',
      problemMessage: violation.message,
      correctionMessage: violation.suggestion,
    );
  }

  // Helper methods
  bool _isUseCaseFile(String filePath) {
    return (filePath.contains('/domain/') || filePath.contains('\\domain\\')) &&
           (filePath.contains('/usecases/') ||
            filePath.contains('\\usecases\\') ||
            filePath.contains('/use_cases/') ||
            filePath.contains('\\use_cases\\') ||
            filePath.endsWith('_usecase.dart') ||
            filePath.endsWith('_use_case.dart'));
  }

  bool _isAllowedMethod(String methodName) {
    // Some methods are allowed as helpers
    return methodName == 'dispose' ||
           methodName == 'close' ||
           methodName.startsWith('validate');
  }

  bool _isFrameworkClass(String className) {
    return className.contains('Widget') ||
           className.contains('State') ||
           className.contains('Controller') ||
           className.contains('Bloc');
  }

  bool _isFrameworkInterface(String interfaceName) {
    return interfaceName.contains('Listener') ||
           interfaceName.contains('Observer') ||
           interfaceName.contains('Delegate');
  }

  bool _isExternalDependencyType(String typeName) {
    return typeName.contains('Client') ||
           typeName.contains('Service') ||
           typeName.contains('Manager') ||
           typeName.contains('Provider');
  }

  bool _containsEntityUsage(String bodyString) {
    return bodyString.contains('Entity') ||
           bodyString.contains('ValueObject') ||
           bodyString.contains('.validate') ||
           bodyString.contains('.isValid');
  }

  bool _containsExternalDependency(String bodyString) {
    return bodyString.contains('http.') ||
           bodyString.contains('dio.') ||
           bodyString.contains('File(') ||
           bodyString.contains('Database');
  }

  bool _suggestsDataOperation(String bodyString) {
    final dataPatterns = [
      'get', 'fetch', 'save', 'update', 'delete',
      'find', 'search', 'load', 'store', 'retrieve'
    ];
    final lower = bodyString.toLowerCase();
    return dataPatterns.any((pattern) => lower.contains(pattern));
  }

  bool _containsDirectInfrastructureCall(String bodyString) {
    final infraPatterns = [
      '.get(', '.post(', '.put(', '.delete(',
      'query(', 'execute(', 'runTransaction(',
      'File(', 'Directory(', 'Socket('
    ];
    return infraPatterns.any((pattern) => bodyString.contains(pattern));
  }

  bool _isEnterpriseRule(String methodName) {
    // Enterprise rules are general business rules
    final enterprisePatterns = [
      'calculate', 'compute', 'derive',
      'validateCore', 'checkInvariant'
    ];
    final lower = methodName.toLowerCase();
    return enterprisePatterns.any((pattern) => lower.contains(pattern));
  }

  bool _containsPresentationLogic(String bodyString) {
    final uiPatterns = [
      'Navigator', 'BuildContext', 'showDialog',
      'setState', 'Widget', 'Color',
      'Theme', 'MediaQuery'
    ];
    return uiPatterns.any((pattern) => bodyString.contains(pattern));
  }
}

class UseCaseAnalysis {
  final String className;
  final List<MethodDeclaration> publicMethods;
  final List<MethodDeclaration> privateMethods;
  final List<FieldDeclaration> fields;
  final List<MethodDeclaration> mainMethods;
  final List<FormalParameter> constructorParams;
  final bool hasRepositoryDep;
  final bool hasEntityUsage;
  final bool hasExternalDep;

  UseCaseAnalysis({
    required this.className,
    required this.publicMethods,
    required this.privateMethods,
    required this.fields,
    required this.mainMethods,
    required this.constructorParams,
    required this.hasRepositoryDep,
    required this.hasEntityUsage,
    required this.hasExternalDep,
  });
}

class UseCaseViolation {
  final ViolationType type;
  final String message;
  final String suggestion;
  final AstNode? node;

  UseCaseViolation({
    required this.type,
    required this.message,
    required this.suggestion,
    this.node,
  });
}

enum ViolationType {
  singleResponsibility,
  independence,
  orchestration,
  applicationRules,
}