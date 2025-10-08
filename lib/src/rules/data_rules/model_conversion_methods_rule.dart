import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../clean_architecture_linter_base.dart';

/// Enforces presence of conversion methods in Model extensions
///
/// This rule ensures that data models have proper conversion methods:
/// - toEntity(): Convert Model to Entity (instance method)
/// - fromEntity(): Create Model from Entity (static method)
/// - Extensions must be in the same file as the Model
///
/// ✅ Correct Pattern:
/// ```dart
/// @freezed
/// sealed class TodoModel with _$TodoModel {
///   const factory TodoModel({
///     required Todo entity,
///     String? etag,
///   }) = _TodoModel;
/// }
///
/// extension TodoModelX on TodoModel {
///   /// Convert Model to Entity
///   Todo toEntity() => entity;
///
///   /// Create Model from Entity
///   static TodoModel fromEntity(Todo entity, {String? etag}) {
///     return TodoModel(entity: entity, etag: etag);
///   }
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
/// // ❌ Missing extension with conversion methods
/// ```
class ModelConversionMethodsRule extends CleanArchitectureLintRule {
  const ModelConversionMethodsRule() : super(code: _code);

  static const _code = LintCode(
    name: 'model_conversion_methods',
    problemMessage: 'Data model should have conversion methods in extension (toEntity, fromEntity)',
    correctionMessage: 'Add extension with conversion methods in same file:\n'
        '  extension ModelNameX on ModelName {\n'
        '    Entity toEntity() => entity;\n'
        '    static ModelName fromEntity(Entity entity) => ModelName(entity: entity);\n'
        '  }',
  );

  @override
  void runRule(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((node) {
      _checkConversionMethods(node, reporter, resolver);
    });
  }

  void _checkConversionMethods(
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

    // Check for Entity field
    if (!_hasEntityField(node)) return;

    // Check for conversion extension in same file
    final compilationUnit = node.thisOrAncestorOfType<CompilationUnit>();
    if (compilationUnit == null) return;

    final hasExtension = _hasConversionExtension(
      compilationUnit,
      className,
    );

    if (!hasExtension) {
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
            if (fieldInfo.name == 'entity' || fieldInfo.name.endsWith('Entity')) {
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

  bool _hasConversionExtension(
    CompilationUnit compilationUnit,
    String className,
  ) {
    for (final declaration in compilationUnit.declarations) {
      if (declaration is ExtensionDeclaration) {
        // Check if extension is on this Model class
        final extendedType = declaration.onClause?.extendedType;
        if (extendedType != null && extendedType is NamedType) {
          final typeName = extendedType.name2.lexeme;
          if (typeName == className) {
            // Check for required conversion methods
            final hasToEntity = _hasMethod(declaration, 'toEntity', isStatic: false);
            final hasFromEntity = _hasMethod(declaration, 'fromEntity', isStatic: true);

            return hasToEntity && hasFromEntity;
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
