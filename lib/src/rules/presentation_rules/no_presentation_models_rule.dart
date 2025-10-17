import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../clean_architecture_linter_base.dart';

/// Enforces NO Presentation Models or ViewModels pattern.
///
/// Following CLEAN_ARCHITECTURE_GUIDE.md:
/// - Use Freezed State with Riverpod (not ViewModels)
/// - State contains Domain Entities directly
/// - NO separate presentation/models/ directory
/// - NO presentation/viewmodels/ directory
/// - NO ChangeNotifier pattern
///
/// ✅ Correct Pattern:
/// ```dart
/// // presentation/states/ranking_state.dart
/// @freezed
/// class RankingState {
///   const factory RankingState({
///     required List<Ranking> rankings,  // Uses Entity directly
///     required bool isLoading,
///   }) = _RankingState;
/// }
/// ```
///
/// ❌ Wrong Pattern:
/// ```dart
/// // presentation/models/ranking_ui_model.dart  ❌
/// // presentation/viewmodels/ranking_viewmodel.dart  ❌
/// class RankingViewModel extends ChangeNotifier { }  ❌
/// ```
class NoPresentationModelsRule extends CleanArchitectureLintRule {
  const NoPresentationModelsRule() : super(code: _code);

  static const _code = LintCode(
    name: 'no_presentation_models',
    problemMessage: 'Presentation Models and ViewModels are not allowed',
    correctionMessage:
        'Use Freezed State with Riverpod instead. State should contain Domain Entities directly.',
  );

  @override
  void runRule(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCompilationUnit((node) {
      _checkPresentationModelDirectory(node, reporter, resolver);
    });

    context.registry.addClassDeclaration((node) {
      _checkViewModelClass(node, reporter, resolver);
      _checkChangeNotifier(node, reporter, resolver);
    });
  }

  void _checkPresentationModelDirectory(
    CompilationUnit node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    final normalized = filePath.replaceAll('\\', '/').toLowerCase();

    // Check for forbidden directories
    if (normalized.contains('/presentation/models/')) {
      final code = LintCode(
        name: 'no_presentation_models',
        problemMessage: 'Presentation models directory is not allowed',
        correctionMessage:
            'Remove presentation/models/ directory. Use states/ directory with Freezed State containing Entities.',
      );
      reporter.atOffset(
        offset: 0,
        length: 1,
        errorCode: code,
      );
    }

    if (normalized.contains('/presentation/viewmodels/')) {
      final code = LintCode(
        name: 'no_presentation_models',
        problemMessage: 'ViewModels directory is not allowed',
        correctionMessage:
            'Remove presentation/viewmodels/ directory. Use Freezed State with Riverpod instead.',
      );
      reporter.atOffset(
        offset: 0,
        length: 1,
        errorCode: code,
      );
    }
  }

  void _checkViewModelClass(
    ClassDeclaration node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final className = node.name.lexeme;

    if (className.endsWith('ViewModel')) {
      final code = LintCode(
        name: 'no_presentation_models',
        problemMessage: 'ViewModel pattern is not allowed: $className',
        correctionMessage:
            'Use Freezed State with riverpod_generator (@riverpod annotation) instead.',
      );
      reporter.atNode(node, code);
    }
  }

  void _checkChangeNotifier(
    ClassDeclaration node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final extendsClause = node.extendsClause;
    if (extendsClause == null) return;

    final superclass = extendsClause.superclass.toString();

    if (superclass.contains('ChangeNotifier')) {
      final code = LintCode(
        name: 'no_presentation_models',
        problemMessage: 'ChangeNotifier pattern is not allowed',
        correctionMessage:
            'Use Freezed State with Riverpod instead. Define state with @freezed and notifier with @riverpod.',
      );
      reporter.atNode(extendsClause, code);
    }
  }
}
