import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../clean_architecture_linter_base.dart';

/// Enforces that domain entities do not contain JSON serialization methods.
///
/// JSON serialization is a data layer concern and should not be in domain entities.
/// Domain entities should remain pure and only contain business logic.
///
/// **Violation:**
/// ```dart
/// // domain/entities/user.dart
/// @freezed
/// class User with _$User {
///   factory User({required String id}) = _User;
///   factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);  // ❌
/// }
/// ```
///
/// **Correct:**
/// ```dart
/// // domain/entities/user.dart
/// @freezed
/// class User with _$User {
///   const factory User({required String id}) = _User;  // ✅ Pure entity
/// }
///
/// // data/models/user_model.dart
/// @freezed
/// class UserModel with _$UserModel {
///   const factory UserModel({required String id, String? etag}) = _UserModel;
///   factory UserModel.fromJson(Map<String, dynamic> json) => _$UserModelFromJson(json);  // ✅
/// }
/// ```
class EntityNoJsonSerializationRule extends CleanArchitectureLintRule {
  const EntityNoJsonSerializationRule() : super(code: _code);

  static const _code = LintCode(
    name: 'entity_no_json_serialization',
    problemMessage:
        'Domain entity should not contain JSON serialization methods (fromJson/toJson).',
    correctionMessage:
        'Move JSON serialization to Data layer Model. Entity should be pure business logic only.',
  );

  @override
  void runRule(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    final filePath = resolver.path;

    // Only check domain layer files
    if (!CleanArchitectureUtils.isDomainFile(filePath)) return;

    // Skip files that are explicitly models (shouldn't be in domain, but just in case)
    if (filePath.contains('/models/')) return;

    context.registry.addClassDeclaration((node) {
      _checkClassForJsonMethods(node, reporter);
    });
  }

  void _checkClassForJsonMethods(
    ClassDeclaration node,
    ErrorReporter reporter,
  ) {
    final className = node.name.lexeme;

    // Skip if class name suggests it's a Model (defensive check)
    if (className.endsWith('Model') || className.endsWith('Dto')) return;

    // Check for factory constructors with JSON serialization
    for (final member in node.members) {
      if (member is ConstructorDeclaration) {
        _checkConstructor(member, reporter, className);
      } else if (member is MethodDeclaration) {
        _checkMethod(member, reporter, className);
      }
    }
  }

  void _checkConstructor(
    ConstructorDeclaration constructor,
    ErrorReporter reporter,
    String className,
  ) {
    final constructorName = constructor.name?.lexeme;

    // Check for fromJson factory constructor
    if (constructorName == 'fromJson') {
      final code = LintCode(
        name: 'entity_no_json_serialization',
        problemMessage:
            'Entity "$className" has fromJson constructor. JSON serialization belongs in Data layer.',
        correctionMessage:
            'Create ${className}Model in data/models/ with fromJson. Entity should be pure.',
      );
      reporter.atNode(constructor, code);
    }

    // Check for fromMap factory constructor (similar serialization pattern)
    if (constructorName == 'fromMap') {
      final code = LintCode(
        name: 'entity_no_json_serialization',
        problemMessage:
            'Entity "$className" has fromMap constructor. Map serialization belongs in Data layer.',
        correctionMessage:
            'Create ${className}Model in data/models/ with fromMap. Entity should be pure.',
      );
      reporter.atNode(constructor, code);
    }
  }

  void _checkMethod(
    MethodDeclaration method,
    ErrorReporter reporter,
    String className,
  ) {
    final methodName = method.name.lexeme;

    // Check for toJson method
    if (methodName == 'toJson') {
      final code = LintCode(
        name: 'entity_no_json_serialization',
        problemMessage:
            'Entity "$className" has toJson method. JSON serialization belongs in Data layer.',
        correctionMessage:
            'Create ${className}Model in data/models/ with toJson. Entity should be pure.',
      );
      reporter.atNode(method, code);
    }

    // Check for toMap method (similar serialization pattern)
    if (methodName == 'toMap') {
      final code = LintCode(
        name: 'entity_no_json_serialization',
        problemMessage:
            'Entity "$className" has toMap method. Map serialization belongs in Data layer.',
        correctionMessage:
            'Create ${className}Model in data/models/ with toMap. Entity should be pure.',
      );
      reporter.atNode(method, code);
    }
  }
}
