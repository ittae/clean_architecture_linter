import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../../clean_architecture_linter_base.dart';

/// Enforces proper Freezed Model structure following CLEAN_ARCHITECTURE_GUIDE.md.
class ModelStructureRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'model_structure',
    '{0}',
    correctionMessage: '{1}',
    severity: DiagnosticSeverity.WARNING,
    uniqueName: 'LintCode.model_structure',
  );

  ModelStructureRule()
    : super(
        name: 'model_structure',
        description:
            'Requires data models to use Freezed, be sealed, and contain a domain Entity.',
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
    registry.addClassDeclaration(this, _ModelStructureVisitor(this, context));
  }
}

class _ModelStructureVisitor extends SimpleAstVisitor<void> {
  _ModelStructureVisitor(this.rule, this.context);

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

    if (_hasDatabaseAnnotation(node)) return;

    if (!_hasFreezedAnnotation(node)) {
      rule.reportAtNode(
        node,
        arguments: [
          'Data model "$className" should use @freezed annotation',
          'Add @freezed annotation above the class declaration.',
        ],
      );
      return;
    }

    if (!_isSealedClass(node)) {
      rule.reportAtNode(
        node,
        arguments: [
          'Data model "$className" should be a sealed class',
          'Add "sealed" modifier before "class" keyword (e.g., "sealed class $className").',
        ],
      );
    }

    if (!_hasEntityField(node)) {
      rule.reportAtNode(
        node,
        arguments: [
          'Data model "$className" should contain Entity field',
          'Add "required EntityName entity" field to contain the Domain Entity.',
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

  bool _hasDatabaseAnnotation(ClassDeclaration node) {
    return node.metadata.any((annotation) {
      final name = annotation.name.toSource();
      return name == 'Entity' ||
          name == 'entity' ||
          name == 'RealmModel' ||
          name == 'MapTo' ||
          name == 'collection' ||
          name == 'Collection' ||
          name == 'UseRowClass' ||
          name == 'DataClassName';
    });
  }

  bool _isSealedClass(ClassDeclaration node) {
    return node.sealedKeyword != null;
  }

  bool _hasEntityField(ClassDeclaration node) {
    for (final member in node.body.members) {
      if (member is! ConstructorDeclaration || member.factoryKeyword == null) {
        continue;
      }

      for (final param in member.parameters.parameters) {
        if (param is! RegularFormalParameter) continue;
        final normalParam = param;

        final paramName = normalParam.name?.lexeme ?? '';
        final typeName = normalParam.type?.toSource() ?? '';
        if (paramName == 'entity' ||
            paramName.endsWith('Entity') ||
            _isEntityType(typeName)) {
          return true;
        }
      }
    }
    return false;
  }

  bool _isEntityType(String typeName) {
    if (typeName.isEmpty) return false;

    if (typeName.endsWith('Model') ||
        typeName.endsWith('Dto') ||
        typeName.endsWith('Response') ||
        typeName.endsWith('Request')) {
      return false;
    }

    if (typeName.endsWith('Entity')) return true;

    const primitiveTypes = {
      'String',
      'int',
      'double',
      'bool',
      'DateTime',
      'List',
      'Map',
      'Set',
    };
    if (primitiveTypes.any(typeName.startsWith)) {
      return false;
    }

    return true;
  }
}
