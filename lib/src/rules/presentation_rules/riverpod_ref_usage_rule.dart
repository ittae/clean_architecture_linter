import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../../clean_architecture_linter_base.dart';
import '../../compat/analyzer_ast_compat.dart';
import '../../utils/riverpod_provider_detector.dart';

/// Enforces proper usage of ref.watch() vs ref.read() in Riverpod code.
///
/// Covers Notifier classes, extensions on Notifiers, and top-level
/// `@riverpod` functional providers (whose whole body is the `build()`
/// equivalent). A private synchronous helper that only `build()` runs
/// (directly or transitively) may use `ref.watch()`.
class RiverpodRefUsageRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'riverpod_ref_usage',
    '{0}',
    correctionMessage: '{1}',
    severity: DiagnosticSeverity.WARNING,
    uniqueName: 'LintCode.riverpod_ref_usage',
  );

  RiverpodRefUsageRule()
    : super(
        name: 'riverpod_ref_usage',
        description: 'Checks ref.watch/ref.read usage in Riverpod classes.',
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
    final visitor = _RiverpodRefUsageVisitor(this, context);
    registry.addClassDeclaration(this, visitor);
    // Extension methods on Notifiers (common part-file helpers) need the same
    // ref.watch / ref.read discipline as class members.
    registry.addExtensionDeclaration(this, visitor);
    // Top-level `@riverpod` functional providers are build-only.
    registry.addFunctionDeclaration(this, visitor);
  }
}

class _RiverpodRefUsageVisitor extends SimpleAstVisitor<void> {
  _RiverpodRefUsageVisitor(this.rule, this.context);

  final AnalysisRule rule;
  final RuleContext context;

  String get _filePath =>
      context.currentUnit?.file.path ?? context.definingUnit.file.path;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    if (!_isProviderFile(_filePath)) return;
    if (!isRiverpodNotifierClass(node)) return;

    final members = classMembers(node).toList();
    _scanMembers(
      members,
      buildReachable: _buildReachableHelpers(members, _extensionBodiesOn(node)),
    );
  }

  /// Method bodies of same-file extensions on [node]'s class; they can call
  /// its private helpers too.
  List<AstNode> _extensionBodiesOn(ClassDeclaration node) {
    final unit = node.parent;
    final className = classDeclarationName(node);
    if (unit is! CompilationUnit || className == null) return const [];
    final bodies = <AstNode>[];
    for (final declaration in unit.declarations) {
      if (declaration is! ExtensionDeclaration) continue;
      final extended = declaration.onClause?.extendedType;
      if (extended is! NamedType || extended.name.lexeme != className) continue;
      for (final member in extensionMembers(declaration)) {
        if (member is MethodDeclaration) bodies.add(member.body);
      }
    }
    return bodies;
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    if (node.parent is! CompilationUnit) return;
    if (!_isProviderFile(_filePath)) return;
    if (!hasRiverpodAnnotation(node.metadata)) return;

    // The function body runs once per (re)build, exactly like `build()`.
    _checkBodyRefUsage(node.functionExpression.body, isBuildMethod: true);
  }

  @override
  void visitExtensionDeclaration(ExtensionDeclaration node) {
    if (!_isProviderFile(_filePath)) return;
    if (!isRiverpodNotifierExtension(node)) return;

    // Extension members are never the Riverpod `build()` override.
    _scanMembers(extensionMembers(node), isBuildMethod: false);
  }

  void _scanMembers(
    Iterable<AstNode> members, {
    bool? isBuildMethod,
    Set<String> buildReachable = const {},
  }) {
    for (final member in members) {
      if (member is MethodDeclaration) {
        _checkBodyRefUsage(
          member.body,
          isBuildMethod: isBuildMethod ?? member.name.lexeme == 'build',
          allowWatchInMethod: buildReachable.contains(member.name.lexeme),
        );
      }
    }
  }

  /// Names of private, synchronous methods that only `build()` runs: every
  /// call to them is `name()` / `this.name()` made in `build()`'s synchronous
  /// run or in another such helper, and nothing else references them.
  ///
  /// `ref.watch()` there runs inside the synchronous `build()` call graph, so
  /// it is a reactive dependency of the provider, not a one-time read. Left
  /// out, because `ref.watch()` is a real mistake there:
  /// - public, `async` and generator (`sync*`) methods, which event handlers
  ///   or a suspension point can run;
  /// - every helper of an `async` `build()`, whose calls may follow an
  ///   `await` (kept conservative on purpose);
  /// - a call inside any closure (`ref.listen`, `Timer`, `then`,
  ///   `Stream.map`, ...), which may run after `build()` returned;
  /// - a helper that anything else also calls: another method, a field
  ///   initializer, or an extension in the same file (extensions in other
  ///   `part` files are not visible);
  /// - a helper used as a tear-off (`ref.listen(p, _onChange)`).
  Set<String> _buildReachableHelpers(
    List<AstNode> members,
    List<AstNode> extensionBodies,
  ) {
    final helpers = <String, MethodDeclaration>{};
    MethodDeclaration? build;
    for (final member in members) {
      if (member is! MethodDeclaration) continue;
      final name = member.name.lexeme;
      if (name == 'build') {
        build = member;
      } else if (name.startsWith('_') &&
          !member.body.isAsynchronous &&
          !member.body.isGenerator) {
        helpers[name] = member;
      }
    }
    if (build == null || build.body.isAsynchronous || helpers.isEmpty) {
      return const {};
    }

    final names = helpers.keys.toSet();
    final allSites = _callSites([...members, ...extensionBodies], names);
    final tearOffs = _TearOffCollector(names);
    for (final node in [...members, ...extensionBodies]) {
      node.accept(tearOffs);
    }

    // Greatest fixed point: a helper stays only while every call to it sits in
    // `build()`'s synchronous run or in the synchronous run of a kept helper.
    final reachable = _reachableFromBuild(build, helpers);
    var kept = {
      for (final name in reachable)
        if (!tearOffs.names.contains(name)) name,
    };
    while (true) {
      final syncSites = <MethodInvocation>{
        ..._callSites(
          [build.body],
          names,
          syncOnly: true,
        ).values.expand((sites) => sites),
        for (final name in kept)
          ..._callSites(
            [helpers[name]!.body],
            names,
            syncOnly: true,
          ).values.expand((sites) => sites),
      };
      final next = {
        for (final name in kept)
          if (syncSites.containsAll(allSites[name] ?? const {})) name,
      };
      if (next.length == kept.length) return next;
      kept = next;
    }
  }

  /// Helpers `build()` reaches through synchronous calls only.
  Set<String> _reachableFromBuild(
    MethodDeclaration build,
    Map<String, MethodDeclaration> helpers,
  ) {
    final names = helpers.keys.toSet();
    final reached = <String>{};
    final pending = <AstNode>[build.body];
    while (pending.isNotEmpty) {
      final sites = _callSites([pending.removeLast()], names, syncOnly: true);
      for (final name in sites.keys) {
        if (reached.add(name)) pending.add(helpers[name]!.body);
      }
    }
    return reached;
  }

  /// Call sites of [names] found in [roots], keyed by helper name.
  Map<String, Set<MethodInvocation>> _callSites(
    List<AstNode> roots,
    Set<String> names, {
    bool syncOnly = false,
  }) {
    final collector = _SelfCallCollector(names, syncOnly: syncOnly);
    for (final root in roots) {
      root.accept(collector);
    }
    return collector.sites;
  }

  bool _isProviderFile(String filePath) {
    if (CleanArchitectureUtils.shouldExcludeFile(filePath)) return false;

    final normalizedPath = filePath.replaceAll('\\', '/').toLowerCase();
    if (!normalizedPath.contains('/presentation/')) return false;

    return normalizedPath.contains('/providers/') ||
        normalizedPath.endsWith('_provider.dart') ||
        normalizedPath.endsWith('_providers.dart') ||
        normalizedPath.endsWith('_notifier.dart') ||
        normalizedPath.endsWith('_notifiers.dart');
  }

  void _checkBodyRefUsage(
    FunctionBody body, {
    required bool isBuildMethod,
    bool allowWatchInMethod = false,
  }) {
    if (body is! BlockFunctionBody && body is! ExpressionFunctionBody) return;

    final refWatchCalls = <MethodInvocation>[];
    final refReadCalls = <MethodInvocation>[];
    _collectRefCalls(body, refWatchCalls, refReadCalls);

    if (isBuildMethod) {
      for (final refReadCall in refReadCalls) {
        if (_isAllowedOneShotProviderCall(refReadCall) ||
            _isNotifierAccess(refReadCall)) {
          continue;
        }
        rule.reportAtNode(
          refReadCall,
          arguments: const [
            'Use ref.watch() instead of ref.read() for State providers in build().',
            'Change ref.read() to ref.watch() for reactive State provider dependencies.',
          ],
        );
      }
    } else {
      for (final refWatchCall in refWatchCalls) {
        // A build-only helper may watch in its own synchronous run, but a
        // closure inside it can fire after `build()` returned.
        if (allowWatchInMethod && !_isInsideClosure(refWatchCall, body)) {
          continue;
        }
        rule.reportAtNode(
          refWatchCall,
          arguments: const [
            'Use ref.read() instead of ref.watch() in methods for one-time reads.',
            'Change ref.watch() to ref.read() for one-time provider access in methods.',
          ],
        );
      }
    }
  }

  bool _isInsideClosure(AstNode node, AstNode body) {
    for (AstNode? p = node.parent; p != null && p != body; p = p.parent) {
      if (p is FunctionExpression) return true;
    }
    return false;
  }

  void _collectRefCalls(
    AstNode node,
    List<MethodInvocation> refWatchCalls,
    List<MethodInvocation> refReadCalls,
  ) {
    if (node is MethodInvocation) {
      final methodName = node.methodName.name;
      final target = node.target;
      if (target is SimpleIdentifier && target.name == 'ref') {
        if (methodName == 'watch') {
          refWatchCalls.add(node);
        } else if (methodName == 'read') {
          refReadCalls.add(node);
        }
      }
    }

    for (final child in node.childEntities) {
      if (child is AstNode) {
        _collectRefCalls(child, refWatchCalls, refReadCalls);
      }
    }
  }

  bool _isAllowedOneShotProviderCall(MethodInvocation refReadCall) {
    final args = refReadCall.argumentList.arguments;
    if (args.isEmpty) return false;

    final firstArg = args.first;
    String? providerName;
    if (firstArg is SimpleIdentifier) {
      providerName = firstArg.name;
    } else if (firstArg is MethodInvocation) {
      providerName = firstArg.methodName.name;
    } else if (firstArg is FunctionExpressionInvocation) {
      final function = firstArg.function;
      if (function is SimpleIdentifier) providerName = function.name;
    }

    if (providerName != null && _isAllowedOneShotProviderName(providerName)) {
      return true;
    }

    final parent = refReadCall.parent;
    if (parent is FunctionExpressionInvocation) return true;
    if (parent is AwaitExpression &&
        parent.parent is FunctionExpressionInvocation) {
      return true;
    }

    return false;
  }

  bool _isAllowedOneShotProviderName(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.endsWith('usecaseprovider')) return true;

    // Stable DI / infrastructure providers are one-shot dependencies, not
    // reactive UI state. Riverpod 3.3 still models them as Provider/Ref reads;
    // flagging them as "use ref.watch" is a common false positive.
    // Residual FN: names ending in Service/Api/Storage can still wrap reactive
    // state in some apps — prefer tighter suffixes or type-aware checks later.
    const stableDependencySuffixes = [
      'repositoryprovider',
      'datasourceprovider',
      'serviceprovider',
      'clientprovider',
      'apiprovider',
      'daoprovider',
      'loggerprovider',
      'analyticsprovider',
      'storageprovider',
    ];
    for (final suffix in stableDependencySuffixes) {
      if (lowerName.endsWith(suffix)) return true;
    }

    const useCasePrefixes = [
      'get',
      'create',
      'update',
      'delete',
      'fetch',
      'save',
      'load',
      'submit',
      'send',
      'retrieve',
    ];
    for (final prefix in useCasePrefixes) {
      if (lowerName.startsWith(prefix) && lowerName.endsWith('provider')) {
        return true;
      }
    }
    return false;
  }

  bool _isNotifierAccess(MethodInvocation refReadCall) {
    final args = refReadCall.argumentList.arguments;
    if (args.isEmpty) return false;

    final firstArg = args.first;
    if (firstArg is PropertyAccess) {
      return firstArg.propertyName.name == 'notifier';
    }
    if (firstArg is PrefixedIdentifier) {
      return firstArg.identifier.name == 'notifier';
    }
    return false;
  }
}

/// Collects calls to own-class methods named in [_candidates] written as
/// `name()` or `this.name()`.
///
/// With [syncOnly], closures are skipped: a closure may run after the
/// enclosing body returned, so a call inside it is not part of that body's
/// synchronous run.
class _SelfCallCollector extends RecursiveAstVisitor<void> {
  _SelfCallCollector(this._candidates, {required this.syncOnly});

  final Set<String> _candidates;
  final bool syncOnly;
  final Map<String, Set<MethodInvocation>> sites = {};

  @override
  void visitFunctionExpression(FunctionExpression node) {
    if (syncOnly) return;
    super.visitFunctionExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final target = node.target;
    final name = node.methodName.name;
    if ((target == null || target is ThisExpression) &&
        _candidates.contains(name)) {
      (sites[name] ??= {}).add(node);
    }
    super.visitMethodInvocation(node);
  }
}

/// Collects [_candidates] referenced other than as the method name of a call,
/// i.e. tear-offs such as `ref.listen(p, _onChange)` or `this._onChange`.
class _TearOffCollector extends RecursiveAstVisitor<void> {
  _TearOffCollector(this._candidates);

  final Set<String> _candidates;
  final Set<String> names = {};

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    final parent = node.parent;
    final isCallName = parent is MethodInvocation && parent.methodName == node;
    if (!isCallName && _candidates.contains(node.name)) names.add(node.name);
    super.visitSimpleIdentifier(node);
  }
}
