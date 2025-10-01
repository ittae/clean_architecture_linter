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
/// - Presentation: UI extensions in state file or widget file
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
/// ```
///
/// ❌ Wrong Pattern:
/// ```dart
/// // domain/extensions/ranking_extensions.dart  ❌
/// // presentation/extensions/  ❌
/// // presentation/ui/  ❌
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
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCompilationUnit((node) {
      _checkExtensionDirectory(node, reporter, resolver);
    });
  }

  void _checkExtensionDirectory(
    CompilationUnit node,
    ErrorReporter reporter,
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
        reporter.atOffset(
          offset: 0,
          length: 1,
          errorCode: code,
        );
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
}
