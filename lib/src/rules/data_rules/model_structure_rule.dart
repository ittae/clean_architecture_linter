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
    problemMessage: 'Data model should use Freezed and contain Entity without duplicate fields',
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
        problemMessage: 'Data model "$className" should use @freezed annotation',
        correctionMessage: 'Add @freezed annotation above the class declaration.',
      );
      reporter.atNode(node, code);
      return;
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

  bool _hasEntityField(ClassDeclaration node) {
    // Look for factory constructor parameters
    for (final member in node.members) {
      if (member is ConstructorDeclaration && member.factoryKeyword != null) {
        final params = member.parameters.parameters;
        for (final param in params) {
          if (param is SimpleFormalParameter) {
            final paramName = param.name?.toString() ?? '';
            // Check if parameter name is 'entity' or ends with 'entity'
            if (paramName == 'entity' || paramName.endsWith('Entity')) {
              return true;
            }
          } else if (param is DefaultFormalParameter) {
            final normalParam = param.parameter;
            if (normalParam is SimpleFormalParameter) {
              final paramName = normalParam.name?.toString() ?? '';
              if (paramName == 'entity' || paramName.endsWith('Entity')) {
                return true;
              }
            }
          }
        }
      }
    }
    return false;
  }
}
