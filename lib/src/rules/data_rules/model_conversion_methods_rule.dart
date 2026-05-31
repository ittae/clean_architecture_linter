import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../../clean_architecture_linter_base.dart';

/// Enforces presence of toEntity() conversion method in Model extensions.
class ModelConversionMethodsRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'model_conversion_methods',
    '{0}',
    correctionMessage: '{1}',
    severity: DiagnosticSeverity.WARNING,
    uniqueName: 'LintCode.model_conversion_methods',
  );

  ModelConversionMethodsRule()
    : super(
        name: 'model_conversion_methods',
        description:
            'Requires data models with Entity fields to expose toEntity() in a same-file extension.',
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
    registry.addClassDeclaration(
      this,
      _ModelConversionMethodsVisitor(this, context),
    );
  }
}

class _ModelConversionMethodsVisitor extends SimpleAstVisitor<void> {
  _ModelConversionMethodsVisitor(this.rule, this.context);

  final AnalysisRule rule;
  final RuleContext context;

  String get _filePath =>
      context.currentUnit?.file.path ?? context.definingUnit.file.path;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final filePath = _filePath;
    if (CleanArchitectureUtils.shouldExcludeFile(filePath)) return;

    if (!_isDataModelFile(filePath)) return;

    final className = node.namePart.typeName.lexeme;
    if (!className.endsWith('Model')) return;

    if (!_hasFreezedAnnotation(node)) return;
    if (!_hasEntityField(node)) return;

    final compilationUnit = node.thisOrAncestorOfType<CompilationUnit>();
    if (compilationUnit == null) return;

    if (!_hasToEntityMethod(compilationUnit, className)) {
      rule.reportAtNode(
        node,
        arguments: [
          'Data model "$className" should have toEntity() method in extension',
          'Add extension with toEntity() method (e.g., extension ${className}X on $className { Entity toEntity() => entity; }).',
        ],
      );
    }
  }

  bool _isDataModelFile(String filePath) {
    final normalized = filePath.replaceAll('\\', '/').toLowerCase();
    return normalized.contains('/data/') && normalized.contains('/models/');
  }

  bool _hasFreezedAnnotation(ClassDeclaration node) {
    return node.metadata.any((annotation) {
      final name = annotation.name.toSource();
      return name == 'freezed' || name == 'Freezed';
    });
  }

  bool _hasEntityField(ClassDeclaration node) {
    for (final member in node.body.members) {
      if (member is! ConstructorDeclaration || member.factoryKeyword == null) {
        continue;
      }

      for (final param in member.parameters.parameters) {
        final fieldInfo = _extractFieldInfo(param);
        if (fieldInfo == null) continue;

        if (fieldInfo.name == 'entity' || fieldInfo.name.endsWith('Entity')) {
          return true;
        }
      }
    }
    return false;
  }

  _FieldInfo? _extractFieldInfo(FormalParameter param) {
    if (param is! RegularFormalParameter) return null;
    final normalParam = param;

    final name = normalParam.name?.lexeme;
    final type = normalParam.type?.toSource();
    if (name == null || type == null) return null;

    return _FieldInfo(name: name, type: type);
  }

  bool _hasToEntityMethod(CompilationUnit compilationUnit, String className) {
    for (final declaration in compilationUnit.declarations) {
      if (declaration is! ExtensionDeclaration) continue;

      final extendedType = declaration.onClause?.extendedType;
      if (extendedType is! NamedType) continue;

      final typeName = extendedType.name.lexeme;
      if (typeName != className) continue;

      if (_hasMethod(declaration, 'toEntity', isStatic: false)) {
        return true;
      }
    }
    return false;
  }

  bool _hasMethod(
    ExtensionDeclaration extension,
    String methodName, {
    required bool isStatic,
  }) {
    for (final member in extension.body.members) {
      if (member is MethodDeclaration &&
          member.name.lexeme == methodName &&
          member.isStatic == isStatic) {
        return true;
      }
    }
    return false;
  }
}

class _FieldInfo {
  const _FieldInfo({required this.name, required this.type});

  final String name;
  final String type;
}
