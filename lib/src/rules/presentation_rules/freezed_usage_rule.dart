import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../clean_architecture_linter_base.dart';

/// Enforces Freezed usage for data classes instead of Equatable.
///
/// Following CLEAN_ARCHITECTURE_GUIDE.md:
/// - Use Freezed for all data classes (Models, Entities, States)
/// - NO Equatable usage
/// - Freezed provides: immutability, copyWith, equality, JSON serialization
///
/// ✅ Correct Pattern:
/// ```dart
/// @freezed
/// class Ranking with _$Ranking {
///   const factory Ranking({
///     required String id,
///     required int attendeeCount,
///   }) = _Ranking;
/// }
/// ```
///
/// ❌ Wrong Pattern:
/// ```dart
/// class Ranking extends Equatable {  // ❌
///   final String id;
///   final int attendeeCount;
///
///   @override
///   List<Object?> get props => [id, attendeeCount];
/// }
/// ```
class FreezedUsageRule extends CleanArchitectureLintRule {
  const FreezedUsageRule() : super(code: _code);

  static const _code = LintCode(
    name: 'freezed_usage',
    problemMessage: 'Use Freezed instead of Equatable for data classes',
    correctionMessage:
        'Replace Equatable with @freezed annotation. Freezed provides immutability, copyWith, and equality automatically.',
  );

  @override
  void runRule(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((node) {
      _checkEquatableUsage(node, reporter, resolver);
    });

    context.registry.addImportDirective((node) {
      _checkEquatableImport(node, reporter, resolver);
    });
  }

  void _checkEquatableUsage(
    ClassDeclaration node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    final normalized = filePath.replaceAll('\\', '/').toLowerCase();

    // Only check in domain, data, presentation layers
    if (!_isArchitectureLayer(normalized)) return;

    // Check if class extends Equatable
    final extendsClause = node.extendsClause;
    if (extendsClause != null) {
      final superclass = extendsClause.superclass.toString();
      if (superclass.contains('Equatable')) {
        final code = LintCode(
          name: 'freezed_usage',
          problemMessage:
              'Class "${node.name.lexeme}" uses Equatable. Use @freezed instead.',
          correctionMessage:
              'Replace "extends Equatable" with @freezed annotation. Remove props getter and use Freezed factory constructor.',
        );
        reporter.atNode(extendsClause, code);
      }
    }

    // Check if class implements Equatable
    final implementsClause = node.implementsClause;
    if (implementsClause != null) {
      for (final interface in implementsClause.interfaces) {
        if (interface.toString().contains('Equatable')) {
          final code = LintCode(
            name: 'freezed_usage',
            problemMessage:
                'Class "${node.name.lexeme}" implements Equatable. Use @freezed instead.',
            correctionMessage:
                'Use @freezed annotation for immutable data classes.',
          );
          reporter.atNode(implementsClause, code);
        }
      }
    }
  }

  void _checkEquatableImport(
    ImportDirective node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    final normalized = filePath.replaceAll('\\', '/').toLowerCase();

    // Only check in architecture layers
    if (!_isArchitectureLayer(normalized)) return;

    final importUri = node.uri.stringValue;
    if (importUri != null && importUri.contains('equatable')) {
      final code = LintCode(
        name: 'freezed_usage',
        problemMessage: 'Equatable import detected. Use Freezed instead.',
        correctionMessage:
            'Remove equatable import and add freezed_annotation. Use @freezed for data classes.',
      );
      reporter.atNode(node, code);
    }
  }

  bool _isArchitectureLayer(String filePath) {
    return filePath.contains('/domain/') ||
        filePath.contains('/data/') ||
        filePath.contains('/presentation/');
  }
}
