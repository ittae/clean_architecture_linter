import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../clean_architecture_linter_base.dart';

/// Enforces no field duplication in Model when Entity field exists
///
/// This rule ensures that data models:
/// - Do NOT duplicate Entity fields
/// - Only add metadata fields (etag, version, cachedAt, etc.)
/// - Follow composition pattern: Model contains Entity, not Entity's fields
///
/// ✅ Correct Pattern:
/// ```dart
/// @freezed
/// sealed class TodoModel {
///   const factory TodoModel({
///     required Todo entity,  // ✅ Composition
///     String? etag,  // ✅ Metadata only
///   }) = _TodoModel;
/// }
/// ```
///
/// ❌ Wrong Pattern:
/// ```dart
/// @freezed
/// sealed class TodoModel {
///   const factory TodoModel({
///     required Todo entity,  // Has entity
///     required String title,  // ❌ Duplicate from entity.title
///     required bool isCompleted,  // ❌ Duplicate from entity.isCompleted
///     String? etag,
///   }) = _TodoModel;
/// }
/// ```
class ModelFieldDuplicationRule extends CleanArchitectureLintRule {
  const ModelFieldDuplicationRule() : super(code: _code);

  static const _code = LintCode(
    name: 'model_field_duplication',
    problemMessage: 'Data model should NOT duplicate Entity fields. Use composition pattern.',
    correctionMessage:
        'Remove duplicate fields. Model should only contain Entity field + metadata (etag, version, cachedAt).',
  );

  /// Allowed metadata field names that can exist alongside Entity
  static const _allowedMetadataFields = {
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

  @override
  void runRule(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((node) {
      _checkFieldDuplication(node, reporter, resolver);
    });
  }

  void _checkFieldDuplication(
    ClassDeclaration node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;

    // Only check files in data/models directory
    if (!_isDataModelFile(filePath)) return;

    final className = node.name.lexeme;

    // Check if class name ends with Model
    if (!className.endsWith('Model')) return;

    // Check for Freezed annotation
    if (!_hasFreezedAnnotation(node)) return;

    // Find Entity field and other fields
    final fields = _extractFields(node);
    final entityField = _findEntityField(fields);

    // If no entity field, ModelStructureRule will catch this
    if (entityField == null) return;

    // Check for duplicate fields
    final duplicateFields = _findDuplicateFields(fields, entityField);

    for (final duplicate in duplicateFields) {
      final code = LintCode(
        name: 'model_field_duplication',
        problemMessage:
            'Field "${duplicate.name}" duplicates Entity field. Model should only contain Entity + metadata.',
        correctionMessage: 'Remove "${duplicate.name}" field. Access it via entity.${duplicate.name} instead.',
      );

      // Report at the field location
      reporter.atOffset(
        offset: duplicate.offset,
        length: duplicate.name.length,
        errorCode: code,
      );
    }
  }

  bool _isDataModelFile(String filePath) {
    final normalized = filePath.replaceAll('\\', '/').toLowerCase();
    return normalized.contains('/data/') && normalized.contains('/models/');
  }

  bool _hasFreezedAnnotation(ClassDeclaration node) {
    final metadata = node.metadata;
    return metadata.any((annotation) {
      final name = annotation.name.toString();
      return name == 'freezed' || name == 'Freezed';
    });
  }

  List<_FieldInfo> _extractFields(ClassDeclaration node) {
    final fields = <_FieldInfo>[];

    for (final member in node.members) {
      if (member is ConstructorDeclaration && member.factoryKeyword != null) {
        final params = member.parameters.parameters;
        for (final param in params) {
          final fieldInfo = _extractFieldInfo(param);
          if (fieldInfo != null) {
            fields.add(fieldInfo);
          }
        }
      }
    }

    return fields;
  }

  _FieldInfo? _extractFieldInfo(FormalParameter param) {
    String? name;
    String? type;
    int offset = 0;

    if (param is SimpleFormalParameter) {
      name = param.name?.toString();
      type = param.type?.toString();
      offset = param.offset;
    } else if (param is DefaultFormalParameter) {
      final normalParam = param.parameter;
      if (normalParam is SimpleFormalParameter) {
        name = normalParam.name?.toString();
        type = normalParam.type?.toString();
        offset = normalParam.offset;
      }
    }

    if (name == null || type == null) return null;

    return _FieldInfo(
      name: name,
      type: type,
      offset: offset,
    );
  }

  _FieldInfo? _findEntityField(List<_FieldInfo> fields) {
    for (final field in fields) {
      if (_isEntityField(field)) {
        return field;
      }
    }
    return null;
  }

  bool _isEntityField(_FieldInfo field) {
    // Check by field name
    if (field.name == 'entity' || field.name.endsWith('Entity')) {
      return true;
    }

    // Check by type name (Entity types)
    return _isEntityType(field.type);
  }

  bool _isEntityType(String typeName) {
    if (typeName.isEmpty) return false;

    // Remove nullable marker
    final cleanTypeName = typeName.replaceAll('?', '');

    // Exclude data layer types
    if (cleanTypeName.endsWith('Model') ||
        cleanTypeName.endsWith('Dto') ||
        cleanTypeName.endsWith('Response') ||
        cleanTypeName.endsWith('Request')) {
      return false;
    }

    // Exclude primitive types
    final primitiveTypes = ['String', 'int', 'double', 'bool', 'DateTime', 'List', 'Map', 'Set'];
    if (primitiveTypes.any((type) => cleanTypeName.startsWith(type))) {
      return false;
    }

    // Explicitly named entities or custom domain types
    return true;
  }

  List<_FieldInfo> _findDuplicateFields(
    List<_FieldInfo> fields,
    _FieldInfo entityField,
  ) {
    final duplicates = <_FieldInfo>[];

    for (final field in fields) {
      // Skip the entity field itself
      if (field.name == entityField.name) continue;

      // Skip allowed metadata fields
      if (_allowedMetadataFields.contains(field.name)) continue;

      // Any other field is a potential duplicate
      // In a real implementation, we would need to:
      // 1. Resolve the Entity type
      // 2. Get its fields
      // 3. Check if Model field name matches Entity field name
      //
      // For now, we detect common domain field patterns
      if (_isPotentialDomainField(field)) {
        duplicates.add(field);
      }
    }

    return duplicates;
  }

  bool _isPotentialDomainField(_FieldInfo field) {
    // Common domain field patterns (not metadata)
    final domainFieldPatterns = [
      'id',
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
    ];

    return domainFieldPatterns.contains(field.name);
  }
}

class _FieldInfo {
  final String name;
  final String type;
  final int offset;

  _FieldInfo({
    required this.name,
    required this.type,
    required this.offset,
  });
}
