import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../clean_architecture_linter_base.dart';

/// Enforces using toEntity() method instead of direct .entity property access in Data layer.
///
/// This rule ensures that Model → Entity conversions happen through explicit
/// conversion methods rather than direct property access, maintaining clear
/// architectural boundaries and allowing for future conversion logic changes.
///
/// **Applies to:** Data layer only (`data/` directories)
///
/// ✅ Correct Pattern:
/// ```dart
/// // In Repository or DataSource
/// class TodoRepositoryImpl implements TodoRepository {
///   Future<Result<List<Todo>, Failure>> getTodos() async {
///     final models = await dataSource.getTodos();
///     return Success(models.map((m) => m.toEntity()).toList()); // ✅ Use toEntity()
///   }
/// }
/// ```
///
/// ❌ Wrong Pattern:
/// ```dart
/// class TodoRepositoryImpl implements TodoRepository {
///   Future<Result<List<Todo>, Failure>> getTodos() async {
///     final models = await dataSource.getTodos();
///     return Success(models.map((m) => m.entity).toList()); // ❌ Direct access
///   }
/// }
/// ```
///
/// **Exceptions:**
/// - ✅ Inside extension methods (where conversion logic is implemented)
/// - ✅ Test files (for verification purposes)
class ModelEntityDirectAccessRule extends CleanArchitectureLintRule {
  const ModelEntityDirectAccessRule() : super(code: _code);

  static const _code = LintCode(
    name: 'model_entity_direct_access',
    problemMessage:
        'Direct access to model.entity is not allowed in Data layer. '
        'Use the toEntity() extension method instead.',
    correctionMessage:
        'Replace ".entity" with ".toEntity()" to maintain clear conversion boundaries. '
        'Example: model.toEntity() instead of model.entity',
  );

  @override
  void runRule(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    final filePath = resolver.path;

    // Only check files in data layer
    if (!CleanArchitectureUtils.isDataFile(filePath)) return;

    context.registry.addPropertyAccess((node) {
      _checkPropertyAccess(node, reporter, resolver);
    });
  }

  void _checkPropertyAccess(
    PropertyAccess node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    // Check if accessing 'entity' property
    if (node.propertyName.name != 'entity') return;

    // Exception 1: Allow inside extension methods
    if (_isInsideExtensionMethod(node)) return;

    // Exception 2: Allow in test files (already excluded by base class, but double-check)
    if (_isTestFile(resolver.path)) return;

    // Report violation
    reporter.atNode(node, _code);
  }

  /// Checks if the property access is inside an extension method.
  ///
  /// Extensions define conversion logic, so direct .entity access is allowed there.
  bool _isInsideExtensionMethod(PropertyAccess node) {
    var current = node.parent;

    while (current != null) {
      // Check if we're inside an extension declaration
      if (current is ExtensionDeclaration) {
        return true;
      }

      // Stop at class declaration (not in extension if we hit a class first)
      if (current is ClassDeclaration) {
        return false;
      }

      current = current.parent;
    }

    return false;
  }

  /// Checks if a file is a test file.
  ///
  /// This is a redundant check since CleanArchitectureLintRule already
  /// excludes test files, but kept for explicit clarity.
  bool _isTestFile(String filePath) {
    return filePath.contains('/test/') ||
        filePath.contains('\\test\\') ||
        filePath.endsWith('_test.dart');
  }
}
