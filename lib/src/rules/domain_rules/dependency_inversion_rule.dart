import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../../clean_architecture_linter_base.dart';

/// Enforces Dependency Inversion Principle in the domain layer.
class DependencyInversionRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'dependency_inversion',
    '{0}',
    correctionMessage: '{1}',
    severity: DiagnosticSeverity.WARNING,
    uniqueName: 'LintCode.dependency_inversion',
  );

  DependencyInversionRule()
    : super(
        name: 'dependency_inversion',
        description: 'Requires domain layer classes to depend on abstractions.',
      );

  @override
  bool get canUseParsedResult => true;

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final visitor = _DependencyInversionVisitor(this, context);
    registry.addConstructorDeclaration(this, visitor);
    registry.addFieldDeclaration(this, visitor);
    registry.addImportDirective(this, visitor);
    registry.addClassDeclaration(this, visitor);
  }
}

class _DependencyInversionVisitor extends SimpleAstVisitor<void> {
  _DependencyInversionVisitor(this.rule, this.context);

  final AnalysisRule rule;
  final RuleContext context;

  String get _filePath =>
      context.currentUnit?.file.path ?? context.definingUnit.file.path;

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    if (_shouldSkipFile) return;

    final analysis = _analyzeDependencyTypes(node.parameters.parameters);
    for (final violation in analysis.violations) {
      rule.reportAtNode(
        violation.node!,
        arguments: [violation.message, violation.suggestion],
      );
    }
  }

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    if (_shouldSkipFile) return;

    final type = node.fields.type;
    if (type is NamedType) {
      final violation = _analyzeFieldDependency(type);
      if (violation != null) {
        rule.reportAtNode(
          type,
          arguments: [violation.message, violation.suggestion],
        );
      }
    }
  }

  @override
  void visitImportDirective(ImportDirective node) {
    if (_shouldSkipFile) return;

    final importUri = node.uri.stringValue;
    if (importUri == null) return;

    final violation = _analyzeImportDependency(importUri);
    if (violation != null) {
      rule.reportAtNode(
        node,
        arguments: [violation.message, violation.suggestion],
      );
    }
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    if (_shouldSkipFile) return;

    final superclass = node.extendsClause?.superclass;
    if (superclass != null) {
      final violation = _analyzeInheritanceDependency(superclass, 'extends');
      if (violation != null) {
        rule.reportAtNode(
          superclass,
          arguments: [violation.message, violation.suggestion],
        );
      }
    }

    final interfaces = node.implementsClause?.interfaces;
    if (interfaces != null) {
      for (final interface in interfaces) {
        final violation = _analyzeInheritanceDependency(
          interface,
          'implements',
        );
        if (violation != null) {
          rule.reportAtNode(
            interface,
            arguments: [violation.message, violation.suggestion],
          );
        }
      }
    }

    final mixins = node.withClause?.mixinTypes;
    if (mixins != null) {
      for (final mixin in mixins) {
        final violation = _analyzeInheritanceDependency(mixin, 'mixes');
        if (violation != null) {
          rule.reportAtNode(
            mixin,
            arguments: [violation.message, violation.suggestion],
          );
        }
      }
    }
  }

  bool get _shouldSkipFile {
    final filePath = _filePath;
    return CleanArchitectureUtils.shouldExcludeFile(filePath) ||
        !CleanArchitectureUtils.isDomainFile(filePath);
  }

  DependencyAnalysis _analyzeDependencyTypes(List<FormalParameter> parameters) {
    final violations = <DependencyViolation>[];

    for (final param in parameters) {
      if (param is RegularFormalParameter) {
        final type = param.type;
        if (type is NamedType) {
          final violation = _checkParameterDependency(type, param);
          if (violation != null) {
            violations.add(violation);
          }
        }
      }
    }

    return DependencyAnalysis(violations: violations);
  }

  DependencyViolation? _checkParameterDependency(
    NamedType type,
    FormalParameter param,
  ) {
    final typeName = type.name.lexeme;

    if (_isConcreteImplementation(typeName)) {
      return DependencyViolation(
        node: param,
        message:
            'Constructor parameter depends on concrete implementation: $typeName',
        suggestion:
            'Use abstract interface or base class instead of concrete implementation.',
      );
    }

    if (_isInfrastructureDependency(typeName)) {
      return DependencyViolation(
        node: param,
        message: 'Domain layer directly depends on infrastructure: $typeName',
        suggestion:
            'Create domain interface and inject through dependency inversion.',
      );
    }

    if (_isFrameworkDependency(typeName)) {
      return DependencyViolation(
        node: param,
        message: 'Domain layer depends on external framework: $typeName',
        suggestion: 'Abstract framework dependency behind domain interface.',
      );
    }

    return null;
  }

  DependencyViolation? _analyzeFieldDependency(NamedType type) {
    final typeName = type.name.lexeme;

    if (_isConcreteImplementation(typeName)) {
      return DependencyViolation(
        node: type,
        message: 'Field depends on concrete implementation: $typeName',
        suggestion: 'Use abstract type for field declaration.',
      );
    }

    if (_isInfrastructureDependency(typeName)) {
      return DependencyViolation(
        node: type,
        message: 'Domain field directly references infrastructure: $typeName',
        suggestion: 'Create domain abstraction for infrastructure dependency.',
      );
    }

    return null;
  }

  DependencyViolation? _analyzeImportDependency(String importUri) {
    const infraPatterns = [
      'package:sqflite',
      'package:shared_preferences',
      'package:cloud_firestore',
      'package:firebase_',
      'package:http',
      'package:dio',
    ];

    for (final pattern in infraPatterns) {
      if (importUri.startsWith(pattern)) {
        return DependencyViolation(
          node: null,
          message: 'Direct infrastructure import in domain layer: $importUri',
          suggestion:
              'Create domain abstraction and move infrastructure to data layer.',
        );
      }
    }

    if ((importUri.contains('/data/') || importUri.contains('\\data\\')) &&
        !importUri.contains('/domain/') &&
        !importUri.contains('\\domain\\')) {
      return DependencyViolation(
        node: null,
        message: 'Domain layer importing from data layer: $importUri',
        suggestion:
            'Domain should not depend on data layer. Use dependency inversion.',
      );
    }

    if (importUri.contains('/presentation/') ||
        importUri.contains('\\presentation\\')) {
      return DependencyViolation(
        node: null,
        message: 'Domain layer importing from presentation layer: $importUri',
        suggestion: 'Domain should not depend on presentation layer.',
      );
    }

    return null;
  }

  DependencyViolation? _analyzeInheritanceDependency(
    NamedType type,
    String relationship,
  ) {
    final typeName = type.name.lexeme;

    if (_isConcreteImplementation(typeName)) {
      return DependencyViolation(
        node: type,
        message:
            'Domain class $relationship concrete implementation: $typeName',
        suggestion: 'Use abstract base class or interface for inheritance.',
      );
    }

    if (_isFrameworkDependency(typeName)) {
      return DependencyViolation(
        node: type,
        message: 'Domain class $relationship framework type: $typeName',
        suggestion:
            'Create domain abstraction instead of depending on framework.',
      );
    }

    return null;
  }

  bool _isConcreteImplementation(String typeName) {
    const concretePatterns = ['Impl', 'Implementation', 'Concrete'];
    const infrastructurePatterns = ['Client', 'Adapter', 'Gateway'];

    if (concretePatterns.any((pattern) => typeName.endsWith(pattern))) {
      return true;
    }

    return infrastructurePatterns.any((pattern) => typeName.endsWith(pattern));
  }

  bool _isInfrastructureDependency(String typeName) {
    const infraTypes = [
      'Database',
      'SqlDatabase',
      'NoSqlDatabase',
      'FileSystem',
      'Storage',
      'Cache',
      'SharedPreferences',
      'SecureStorage',
      'FirebaseFirestore',
      'FirebaseAuth',
      'NetworkClient',
      'ApiClient',
    ];
    return infraTypes.contains(typeName);
  }

  bool _isFrameworkDependency(String typeName) {
    const frameworkTypes = [
      'HttpClient',
      'Client',
      'RestClient',
      'Widget',
      'StatefulWidget',
      'StatelessWidget',
      'BuildContext',
      'Navigator',
      'StreamController',
      'AnimationController',
    ];
    return frameworkTypes.contains(typeName);
  }
}

class DependencyAnalysis {
  const DependencyAnalysis({required this.violations});

  final List<DependencyViolation> violations;
}

class DependencyViolation {
  const DependencyViolation({
    required this.node,
    required this.message,
    required this.suggestion,
  });

  final AstNode? node;
  final String message;
  final String suggestion;
}
