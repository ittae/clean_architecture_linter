import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../clean_architecture_linter_base.dart';

/// Enforces presence of toEntity() conversion method in Model extensions
///
/// This rule ensures that data models have the toEntity() method to convert Model → Entity.
/// The toEntity() method must be in an extension in the same file.
///
/// For creating Models from Entities (fromEntity), use factory constructors directly in the class.
///
/// ✅ Correct Pattern:
/// ```dart
/// @freezed
/// sealed class TodoModel with _$TodoModel {
///   const factory TodoModel({
///     required Todo entity,
///     String? etag,
///   }) = _TodoModel;
///
///   // Optional: Named factory for creating from Entity
///   factory TodoModel.fromEntity(Todo entity, {String? etag}) {
///     return TodoModel(entity: entity, etag: etag);
///   }
/// }
///
/// extension TodoModelX on TodoModel {
///   Todo toEntity() => entity;  // Required
/// }
/// ```
///
/// ❌ Wrong Pattern:
/// ```dart
/// @freezed
/// sealed class TodoModel with _$TodoModel {
///   const factory TodoModel({
///     required Todo entity,
///     String? etag,
///   }) = _TodoModel;
/// }
/// // ❌ Missing toEntity() extension method
/// ```
class ModelConversionMethodsRule extends CleanArchitectureLintRule {
  const ModelConversionMethodsRule() : super(code: _code);

  static const _code = LintCode(
    name: 'model_conversion_methods',
    problemMessage: 'Data model should have toEntity() method in extension',
    correctionMessage:
        'Add extension with toEntity() method (e.g., extension ModelX on Model { Entity toEntity() => entity; }).',
  );

  @override
  void runRule(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((node) {
      _checkConversionMethods(node, reporter, resolver);
    });
  }

  void _checkConversionMethods(
    ClassDeclaration node,
    DiagnosticReporter reporter,
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

    // Check for Entity field
    if (!_hasEntityField(node)) return;

    // Check for toEntity() method in extension
    final compilationUnit = node.thisOrAncestorOfType<CompilationUnit>();
    if (compilationUnit == null) return;

    final hasToEntity = _hasToEntityMethod(compilationUnit, className);

    if (!hasToEntity) {
      reporter.atNode(node, _code);
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
          final fieldInfo = _extractFieldInfo(param);
          if (fieldInfo != null) {
            if (fieldInfo.name == 'entity' ||
                fieldInfo.name.endsWith('Entity')) {
              return true;
            }
          }
        }
      }
    }
    return false;
  }

  _FieldInfo? _extractFieldInfo(FormalParameter param) {
    String? name;
    String? type;

    if (param is SimpleFormalParameter) {
      name = param.name?.toString();
      type = param.type?.toString();
    } else if (param is DefaultFormalParameter) {
      final normalParam = param.parameter;
      if (normalParam is SimpleFormalParameter) {
        name = normalParam.name?.toString();
        type = normalParam.type?.toString();
      }
    }

    if (name == null || type == null) return null;
    return _FieldInfo(name: name, type: type);
  }

  /// Checks if toEntity() method exists in any extension on this Model
  bool _hasToEntityMethod(CompilationUnit compilationUnit, String className) {
    for (final declaration in compilationUnit.declarations) {
      if (declaration is ExtensionDeclaration) {
        // Check if extension is on this Model class
        final extendedType = declaration.onClause?.extendedType;
        if (extendedType != null && extendedType is NamedType) {
          final typeName = extendedType.name.lexeme;
          if (typeName == className) {
            // Check for toEntity() instance method
            if (_hasMethod(declaration, 'toEntity', isStatic: false)) {
              return true;
            }
          }
        }
      }
    }
    return false;
  }

  bool _hasMethod(
    ExtensionDeclaration extension,
    String methodName, {
    required bool isStatic,
  }) {
    for (final member in extension.members) {
      if (member is MethodDeclaration) {
        if (member.name.lexeme == methodName && member.isStatic == isStatic) {
          return true;
        }
      }
    }
    return false;
  }
}

class _FieldInfo {
  final String name;
  final String type;

  _FieldInfo({required this.name, required this.type});
}
