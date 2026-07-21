import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../../clean_architecture_linter_base.dart';
import '../../compat/analyzer_ast_compat.dart';

/// Detects usage of `ref.mounted` in the UI layer.
///
/// The rule is layer-aware rather than path-based:
///
/// * **State layer (Notifier / provider classes)** — `if (!ref.mounted) return;`
///   after an async gap is the documented Riverpod 3 way to avoid
///   `UnmountedRefException`, so it is NOT reported.
/// * **UI layer (widgets / pages)** — gating state logic on `ref.mounted`
///   masks a design problem and IS reported.
class RefMountedUsageRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'ref_mounted_usage',
    'Avoid using "ref.mounted" to guard async operations in the UI layer. This masks design problems.',
    correctionMessage:
        'Instead: (1) Complete async work before navigation, or (2) Call UseCase directly then navigate - new screen\'s provider will load state. Inside a Notifier, "if (!ref.mounted) return;" is the recommended disposal guard and is not reported.',
    severity: DiagnosticSeverity.INFO,
    uniqueName: 'LintCode.ref_mounted_usage',
  );

  RefMountedUsageRule()
    : super(
        name: 'ref_mounted_usage',
        description:
            'Disallows ref.mounted lifecycle masking in the UI layer, while allowing it as a disposal guard inside Notifier classes.',
      );

  @override
  bool get canUseParsedResult => true;

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final visitor = _RefMountedUsageVisitor(this, context);
    registry.addPrefixedIdentifier(this, visitor);
    registry.addPrefixExpression(this, visitor);
  }
}

class _RefMountedUsageVisitor extends SimpleAstVisitor<void> {
  _RefMountedUsageVisitor(this.rule, this.context);

  final AnalysisRule rule;
  final RuleContext context;

  String get _filePath =>
      context.currentUnit?.file.path ?? context.definingUnit.file.path;

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (!_shouldCheckFile) return;

    final parent = node.parent;
    if (parent is PrefixExpression &&
        parent.operator.lexeme == '!' &&
        parent.operand == node &&
        node.prefix.name == 'ref' &&
        node.identifier.name == 'mounted') {
      return;
    }

    if (node.prefix.name == 'ref' && node.identifier.name == 'mounted') {
      if (_isExemptContext(node)) return;
      rule.reportAtNode(node);
    }
  }

  @override
  void visitPrefixExpression(PrefixExpression node) {
    if (!_shouldCheckFile) return;

    if (node.operator.lexeme == '!' && node.operand is PrefixedIdentifier) {
      final operand = node.operand as PrefixedIdentifier;
      if (operand.prefix.name == 'ref' &&
          operand.identifier.name == 'mounted') {
        if (_isExemptContext(node)) return;
        rule.reportAtNode(node);
      }
    }
  }

  bool get _shouldCheckFile {
    if (CleanArchitectureUtils.shouldExcludeFile(_filePath)) return false;

    final normalized = _filePath.replaceAll('\\', '/').toLowerCase();
    return normalized.contains('/presentation/') ||
        normalized.contains('/providers/');
  }

  /// Whether [node] sits in a class where `ref.mounted` is the recommended
  /// disposal guard rather than a design smell.
  ///
  /// Judged from the enclosing class in the AST, not from the file path: a
  /// Notifier and the widget that consumes it routinely live under the same
  /// `presentation/providers/` directory.
  bool _isExemptContext(AstNode node) {
    final enclosingClass = node.thisOrAncestorOfType<ClassDeclaration>();
    if (enclosingClass == null) return false;

    return isRiverpodNotifierClass(enclosingClass);
  }
}

/// Whether [node] declares a Riverpod state-layer class (a Notifier).
///
/// Recognises the three shapes that appear in Riverpod 2/3 codebases:
/// the `@riverpod` / `@Riverpod(...)` annotation, the generated `_$Name`
/// superclass, and the hand-written `Notifier` family base classes.
bool isRiverpodNotifierClass(ClassDeclaration node) {
  for (final metadata in node.metadata) {
    final name = metadata.name.name;
    if (name == 'riverpod' || name == 'Riverpod') return true;
  }

  final superclassName = node.extendsClause?.superclass.name.lexeme;
  if (superclassName != null) {
    if (superclassName.startsWith('_\$')) return true;
    // Notifier, AsyncNotifier, StreamNotifier, AutoDisposeNotifier,
    // FamilyAsyncNotifier, and project-local base notifiers all end in
    // "Notifier".
    if (superclassName.endsWith('Notifier')) return true;
  }

  return classDeclarationName(node)?.endsWith('Notifier') ?? false;
}
