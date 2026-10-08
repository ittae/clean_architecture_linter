import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../../clean_architecture_linter_base.dart';
import '../../compat/analyzer_ast_compat.dart';

/// Reports a Riverpod notifier `extension` whose `@Dependencies([...])`
/// metadata is not covered by the target notifier's
/// `@Riverpod(dependencies: [...])` runtime scope list.
///
/// ## Why this only blows up at runtime
///
/// `@Dependencies` is **lint-only metadata**. The Riverpod docs are explicit:
/// it tells the linter that a *non-provider* object (a widget, an extension,
/// …) depends on scoped providers. It does **not** widen the runtime scope of
/// anything. The only list that changes a notifier's runtime scope is its own
/// `@Riverpod(dependencies: [...])`.
///
/// Notifier methods are routinely split into `extension X on FooNotifier` in a
/// part file, and `@Dependencies` is pinned to that extension. When such a
/// method calls `ref.read(scopedProvider)` for a provider that is **not** in
/// the notifier's own `dependencies`, Riverpod throws at runtime:
///
/// ```
/// Bad state: The provider `fooProvider` depends on `scopedProvider`, which may
/// be scoped. Yet `scopedProvider` is not part of `fooProvider`'s
/// `dependencies` list.
/// ```
///
/// The failure surfaces only on the code path that reads the scoped provider,
/// and it is frequently swallowed by a surrounding `catch`, so the feature
/// fails silently. That makes the lint especially valuable.
///
/// ## Why the upstream `riverpod_lint` rule misses it
///
/// `riverpod_lint`'s `provider_dependencies` walks only the provider
/// declaration's own AST subtree to collect "used" scoped providers, and it
/// treats the extension as an **independent** dependency-list owner — the
/// extension's `@Dependencies` is reconciled against the extension's *own*
/// usage, never against the notifier it extends. So the extension stays
/// self-consistent and the notifier's list never sees the extension's reads.
/// Verified empirically against `riverpod_lint` 3.1.9: the identical read
/// reported `Missing dependencies` when placed directly in the notifier body
/// but produced no diagnostic when moved into an extension in a part file.
///
/// ## What this rule checks (purely syntactic annotation comparison)
///
/// If an `extension` carries `@Dependencies([...])` and the class it extends
/// declares `@Riverpod(dependencies: [...])`, every identifier in the
/// extension's list that is absent from the notifier's list is reported. The
/// rule compares the two annotation lists only; it does **not** verify that the
/// extension body actually reads each provider. A provider the extension
/// declares as a scoped dependency but the notifier does not scope throws at
/// runtime the moment it is read via `ref.read`/`watch`; one that is declared
/// but never read would still be flagged as an intent mismatch (lint-only
/// metadata that claims a scope the notifier does not grant). Both annotations
/// are visible within the same library (parts included), so no cross-library or
/// element resolution is needed.
///
/// ## Known gaps (intentional, documented)
///
/// - If the notifier is annotated with `@riverpod` or `@Riverpod()` **without**
///   a `dependencies:` argument, nothing is reported. Riverpod 3 still asserts
///   when a non-scoped provider reads a scoped one, but detecting that requires
///   whole-program scope inference and is left to the runtime assertion.
/// - If the extended class lives in a different library (not resolvable from
///   the units of this library), nothing is reported — the `@Riverpod` list is
///   not visible for comparison.
class RiverpodExtensionScopedDependencyRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'riverpod_extension_scoped_dependency',
    '{0}',
    correctionMessage: '{1}',
    severity: DiagnosticSeverity.WARNING,
    uniqueName: 'LintCode.riverpod_extension_scoped_dependency',
  );

  RiverpodExtensionScopedDependencyRule()
    : super(
        name: 'riverpod_extension_scoped_dependency',
        description:
            'Requires an extension\'s @Dependencies to be a subset of the '
            'target notifier\'s @Riverpod(dependencies:) runtime scope.',
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
    registry.addExtensionDeclaration(this, _Visitor(this, context));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule, this.context);

  final AnalysisRule rule;
  final RuleContext context;

  String get _filePath =>
      context.currentUnit?.file.path ?? context.definingUnit.file.path;

  @override
  void visitExtensionDeclaration(ExtensionDeclaration node) {
    if (CleanArchitectureUtils.shouldExcludeFile(_filePath)) return;

    // 1. The extension must carry @Dependencies([...]).
    final extensionAnnotation = _dependenciesAnnotation(node.metadata);
    if (extensionAnnotation == null) return;
    final extensionDeps = _dependenciesListNames(extensionAnnotation);
    if (extensionDeps.isEmpty) return;

    // 2. Resolve the class the extension extends, within this library.
    final extendedType = node.onClause?.extendedType;
    if (extendedType is! NamedType) return;
    final targetName = extendedType.name.lexeme;
    final targetClass = _findClassInLibrary(targetName);
    if (targetClass == null) return;

    // 3. The target must declare @Riverpod(dependencies: [...]) — the runtime
    //    scope. Absent `dependencies:` means not scoped: intentionally skipped.
    final riverpodAnnotation = _riverpodAnnotation(targetClass.metadata);
    if (riverpodAnnotation == null) return;
    final scopeList = _riverpodDependenciesList(riverpodAnnotation);
    if (scopeList == null) return;
    final scopeNames = _listNames(scopeList).toSet();

    // 4. Report every extension dependency missing from the runtime scope.
    final missing = [
      for (final name in extensionDeps)
        if (!scopeNames.contains(name)) name,
    ];
    if (missing.isEmpty) return;

    final missingLabel = '[${missing.join(', ')}]';
    rule.reportAtNode(
      extensionAnnotation,
      arguments: [
        'Extension @Dependencies declares scoped provider(s) $missingLabel '
            'that are not in $targetName\'s @Riverpod(dependencies:). '
            '@Dependencies on an extension is lint-only metadata and does not '
            'widen the notifier\'s runtime scope, so ref.read/watch of these '
            'providers throws at runtime.',
        'Add $missingLabel to $targetName\'s @Riverpod(dependencies: [...]) '
            '(its runtime scope), or remove them from the extension\'s '
            '@Dependencies if the notifier never reads them.',
      ],
    );
  }

  /// Finds the [ClassDeclaration] named [name] anywhere in this library's
  /// units (the defining unit plus its parts). Parsed-only; no element
  /// resolution. Returns `null` when the class is in another library.
  ClassDeclaration? _findClassInLibrary(String name) {
    for (final unit in context.allUnits) {
      for (final declaration in unit.unit.declarations) {
        if (declaration is ClassDeclaration &&
            classDeclarationName(declaration) == name) {
          return declaration;
        }
      }
    }
    return null;
  }

  /// The `@Dependencies(...)` annotation in [metadata], or `null`.
  Annotation? _dependenciesAnnotation(Iterable<Annotation> metadata) {
    for (final annotation in metadata) {
      if (_annotationSimpleName(annotation) == 'Dependencies') {
        return annotation;
      }
    }
    return null;
  }

  /// The `@Riverpod(...)` annotation in [metadata], or `null`. The lowercase
  /// `@riverpod` shorthand never carries a `dependencies:` argument, so it is
  /// not matched here.
  Annotation? _riverpodAnnotation(Iterable<Annotation> metadata) {
    for (final annotation in metadata) {
      if (_annotationSimpleName(annotation) == 'Riverpod') return annotation;
    }
    return null;
  }

  /// The identifier names of `@Dependencies([a, b])`'s positional list.
  List<String> _dependenciesListNames(Annotation annotation) {
    final arguments = annotation.arguments?.arguments;
    if (arguments == null || arguments.isEmpty) return const [];
    final expression = callbackArgumentExpression(arguments.first);
    if (expression is! ListLiteral) return const [];
    return _listNames(expression);
  }

  /// The `dependencies:` list literal of `@Riverpod(dependencies: [...])`, or
  /// `null` when the argument is absent (not scoped). An empty `[]` is a
  /// present-but-empty scope and returns an empty list literal, not `null`.
  ListLiteral? _riverpodDependenciesList(Annotation annotation) {
    final arguments = annotation.arguments?.arguments;
    if (arguments == null) return null;
    for (final argument in arguments) {
      if (namedArgumentName(argument) == 'dependencies') {
        final expression = callbackArgumentExpression(argument);
        return expression is ListLiteral ? expression : null;
      }
    }
    return null;
  }

  /// SimpleIdentifier names of a list literal's elements. Non-identifier
  /// elements are ignored.
  List<String> _listNames(ListLiteral list) {
    final names = <String>[];
    for (final element in list.elements) {
      if (element is SimpleIdentifier) {
        names.add(element.name);
      } else if (element is PrefixedIdentifier) {
        names.add(element.identifier.name);
      }
    }
    return names;
  }

  /// The final component of an annotation name (`scope.Dependencies` →
  /// `Dependencies`).
  String _annotationSimpleName(Annotation annotation) {
    final name = annotation.name;
    if (name is PrefixedIdentifier) return name.identifier.name;
    return name.name;
  }
}
