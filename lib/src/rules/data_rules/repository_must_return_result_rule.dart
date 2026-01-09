import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:analyzer/error/error.dart' show ErrorSeverity;

import '../../clean_architecture_linter_base.dart';
import '../../mixins/repository_rule_visitor.dart';
import '../../mixins/return_type_validation_mixin.dart';

/// Validates Repository implementation return types.
///
/// In Clean Architecture, Repository implementations should use the pass-through
/// pattern, returning `Future<Entity>` directly. Error handling is done by
/// AsyncValue.guard() in the Presentation layer.
///
/// ```dart
/// // ✅ CORRECT - Pass-through pattern
/// class TodoRepositoryImpl implements TodoRepository {
///   @override
///   Future<Todo> getTodo(String id) async {
///     final model = await remoteDataSource.getTodo(id);
///     return model.toEntity();  // Errors pass through to AsyncValue
///   }
/// }
/// ```
///
/// ## What This Rule Checks
///
/// - ❌ Repository returning `Result<Entity, Failure>` - Use pass-through instead
/// - ❌ Repository returning Model types (should return Entity)
/// - ❌ Repository returning raw types without Future
/// - ✅ `Future<Entity>` - Allowed (pass-through pattern)
///
/// See UNIFIED_ERROR_GUIDE.md for complete error handling patterns.
class RepositoryMustReturnResultRule extends CleanArchitectureLintRule
    with RepositoryRuleVisitor, ReturnTypeValidationMixin {
  const RepositoryMustReturnResultRule() : super(code: _code);

  static const _code = LintCode(
    name: 'repository_must_return_result',
    problemMessage: 'Repository must return Future<Entity> (pass-through pattern).',
    correctionMessage:
        'Return Future<Entity> directly. Errors pass through to AsyncValue.guard(). '
        'See UNIFIED_ERROR_GUIDE.md.',
    errorSeverity: ErrorSeverity.WARNING,
  );

  @override
  void runRule(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((node) {
      _checkRepositoryMethod(node, reporter, resolver);
    });
  }

  void _checkRepositoryMethod(
    MethodDeclaration method,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    // Check if this method is in a Repository implementation class
    final classNode = method.thisOrAncestorOfType<ClassDeclaration>();
    if (classNode == null) return;

    if (!isRepositoryImplementation(classNode)) return;

    // Skip private methods and void methods
    if (shouldSkipMethod(method)) return;

    final returnType = method.returnType;
    if (returnType == null) return;

    final returnTypeString = returnType.toString();

    // Allow void returns
    if (returnTypeString == 'void') return;

    // Allow Stream returns
    if (returnTypeString.startsWith('Stream<')) return;

    // Check if return type is Future-wrapped
    final isFuture = returnTypeString.startsWith('Future<') ||
        returnTypeString.startsWith('FutureOr<');

    if (!isFuture) {
      // Non-Future, non-void, non-Stream returns are suspicious
      // But we only warn if it looks like an Entity type
      if (_looksLikeEntityType(returnTypeString)) {
        final code = LintCode(
          name: 'repository_must_return_result',
          problemMessage:
              'Repository method "${method.name.lexeme}" should return Future<$returnTypeString>.',
          correctionMessage: 'Wrap in Future: Future<$returnTypeString>',
          errorSeverity: ErrorSeverity.WARNING,
        );
        reporter.atNode(returnType, code);
      }
      return;
    }

    // Check for Result pattern usage - warn to use pass-through instead
    if (isResultReturnType(returnType)) {
      final code = LintCode(
        name: 'repository_must_return_result',
        problemMessage:
            'Repository should NOT use Result pattern. Use pass-through pattern instead.',
        correctionMessage:
            'Return Future<Entity> directly. '
            'Let errors pass through to AsyncValue.guard() in Presentation layer.',
        errorSeverity: ErrorSeverity.WARNING,
      );
      reporter.atNode(returnType, code);
    }
  }

  /// Checks if a type name looks like an Entity type.
  bool _looksLikeEntityType(String typeName) {
    // Skip primitive types
    if (_isPrimitiveType(typeName)) return false;

    // Skip common utility types
    if (typeName == 'void' ||
        typeName == 'dynamic' ||
        typeName == 'Object' ||
        typeName == 'Never') {
      return false;
    }

    // Looks like an Entity if it's a capitalized name
    return typeName.isNotEmpty && typeName[0] == typeName[0].toUpperCase();
  }

  bool _isPrimitiveType(String typeName) {
    const primitives = {
      'int',
      'double',
      'num',
      'String',
      'bool',
      'void',
      'dynamic',
      'Object',
      'Null',
    };
    return primitives.contains(typeName);
  }
}
