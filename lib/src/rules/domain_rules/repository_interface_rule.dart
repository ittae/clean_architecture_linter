import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../../clean_architecture_linter_base.dart';
import '../../mixins/repository_rule_visitor.dart';

/// Enforces proper repository abstraction patterns in domain layer.
class RepositoryInterfaceRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'repository_interface',
    '{0}',
    correctionMessage: '{1}',
    severity: DiagnosticSeverity.WARNING,
    uniqueName: 'LintCode.repository_interface',
  );

  RepositoryInterfaceRule()
    : super(
        name: 'repository_interface',
        description:
            'Requires domain layer repository abstractions and entity-only signatures.',
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
    final visitor = _RepositoryInterfaceVisitor(this, context);
    registry.addImportDirective(this, visitor);
    registry.addClassDeclaration(this, visitor);
    registry.addConstructorDeclaration(this, visitor);
    registry.addFieldDeclaration(this, visitor);
  }
}

class _RepositoryInterfaceVisitor extends SimpleAstVisitor<void>
    with RepositoryRuleVisitor {
  _RepositoryInterfaceVisitor(this.rule, this.context);

  final AnalysisRule rule;
  final RuleContext context;

  String get _filePath =>
      context.currentUnit?.file.path ?? context.definingUnit.file.path;

  @override
  void visitImportDirective(ImportDirective node) {
    if (_shouldSkipFile) return;

    final importUri = node.uri.stringValue;
    if (importUri == null) return;

    final violation = _analyzeRepositoryImport(importUri);
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

    final className = node.namePart.typeName.lexeme;
    if (!className.contains('Repository')) return;

    if (!isRepositoryInterface(node)) {
      rule.reportAtNode(
        node,
        arguments: [
          'Repository in domain layer should be abstract: $className',
          'Make repository abstract or move implementation to data layer.',
        ],
      );
    }

    for (final member in node.body.members) {
      if (member is MethodDeclaration) {
        _checkRepositoryMethod(member);
      }
    }
  }

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    if (_shouldSkipFile) return;

    for (final param in node.parameters.parameters) {
      if (param is RegularFormalParameter) {
        final type = param.type;
        if (type is NamedType) {
          final typeName = type.name.lexeme;
          if (CleanArchitectureUtils.isRepositoryImplClass(typeName)) {
            rule.reportAtNode(
              type,
              arguments: [
                'Constructor depends on concrete repository implementation: $typeName',
                'Use abstract repository interface instead of concrete implementation.',
              ],
            );
          }
        }
      }
    }
  }

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    if (_shouldSkipFile) return;

    final type = node.fields.type;
    if (type is NamedType) {
      final typeName = type.name.lexeme;
      if (CleanArchitectureUtils.isRepositoryImplClass(typeName)) {
        rule.reportAtNode(
          type,
          arguments: [
            'Field depends on concrete repository implementation: $typeName',
            'Use abstract repository interface instead of concrete implementation.',
          ],
        );
      }
    }
  }

  bool get _shouldSkipFile {
    final filePath = _filePath;
    return CleanArchitectureUtils.shouldExcludeFile(filePath) ||
        !CleanArchitectureUtils.isDomainFile(filePath);
  }

  void _checkRepositoryMethod(MethodDeclaration method) {
    _checkReturnTypeForModels(method.returnType);
    _checkMethodParametersForModels(method);
  }

  void _checkReturnTypeForModels(TypeAnnotation? returnType) {
    if (returnType == null) return;

    if (returnType is NamedType) {
      final returnTypeName = returnType.name.lexeme;

      if (_isDataLayerModel(returnTypeName)) {
        rule.reportAtNode(
          returnType,
          arguments: [
            'Repository method returns data layer model: $returnTypeName',
            'Repository methods should return domain entities, not data models.',
          ],
        );
        return;
      }

      final typeArguments = returnType.typeArguments?.arguments;
      if (typeArguments != null) {
        for (final typeArg in typeArguments) {
          if (typeArg is NamedType) {
            final typeArgName = typeArg.name.lexeme;
            if (_isDataLayerModel(typeArgName)) {
              rule.reportAtNode(
                typeArg,
                arguments: [
                  'Repository method uses data layer model in generic type: $typeArgName',
                  'Use domain entities in generic types. Example: Future<User> or AsyncValue<User> patterns should never expose UserModel.',
                ],
              );
            }
          }
        }
      }
    }
  }

  void _checkMethodParametersForModels(MethodDeclaration method) {
    final parameters = method.parameters;
    if (parameters == null) return;

    for (final param in parameters.parameters) {
      TypeAnnotation? paramType;

      if (param is RegularFormalParameter) {
        paramType = param.type;
      }

      if (paramType is NamedType) {
        final paramTypeName = paramType.name.lexeme;
        if (_isDataLayerModel(paramTypeName)) {
          rule.reportAtNode(
            paramType,
            arguments: [
              'Repository method parameter uses data layer model: $paramTypeName',
              'Repository method parameters should use domain entities, not data models.',
            ],
          );
        }

        final typeArguments = paramType.typeArguments?.arguments;
        if (typeArguments != null) {
          for (final typeArg in typeArguments) {
            if (typeArg is NamedType) {
              final typeArgName = typeArg.name.lexeme;
              if (_isDataLayerModel(typeArgName)) {
                rule.reportAtNode(
                  typeArg,
                  arguments: [
                    'Repository parameter uses data layer model in generic type: $typeArgName',
                    'Use domain entities in generic types. Example: List<User> instead of List<UserModel>',
                  ],
                );
              }
            }
          }
        }
      }
    }
  }

  RepositoryViolation? _analyzeRepositoryImport(String importUri) {
    if ((importUri.contains('/data/') || importUri.contains('\\data\\')) &&
        (importUri.contains('repository') ||
            importUri.contains('Repository'))) {
      if (importUri.contains('impl') || importUri.contains('Impl')) {
        return const RepositoryViolation(
          message:
              'Importing concrete repository implementation from data layer',
          suggestion:
              'Import only abstract repository interfaces. Move concrete implementations to data layer.',
        );
      }
    }

    const infraPatterns = [
      'package:sqflite',
      'package:hive',
      'package:shared_preferences',
      'package:cloud_firestore',
    ];

    for (final pattern in infraPatterns) {
      if (importUri.startsWith(pattern)) {
        return const RepositoryViolation(
          message:
              'Direct infrastructure dependency detected in domain repository',
          suggestion:
              'Use repository abstractions instead of direct infrastructure dependencies.',
        );
      }
    }

    return null;
  }

  bool _isDataLayerModel(String typeName) {
    return typeName.endsWith('Model') ||
        typeName.endsWith('Dto') ||
        typeName.endsWith('Response') ||
        typeName.endsWith('Entity') && typeName.contains('Data');
  }
}

class RepositoryViolation {
  const RepositoryViolation({required this.message, required this.suggestion});

  final String message;
  final String suggestion;
}
