import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../clean_architecture_linter_base.dart';

/// Enforces extensions in the same file as the class they extend.
///
/// Following CLEAN_ARCHITECTURE_GUIDE.md:
/// - Extensions should be in the same file as the class
/// - NO separate extensions/ directories
/// - Domain: Business logic extensions in entity file
/// - Data: Conversion extensions in model file
/// - Presentation: Entity UI extensions ONLY in state files (NOT in widget files)
///
/// ✅ Correct Pattern:
/// ```dart
/// // domain/entities/ranking.dart
/// @freezed
/// class Ranking { }
///
/// extension RankingX on Ranking {  // Same file
///   bool get isHighAttendance => attendeeCount > 5;
/// }
///
/// // presentation/states/ranking_state.dart
/// @freezed
/// class RankingState {
///   const factory RankingState({
///     @Default([]) List<Ranking> rankings,
///   }) = _RankingState;
/// }
///
/// extension RankingUIX on Ranking {  // ✅ OK: State file only
///   Color get statusColor => Colors.green;
/// }
/// ```
///
/// ❌ Wrong Pattern:
/// ```dart
/// // domain/extensions/ranking_extensions.dart  ❌
/// // presentation/extensions/  ❌
/// // presentation/ui/  ❌
/// // presentation/widgets/ranking_card.dart
/// extension RankingUIX on Ranking { }  // ❌ NO: Widget file
/// ```
class ExtensionLocationRule extends CleanArchitectureLintRule {
  const ExtensionLocationRule() : super(code: _code);

  static const _code = LintCode(
    name: 'extension_location',
    problemMessage: 'Extensions should be in the same file as the class',
    correctionMessage:
        'Move extensions to the class file. Domain entity extensions → entity file, Model extensions → model file, UI extensions → state file or widget file.',
  );

  @override
  void runRule(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCompilationUnit((node) {
      _checkExtensionDirectory(node, reporter, resolver);
    });

    context.registry.addExtensionDeclaration((node) {
      _checkPresentationExtensionLocation(node, reporter, resolver);
    });
  }

  void _checkExtensionDirectory(
    CompilationUnit node,
    DiagnosticReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    final normalized = filePath.replaceAll('\\', '/').toLowerCase();

    // Check for forbidden extension directories
    final forbiddenPaths = [
      '/domain/extensions/',
      '/data/extensions/',
      '/presentation/extensions/',
      '/presentation/ui/',
    ];

    for (final forbidden in forbiddenPaths) {
      if (normalized.contains(forbidden)) {
        final layerName = _getLayerName(forbidden);
        final code = LintCode(
          name: 'extension_location',
          problemMessage: 'Extension directory is not allowed: $forbidden',
          correctionMessage:
              'Move extensions to the $layerName file. Extensions should be in the same file as the class they extend.',
        );
        reporter.atOffset(offset: 0, length: 1, diagnosticCode: code);
        break;
      }
    }
  }

  String _getLayerName(String forbiddenPath) {
    if (forbiddenPath.contains('domain')) {
      return 'entity file (e.g., ranking.dart with extension RankingX)';
    } else if (forbiddenPath.contains('data')) {
      return 'model file (e.g., ranking_model.dart with extension RankingModelX)';
    } else if (forbiddenPath.contains('presentation')) {
      return 'state file or widget file (e.g., ranking_state.dart with UI extensions)';
    }
    return 'appropriate file';
  }

  void _checkPresentationExtensionLocation(
    ExtensionDeclaration node,
    DiagnosticReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    final normalized = filePath.replaceAll('\\', '/').toLowerCase();

    // Only check presentation layer
    if (!normalized.contains('/presentation/')) return;

    // Skip if in states/ directory (allowed)
    if (normalized.contains('/states/') || normalized.endsWith('_state.dart')) {
      return;
    }

    // Check if extension is on a Domain Entity
    final extendedType = node.onClause?.extendedType;
    if (extendedType == null) return;

    // Check if this looks like a Domain Entity extension
    // (Entity extensions in presentation should ONLY be in state files)
    if (normalized.contains('/widgets/') ||
        normalized.contains('/pages/') ||
        normalized.contains('/screens/') ||
        normalized.endsWith('_widget.dart') ||
        normalized.endsWith('_page.dart') ||
        normalized.endsWith('_screen.dart')) {
      final code = LintCode(
        name: 'extension_location',
        problemMessage:
            'Entity UI extensions are not allowed in widget/page/screen files',
        correctionMessage:
            'Move entity UI extensions to the State file (e.g., todo_state.dart). '
            'Only State files should contain entity UI extensions. '
            'Widget files should use the State and its extensions, not define their own.',
      );
      reporter.atNode(node, code);
    }
  }
}
