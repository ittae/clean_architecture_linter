import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:analyzer/error/error.dart' show ErrorSeverity;

import '../../clean_architecture_linter_base.dart';
import '../../mixins/repository_rule_visitor.dart';
import '../../mixins/return_type_validation_mixin.dart';

/// Validates Repository implementation uses pass-through pattern.
///
/// In Clean Architecture with pass-through error handling, Repository
/// implementations should NOT use Result pattern. Instead, they return
/// `Future<Entity>` directly and let exceptions propagate to AsyncValue.guard()
/// in the Presentation layer.
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
class RepositoryPassThroughRule extends CleanArchitectureLintRule
    with RepositoryRuleVisitor, ReturnTypeValidationMixin {
  const RepositoryPassThroughRule() : super(code: _code);

  static const _code = LintCode(
    name: 'repository_pass_through',
    problemMessage:
        'Repository must return Future<Entity> (pass-through pattern).',
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
    final isFuture =
        returnTypeString.startsWith('Future<') ||
        returnTypeString.startsWith('FutureOr<');

    if (!isFuture) {
      // Non-Future, non-void, non-Stream returns are suspicious
      // But we only warn if it looks like an Entity type
      if (_looksLikeEntityType(returnTypeString)) {
        final code = LintCode(
          name: 'repository_pass_through',
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
        name: 'repository_pass_through',
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
    // Skip primitive types and their collections
    if (_isPrimitiveOrCollection(typeName)) return false;

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

  /// Checks if a type is primitive or a collection of primitives.
  ///
  /// Allows synchronous returns for local storage patterns (e.g., SharedPreferences):
  /// - Primitives: String, int, bool, double, num
  /// - Collections: List<String>, Set<int>, Map<String, String>, etc.
  bool _isPrimitiveOrCollection(String typeName) {
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

    // Direct primitive
    if (primitives.contains(typeName)) return true;

    // Nullable primitive (e.g., String?, int?)
    if (typeName.endsWith('?')) {
      final baseType = typeName.substring(0, typeName.length - 1);
      if (primitives.contains(baseType)) return true;
    }

    // Collection of primitives (e.g., List<String>, Set<int>, Map<String, String>)
    if (typeName.startsWith('List<') ||
        typeName.startsWith('Set<') ||
        typeName.startsWith('Iterable<')) {
      final inner = _extractGenericType(typeName);
      return inner != null && _isPrimitiveOrCollection(inner);
    }

    // Map with primitive keys and values
    if (typeName.startsWith('Map<')) {
      final types = _extractMapTypes(typeName);
      if (types != null) {
        return _isPrimitiveOrCollection(types.$1) &&
            _isPrimitiveOrCollection(types.$2);
      }
    }

    return false;
  }

  /// Extracts generic type from List<T>, Set<T>, etc.
  String? _extractGenericType(String typeName) {
    final start = typeName.indexOf('<');
    final end = typeName.lastIndexOf('>');
    if (start != -1 && end != -1 && end > start) {
      return typeName.substring(start + 1, end).trim();
    }
    return null;
  }

  /// Extracts key and value types from Map<K, V>.
  (String, String)? _extractMapTypes(String typeName) {
    final inner = _extractGenericType(typeName);
    if (inner == null) return null;

    // Simple split by comma (doesn't handle nested generics)
    final commaIndex = inner.indexOf(',');
    if (commaIndex == -1) return null;

    final keyType = inner.substring(0, commaIndex).trim();
    final valueType = inner.substring(commaIndex + 1).trim();
    return (keyType, valueType);
  }
}
