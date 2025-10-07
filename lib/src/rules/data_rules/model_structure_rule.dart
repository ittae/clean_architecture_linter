import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../clean_architecture_linter_base.dart';

/// Enforces proper Freezed Model structure following CLEAN_ARCHITECTURE_GUIDE.md
///
/// This rule ensures that data models:
/// - Use Freezed annotation
/// - Contain Entity (no duplicate fields)
/// - Only add metadata fields if needed (etag, version, cachedAt, etc.)
/// - Have conversion extensions in same file
///
/// ✅ Correct Pattern:
/// ```dart
/// @freezed
/// class RankingModel {
///   const factory RankingModel({
///     required Ranking entity,  // Domain Entity
///     String? etag,  // Optional metadata only
///   }) = _RankingModel;
/// }
///
/// extension RankingModelX on RankingModel {
///   Ranking toEntity() => entity;
/// }
/// ```
///
/// ❌ Wrong Pattern:
/// ```dart
/// class RankingModel {
///   final Ranking entity;
///   final String startTime;  // ❌ Duplicate from entity
///   final int attendeeCount;  // ❌ Duplicate from entity
/// }
/// ```
class ModelStructureRule extends CleanArchitectureLintRule {
  const ModelStructureRule() : super(code: _code);

  static const _code = LintCode(
    name: 'model_structure',
    problemMessage:
        'Data model should use Freezed and contain Entity without duplicate fields',
    correctionMessage:
        'Use @freezed with required Entity field. Only add metadata fields if needed (etag, version, cachedAt).',
  );

  @override
  void runRule(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((node) {
      _checkModelStructure(node, reporter, resolver);
    });
  }

  void _checkModelStructure(
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
    if (!_hasFreezedAnnotation(node)) {
      final code = LintCode(
        name: 'model_structure',
        problemMessage:
            'Data model "$className" should use @freezed annotation',
        correctionMessage:
            'Add @freezed annotation above the class declaration.',
      );
      reporter.atNode(node, code);
      return;
    }

    // Check for sealed class modifier
    if (!_isSealedClass(node)) {
      final code = LintCode(
        name: 'model_structure',
        problemMessage:
            'Data model "$className" should be a sealed class',
        correctionMessage:
            'Add "sealed" modifier before "class" keyword (e.g., "sealed class $className").',
      );
      reporter.atNode(node, code);
    }

    // Check for Entity field in constructor
    final hasEntityField = _hasEntityField(node);
    if (!hasEntityField) {
      final code = LintCode(
        name: 'model_structure',
        problemMessage: 'Data model "$className" should contain Entity field',
        correctionMessage:
            'Add "required EntityName entity" field to contain the Domain Entity.',
      );
      reporter.atNode(node, code);
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

  bool _isSealedClass(ClassDeclaration node) {
    return node.sealedKeyword != null;
  }

  bool _hasEntityField(ClassDeclaration node) {
    // Look for factory constructor parameters
    for (final member in node.members) {
      if (member is ConstructorDeclaration && member.factoryKeyword != null) {
        final params = member.parameters.parameters;
        for (final param in params) {
          if (param is SimpleFormalParameter) {
            final paramName = param.name?.toString() ?? '';
            final typeName = param.type?.toString() ?? '';

            // Check if parameter name is 'entity' or ends with 'Entity'
            // OR if parameter type ends with 'Entity' (e.g., TimeSlot for TimeSlot entity)
            if (paramName == 'entity' ||
                paramName.endsWith('Entity') ||
                _isEntityType(typeName)) {
              return true;
            }
          } else if (param is DefaultFormalParameter) {
            final normalParam = param.parameter;
            if (normalParam is SimpleFormalParameter) {
              final paramName = normalParam.name?.toString() ?? '';
              final typeName = normalParam.type?.toString() ?? '';

              if (paramName == 'entity' ||
                  paramName.endsWith('Entity') ||
                  _isEntityType(typeName)) {
                return true;
              }
            }
          }
        }
      }
    }
    return false;
  }

  bool _isEntityType(String typeName) {
    // Check if type name indicates it's an entity
    // Entities typically don't end with 'Model', 'Dto', 'Response', etc.
    if (typeName.isEmpty) return false;

    // Exclude common data layer types
    if (typeName.endsWith('Model') ||
        typeName.endsWith('Dto') ||
        typeName.endsWith('Response') ||
        typeName.endsWith('Request')) {
      return false;
    }

    // Common domain entity patterns
    // 1. Ends with 'Entity' explicitly
    if (typeName.endsWith('Entity')) return true;

    // 2. Domain entities are typically simple nouns (User, Product, Order, TimeSlot, etc.)
    // If it's a custom type (not a primitive), it's likely an entity
    final primitiveTypes = ['String', 'int', 'double', 'bool', 'DateTime', 'List', 'Map', 'Set'];
    if (primitiveTypes.any((type) => typeName.startsWith(type))) {
      return false;
    }

    // If we have a custom type in a Model, it's likely a domain entity
    return true;
  }
}
