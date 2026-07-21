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

  /// Whether [node] sits in a state-layer declaration, where `ref.mounted` is
  /// the recommended disposal guard rather than a design smell.
  ///
  /// Judged from the enclosing declaration in the AST, not from the file path:
  /// a Notifier and the widget that consumes it routinely live under the same
  /// `presentation/providers/` directory.
  bool _isExemptContext(AstNode node) {
    final enclosingClass = node.thisOrAncestorOfType<ClassDeclaration>();
    if (enclosingClass != null) {
      return _isRiverpodNotifierClass(enclosingClass);
    }

    // Notifier methods are routinely split into an `extension X on FooNotifier`
    // in a part file. Those members are still state layer.
    final enclosingExtension = node
        .thisOrAncestorOfType<ExtensionDeclaration>();
    if (enclosingExtension != null) {
      return _isRiverpodNotifierExtension(enclosingExtension);
    }

    // Functional `@riverpod` providers are state layer too — codegen turns them
    // into providers with the same disposal semantics as a Notifier.
    final enclosingFunction = node.thisOrAncestorOfType<FunctionDeclaration>();
    if (enclosingFunction == null) return false;

    return _hasRiverpodAnnotation(enclosingFunction.metadata);
  }
}

/// Whether [node] extends a Riverpod state-layer class.
///
/// Prefers the real declaration when it is visible in the same compilation
/// unit; otherwise falls back to the same name heuristics used for classes.
bool _isRiverpodNotifierExtension(ExtensionDeclaration node) {
  final extendedType = node.onClause?.extendedType;
  if (extendedType is! NamedType) return false;

  final targetName = extendedType.name.lexeme;
  if (_widgetSuperclasses.contains(targetName)) return false;
  if (_nonRiverpodNotifierSuperclasses.contains(targetName)) return false;

  final unit = node.thisOrAncestorOfType<CompilationUnit>();
  if (unit != null) {
    for (final declaration in unit.declarations) {
      if (declaration is ClassDeclaration &&
          classDeclarationName(declaration) == targetName) {
        return _isRiverpodNotifierClass(declaration);
      }
    }
  }

  return targetName.endsWith('Notifier');
}

bool _hasRiverpodAnnotation(Iterable<Annotation> metadata) {
  for (final annotation in metadata) {
    final name = annotation.name.name;
    if (name == 'riverpod' || name == 'Riverpod') return true;
  }

  return false;
}

const _widgetSuperclasses = {
  'StatelessWidget',
  'StatefulWidget',
  'State',
  'ConsumerWidget',
  'HookConsumerWidget',
  'HookWidget',
  'ConsumerState',
  'ConsumerStatefulWidget',
  'StatefulHookConsumerWidget',
};

/// Flutter notifiers that end in "Notifier" but are NOT Riverpod state layer.
/// Without this, `class Foo extends ChangeNotifier` would be exempted by the
/// suffix heuristic below.
const _nonRiverpodNotifierSuperclasses = {'ChangeNotifier', 'ValueNotifier'};

bool _hasWidgetName(ClassDeclaration node) {
  final className = classDeclarationName(node);
  if (className == null) return false;

  return className.endsWith('Page') ||
      className.endsWith('Screen') ||
      className.endsWith('View') ||
      className.endsWith('Widget');
}

/// Whether [node] declares a Riverpod state-layer class (a Notifier).
///
/// Signals are checked strongest first, because the weak name heuristics on
/// both sides overlap: a provider may be called `TodoView` and a widget may be
/// called `TodoNotifier`.
///
/// 1. `@riverpod` / `@Riverpod(...)` annotation, or an `extends _$Name`
///    generated superclass — unambiguous state layer.
/// 2. A widget superclass — unambiguous UI layer.
/// 3. `Notifier` family base classes, minus the Flutter notifiers that are not
///    Riverpod state layer.
/// 4. Only then the class-name suffixes.
bool _isRiverpodNotifierClass(ClassDeclaration node) {
  if (_hasRiverpodAnnotation(node.metadata)) return true;

  final superclassName = node.extendsClause?.superclass.name.lexeme;
  if (superclassName != null) {
    if (superclassName.startsWith('_\$')) return true;
    if (_widgetSuperclasses.contains(superclassName)) return false;
    if (_nonRiverpodNotifierSuperclasses.contains(superclassName)) return false;
    // Notifier, AsyncNotifier, StreamNotifier, AutoDisposeNotifier,
    // FamilyAsyncNotifier, and project-local base notifiers all end in
    // "Notifier".
    if (superclassName.endsWith('Notifier')) return true;
  }

  if (_hasWidgetName(node)) return false;

  return classDeclarationName(node)?.endsWith('Notifier') ?? false;
}
