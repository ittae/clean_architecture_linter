import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Validates that abstraction levels progress naturally from concrete details
/// in outer layers to abstract policies in inner layers.
///
/// Uncle Bob: "As you move inwards the level of abstraction increases.
/// The outermost circle is low level concrete detail. As you move inwards
/// the software grows more abstract, and encapsulates higher level policies.
/// The inner most circle is the most general."
///
/// This rule ensures:
/// - Each layer is more abstract than the layers outside it
/// - Concrete details are pushed to the outer layers
/// - Abstract policies dominate the inner layers
/// - The progression is smooth and consistent
/// - No abstraction inversions occur
class AbstractionProgressionRule extends DartLintRule {
  const AbstractionProgressionRule() : super(code: _code);

  static const _code = LintCode(
    name: 'abstraction_progression',
    problemMessage:
        'Abstraction progression violation: {0}',
    correctionMessage:
        'Ensure abstraction increases as you move toward inner layers.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCompilationUnit((node) {
      _analyzeFileAbstraction(node, reporter, resolver);
    });

    context.registry.addClassDeclaration((node) {
      _analyzeClassAbstraction(node, reporter, resolver);
    });

    context.registry.addMethodDeclaration((node) {
      _analyzeMethodAbstraction(node, reporter, resolver);
    });
  }

  void _analyzeFileAbstraction(
    CompilationUnit node,
    DiagnosticReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    final layer = _detectLayer(filePath);
    if (layer == null) return;

    final fileAbstraction = _analyzeFileAbstractionLevel(node);
    final expectedRange = _getExpectedAbstractionRange(layer);

    if (!_isAbstractionInRange(fileAbstraction, expectedRange)) {
      final code = LintCode(
        name: 'abstraction_progression',
        problemMessage:
            '${layer.name} layer file has inappropriate abstraction level: ${fileAbstraction.score}',
        correctionMessage:
            _getFileAbstractionAdvice(layer, fileAbstraction),
      );
      // Note: Reporting on compilation unit for file-level issues
      reporter.atElement(resolver.libraryElement);
    }
  }

  void _analyzeClassAbstraction(
    ClassDeclaration node,
    DiagnosticReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    final layer = _detectLayer(filePath);
    if (layer == null) return;

    final className = node.name.lexeme;
    final classAbstraction = _analyzeClassAbstractionLevel(node);
    final expectedRange = _getExpectedAbstractionRange(layer);

    if (!_isAbstractionInRange(classAbstraction, expectedRange)) {
      final code = LintCode(
        name: 'abstraction_progression',
        problemMessage:
            'Class $className has inappropriate abstraction for ${layer.name} layer: ${classAbstraction.score}',
        correctionMessage:
            _getClassAbstractionAdvice(layer, classAbstraction, className),
      );
      reporter.atNode(node, code);
    }

    // Check for abstraction consistency within class
    _checkIntraClassAbstractionConsistency(node, reporter, layer);
  }

  void _analyzeMethodAbstraction(
    MethodDeclaration node,
    DiagnosticReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    final layer = _detectLayer(filePath);
    if (layer == null) return;

    final methodName = node.name.lexeme;
    final methodAbstraction = _analyzeMethodAbstractionLevel(node);
    final expectedRange = _getExpectedAbstractionRange(layer);

    if (!_isAbstractionInRange(methodAbstraction, expectedRange)) {
      final code = LintCode(
        name: 'abstraction_progression',
        problemMessage:
            'Method $methodName has inappropriate abstraction for ${layer.name} layer: ${methodAbstraction.score}',
        correctionMessage:
            _getMethodAbstractionAdvice(layer, methodAbstraction, methodName),
      );
      reporter.atNode(node, code);
    }
  }

  FileAbstraction _analyzeFileAbstractionLevel(CompilationUnit node) {
    var concreteScore = 0;
    var abstractScore = 0;
    var totalElements = 0;

    // Analyze imports
    for (final directive in node.directives) {
      if (directive is ImportDirective) {
        final importUri = directive.uri.stringValue ?? '';
        totalElements++;

        if (_isConcreteImport(importUri)) {
          concreteScore++;
        } else if (_isAbstractImport(importUri)) {
          abstractScore++;
        }
      }
    }

    // Analyze top-level declarations
    for (final declaration in node.declarations) {
      totalElements++;

      if (_isConcreteDeclaration(declaration)) {
        concreteScore++;
      } else if (_isAbstractDeclaration(declaration)) {
        abstractScore++;
      }
    }

    final score = totalElements > 0
        ? (abstractScore - concreteScore) / totalElements
        : 0.0;

    return FileAbstraction(
      score: score,
      concreteElements: concreteScore,
      abstractElements: abstractScore,
      totalElements: totalElements,
    );
  }

  ClassAbstraction _analyzeClassAbstractionLevel(ClassDeclaration node) {
    var concreteScore = 0;
    var abstractScore = 0;
    var totalMembers = 0;

    // Analyze class characteristics
    final className = node.name.lexeme;
    final isAbstractClass = node.abstractKeyword != null;

    if (isAbstractClass) abstractScore++;
    if (_hasConcreteClassName(className)) concreteScore++;
    if (_hasAbstractClassName(className)) abstractScore++;

    // Analyze class members
    for (final member in node.members) {
      totalMembers++;

      if (_isConcreteMember(member)) {
        concreteScore++;
      } else if (_isAbstractMember(member)) {
        abstractScore++;
      }
    }

    // Analyze inheritance and interfaces
    final extendsClause = node.extendsClause;
    if (extendsClause != null) {
      totalMembers++;
      final superclassName = extendsClause.superclass.name.lexeme;
      if (_hasAbstractClassName(superclassName)) {
        abstractScore++;
      } else {
        concreteScore++;
      }
    }

    final implementsClause = node.implementsClause;
    if (implementsClause != null) {
      for (final interface in implementsClause.interfaces) {
        totalMembers++;
        abstractScore++; // Implementing interfaces is abstracting
      }
    }

    final score = totalMembers > 0
        ? (abstractScore - concreteScore) / totalMembers
        : 0.0;

    return ClassAbstraction(
      score: score,
      isAbstractClass: isAbstractClass,
      concreteMembers: concreteScore,
      abstractMembers: abstractScore,
      totalMembers: totalMembers,
    );
  }

  MethodAbstraction _analyzeMethodAbstractionLevel(MethodDeclaration node) {
    var concreteScore = 0;
    var abstractScore = 0;
    var totalElements = 1;

    final methodName = node.name.lexeme;
    final isAbstractMethod = node.isAbstract;
    final body = node.body;

    // Method characteristics
    if (isAbstractMethod) {
      abstractScore += 2; // Abstract methods are highly abstract
    }

    if (_hasConcreteMethodName(methodName)) {
      concreteScore++;
    } else if (_hasAbstractMethodName(methodName)) {
      abstractScore++;
    }

    // Analyze method body
    if (body != null) {
      final bodyAnalysis = _analyzeMethodBody(body);
      concreteScore += bodyAnalysis.concreteOperations;
      abstractScore += bodyAnalysis.abstractOperations;
      totalElements += bodyAnalysis.totalOperations;
    }

    // Analyze parameters
    final parameters = node.parameters?.parameters ?? [];
    for (final param in parameters) {
      if (param is SimpleFormalParameter) {
        final type = param.type;
        if (type is NamedType) {
          totalElements++;
          final typeName = type.name.lexeme;
          if (_isConcreteType(typeName)) {
            concreteScore++;
          } else if (_isAbstractType(typeName)) {
            abstractScore++;
          }
        }
      }
    }

    final score = totalElements > 0
        ? (abstractScore - concreteScore) / totalElements
        : 0.0;

    return MethodAbstraction(
      score: score,
      isAbstract: isAbstractMethod,
      concreteOperations: concreteScore,
      abstractOperations: abstractScore,
      totalOperations: totalElements,
    );
  }

  MethodBodyAnalysis _analyzeMethodBody(FunctionBody body) {
    final bodyString = body.toString().toLowerCase();
    var concreteOps = 0;
    var abstractOps = 0;
    var totalOps = 0;

    // Concrete operations
    final concretePatterns = [
      'http.', 'database.', 'file.', 'socket.',
      'new ', 'print(', 'system.', '.execute(',
      'connection.', 'transaction.', 'sql',
    ];

    // Abstract operations
    final abstractPatterns = [
      '.validate(', '.calculate(', '.apply(',
      '.enforce(', '.decide(', '.evaluate(',
      '.process(', '.handle(', '.manage(',
    ];

    for (final pattern in concretePatterns) {
      final matches = pattern.allMatches(bodyString).length;
      concreteOps += matches;
      totalOps += matches;
    }

    for (final pattern in abstractPatterns) {
      final matches = pattern.allMatches(bodyString).length;
      abstractOps += matches;
      totalOps += matches;
    }

    return MethodBodyAnalysis(
      concreteOperations: concreteOps,
      abstractOperations: abstractOps,
      totalOperations: totalOps,
    );
  }

  void _checkIntraClassAbstractionConsistency(
    ClassDeclaration node,
    DiagnosticReporter reporter,
    ArchitecturalLayer layer,
  ) {
    final methods = node.members.whereType<MethodDeclaration>();
    if (methods.length < 2) return;

    final methodAbstractions = methods
        .map((m) => _analyzeMethodAbstractionLevel(m))
        .toList();

    // Check for inconsistent abstraction levels within the class
    final scores = methodAbstractions.map((m) => m.score).toList();
    final minScore = scores.reduce((a, b) => a < b ? a : b);
    final maxScore = scores.reduce((a, b) => a > b ? a : b);
    final range = maxScore - minScore;

    if (range > 1.0) { // Threshold for inconsistency
      final code = LintCode(
        name: 'abstraction_progression',
        problemMessage:
            'Class has inconsistent method abstraction levels (range: ${range.toStringAsFixed(2)})',
        correctionMessage:
            'Ensure all methods in a class operate at similar abstraction levels.',
      );
      reporter.atNode(node, code);
    }
  }

  ArchitecturalLayer? _detectLayer(String filePath) {
    if (filePath.contains('/domain/') || filePath.contains('/entities/')) {
      return ArchitecturalLayer('domain', 4, 3.5, 4.0);
    }
    if (filePath.contains('/usecases/') || filePath.contains('/application/')) {
      return ArchitecturalLayer('application', 3, 2.5, 3.5);
    }
    if (filePath.contains('/adapters/') || filePath.contains('/controllers/')) {
      return ArchitecturalLayer('adapters', 2, 1.5, 2.5);
    }
    if (filePath.contains('/framework/') || filePath.contains('/infrastructure/')) {
      return ArchitecturalLayer('framework', 1, 0.0, 1.5);
    }
    return null;
  }

  AbstractionRange _getExpectedAbstractionRange(ArchitecturalLayer layer) {
    return AbstractionRange(layer.minAbstraction, layer.maxAbstraction);
  }

  bool _isAbstractionInRange(dynamic abstraction, AbstractionRange range) {
    final score = abstraction.score as double;
    return score >= range.min && score <= range.max;
  }

  // Classification methods
  bool _isConcreteImport(String importUri) {
    final concreteImports = [
      'package:sqflite/', 'package:http/', 'package:dio/',
      'dart:io', 'dart:html', 'package:flutter/'
    ];
    return concreteImports.any((import) => importUri.startsWith(import));
  }

  bool _isAbstractImport(String importUri) {
    return importUri.contains('/domain/') ||
           importUri.contains('/entities/') ||
           importUri.contains('/interfaces/');
  }

  bool _isConcreteDeclaration(AstNode declaration) {
    if (declaration is ClassDeclaration) {
      final className = declaration.name.lexeme;
      return _hasConcreteClassName(className);
    }
    return false;
  }

  bool _isAbstractDeclaration(AstNode declaration) {
    if (declaration is ClassDeclaration) {
      return declaration.abstractKeyword != null ||
             _hasAbstractClassName(declaration.name.lexeme);
    }
    return false;
  }

  bool _hasConcreteClassName(String className) {
    final concreteIndicators = [
      'Implementation', 'Concrete', 'Adapter', 'Client',
      'Database', 'Http', 'File', 'Driver', 'Manager'
    ];
    return concreteIndicators.any((indicator) => className.contains(indicator));
  }

  bool _hasAbstractClassName(String className) {
    final abstractIndicators = [
      'Interface', 'Abstract', 'Policy', 'Rule', 'Entity',
      'ValueObject', 'Service', 'Repository'
    ];
    return abstractIndicators.any((indicator) => className.contains(indicator));
  }

  bool _isConcreteMember(ClassMember member) {
    if (member is MethodDeclaration) {
      final methodName = member.name.lexeme;
      return _hasConcreteMethodName(methodName);
    }
    if (member is FieldDeclaration) {
      final type = member.fields.type;
      if (type is NamedType) {
        return _isConcreteType(type.name.lexeme);
      }
    }
    return false;
  }

  bool _isAbstractMember(ClassMember member) {
    if (member is MethodDeclaration) {
      return member.isAbstract || _hasAbstractMethodName(member.name.lexeme);
    }
    if (member is FieldDeclaration) {
      final type = member.fields.type;
      if (type is NamedType) {
        return _isAbstractType(type.name.lexeme);
      }
    }
    return false;
  }

  bool _hasConcreteMethodName(String methodName) {
    final concretePatterns = [
      'connect', 'read', 'write', 'save', 'load',
      'serialize', 'deserialize', 'parse', 'format',
      'http', 'sql', 'file', 'download', 'upload'
    ];
    return concretePatterns.any((pattern) =>
        methodName.toLowerCase().contains(pattern));
  }

  bool _hasAbstractMethodName(String methodName) {
    final abstractPatterns = [
      'validate', 'calculate', 'process', 'apply',
      'enforce', 'decide', 'evaluate', 'assess',
      'determine', 'authorize', 'approve'
    ];
    return abstractPatterns.any((pattern) =>
        methodName.toLowerCase().contains(pattern));
  }

  bool _isConcreteType(String typeName) {
    final concreteTypes = [
      'Database', 'HttpClient', 'File', 'Socket',
      'Connection', 'Driver', 'Adapter', 'Implementation'
    ];
    return concreteTypes.any((type) => typeName.contains(type));
  }

  bool _isAbstractType(String typeName) {
    final abstractTypes = [
      'Interface', 'Abstract', 'Repository', 'Service',
      'Policy', 'Rule', 'Entity', 'ValueObject'
    ];
    return abstractTypes.any((type) => typeName.contains(type));
  }

  // Advice methods
  String _getFileAbstractionAdvice(ArchitecturalLayer layer, FileAbstraction abstraction) {
    if (abstraction.score < layer.minAbstraction) {
      return 'File is too concrete for ${layer.name} layer. Move concrete details to outer layers.';
    } else {
      return 'File is too abstract for ${layer.name} layer. Add necessary implementation details.';
    }
  }

  String _getClassAbstractionAdvice(ArchitecturalLayer layer, ClassAbstraction abstraction, String className) {
    if (abstraction.score < layer.minAbstraction) {
      return 'Class $className is too concrete for ${layer.name} layer. Abstract the implementation details.';
    } else {
      return 'Class $className is too abstract for ${layer.name} layer. Provide concrete implementations.';
    }
  }

  String _getMethodAbstractionAdvice(ArchitecturalLayer layer, MethodAbstraction abstraction, String methodName) {
    if (abstraction.score < layer.minAbstraction) {
      return 'Method $methodName is too concrete for ${layer.name} layer. Focus on higher-level operations.';
    } else {
      return 'Method $methodName is too abstract for ${layer.name} layer. Provide implementation details.';
    }
  }
}

class ArchitecturalLayer {
  final String name;
  final int level;
  final double minAbstraction;
  final double maxAbstraction;

  ArchitecturalLayer(this.name, this.level, this.minAbstraction, this.maxAbstraction);
}

class AbstractionRange {
  final double min;
  final double max;

  AbstractionRange(this.min, this.max);
}

class FileAbstraction {
  final double score;
  final int concreteElements;
  final int abstractElements;
  final int totalElements;

  FileAbstraction({
    required this.score,
    required this.concreteElements,
    required this.abstractElements,
    required this.totalElements,
  });
}

class ClassAbstraction {
  final double score;
  final bool isAbstractClass;
  final int concreteMembers;
  final int abstractMembers;
  final int totalMembers;

  ClassAbstraction({
    required this.score,
    required this.isAbstractClass,
    required this.concreteMembers,
    required this.abstractMembers,
    required this.totalMembers,
  });
}

class MethodAbstraction {
  final double score;
  final bool isAbstract;
  final int concreteOperations;
  final int abstractOperations;
  final int totalOperations;

  MethodAbstraction({
    required this.score,
    required this.isAbstract,
    required this.concreteOperations,
    required this.abstractOperations,
    required this.totalOperations,
  });
}

class MethodBodyAnalysis {
  final int concreteOperations;
  final int abstractOperations;
  final int totalOperations;

  MethodBodyAnalysis({
    required this.concreteOperations,
    required this.abstractOperations,
    required this.totalOperations,
  });
}