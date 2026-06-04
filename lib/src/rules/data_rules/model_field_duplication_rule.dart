import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../../compat/analyzer_ast_compat.dart';
import '../../clean_architecture_linter_base.dart';

/// Enforces no field duplication in Model when Entity field exists.
class ModelFieldDuplicationRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'model_field_duplication',
    '{0}',
    correctionMessage: '{1}',
    severity: DiagnosticSeverity.WARNING,
    uniqueName: 'LintCode.model_field_duplication',
  );

  ModelFieldDuplicationRule()
    : super(
        name: 'model_field_duplication',
        description:
            'Prevents data models from duplicating fields already owned by their Entity.',
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
      _ModelFieldDuplicationVisitor(this, context),
    );
  }
}

class _ModelFieldDuplicationVisitor extends SimpleAstVisitor<void> {
  _ModelFieldDuplicationVisitor(this.rule, this.context);

  final AnalysisRule rule;
  final RuleContext context;

  static const _allowedMetadataFields = {
    'id',
    'etag',
    'version',
    'cachedAt',
    'lastModified',
    'createdAt',
    'updatedAt',
    'syncStatus',
    'isLocal',
    'isCached',
  };

  String get _filePath =>
      context.currentUnit?.file.path ?? context.definingUnit.file.path;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final filePath = _filePath;
    if (CleanArchitectureUtils.shouldExcludeFile(filePath)) return;

    if (!_isDataModelFile(filePath)) return;

    final className = classDeclarationName(node) ?? '';
    if (!className.endsWith('Model')) return;

    if (!_hasFreezedAnnotation(node)) return;

    final fields = _extractFields(node);
    final entityField = _findEntityField(fields);
    if (entityField == null) return;

    final duplicateFields = _findDuplicateFields(fields, entityField);
    for (final duplicate in duplicateFields) {
      rule.reportAtNode(
        duplicate.node,
        arguments: [
          'Field "${duplicate.name}" duplicates Entity field. Model should only contain Entity + metadata.',
          'Remove "${duplicate.name}" field. Access it via entity.${duplicate.name} instead.',
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

  List<_FieldInfo> _extractFields(ClassDeclaration node) {
    final fields = <_FieldInfo>[];

    for (final member in classMembers(node)) {
      if (member is! ConstructorDeclaration || member.factoryKeyword == null) {
        continue;
      }

      for (final param in member.parameters.parameters) {
        final fieldInfo = _extractFieldInfo(param);
        if (fieldInfo != null) {
          fields.add(fieldInfo);
        }
      }
    }

    return fields;
  }

  _FieldInfo? _extractFieldInfo(FormalParameter param) {
    final name = formalParameterName(param);
    final type = formalParameterType(param)?.toSource();
    if (name == null || type == null) return null;

    return _FieldInfo(name: name, type: type, node: param);
  }

  _FieldInfo? _findEntityField(List<_FieldInfo> fields) {
    for (final field in fields) {
      if (_isEntityField(field)) return field;
    }
    return null;
  }

  bool _isEntityField(_FieldInfo field) {
    if (field.name == 'entity' || field.name.endsWith('Entity')) return true;
    return _isEntityType(field.type);
  }

  bool _isEntityType(String typeName) {
    if (typeName.isEmpty) return false;

    final cleanTypeName = typeName.replaceAll('?', '');
    if (cleanTypeName.endsWith('Model') ||
        cleanTypeName.endsWith('Dto') ||
        cleanTypeName.endsWith('Response') ||
        cleanTypeName.endsWith('Request')) {
      return false;
    }

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
    if (primitiveTypes.any(cleanTypeName.startsWith)) {
      return false;
    }

    return true;
  }

  List<_FieldInfo> _findDuplicateFields(
    List<_FieldInfo> fields,
    _FieldInfo entityField,
  ) {
    final duplicates = <_FieldInfo>[];

    for (final field in fields) {
      if (field.name == entityField.name) continue;
      if (_allowedMetadataFields.contains(field.name)) continue;
      if (_isPotentialDomainField(field)) duplicates.add(field);
    }

    return duplicates;
  }

  bool _isPotentialDomainField(_FieldInfo field) {
    const domainFieldPatterns = {
      'name',
      'title',
      'description',
      'content',
      'status',
      'type',
      'value',
      'amount',
      'price',
      'quantity',
      'isCompleted',
      'isActive',
      'isEnabled',
      'dueDate',
      'startDate',
      'endDate',
      'userId',
      'productId',
      'orderId',
    };

    return domainFieldPatterns.contains(field.name);
  }
}

class _FieldInfo {
  const _FieldInfo({
    required this.name,
    required this.type,
    required this.node,
  });

  final String name;
  final String type;
  final AstNode node;
}
