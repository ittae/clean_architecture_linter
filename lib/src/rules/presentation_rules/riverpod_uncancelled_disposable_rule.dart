import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../../clean_architecture_linter_base.dart';

/// Methods that register a long-lived callback / start a resource that
/// out-lives a single async call (and therefore the provider, if not cancelled).
const _startMethods = {'start', 'listen'};

/// Constructors that create a resource which must be disposed.
const _disposableCtors = {
  'Timer',
  'AppLifecycleListener',
  'StreamSubscription',
};

/// Calls that release such a resource.
const _releaseMethods = {'cancel', 'dispose', 'close', 'stop'};

/// Reports disposable resources created in a Riverpod provider's `build()`
/// that are not released via `ref.onDispose`.
///
/// Timers, stream subscriptions and lifecycle listeners that are started in
/// `build()` keep firing their callbacks after the provider is disposed. Those
/// callbacks then touch `state`/`ref` on a disposed notifier and crash with
/// `UnmountedRefException`. They must be cancelled inside `ref.onDispose`.
class RiverpodUncancelledDisposableRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'riverpod_uncancelled_disposable',
    '{0}',
    correctionMessage: '{1}',
    severity: DiagnosticSeverity.WARNING,
    uniqueName: 'LintCode.riverpod_uncancelled_disposable',
  );

  RiverpodUncancelledDisposableRule()
    : super(
        name: 'riverpod_uncancelled_disposable',
        description:
            'Disposable resources started in a provider must be cancelled in ref.onDispose.',
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
    registry.addClassDeclaration(
      this,
      _UncancelledDisposableVisitor(this, context),
    );
  }
}

class _Resource {
  _Resource(this.name, this.node, this.kind);

  final String name;
  final AstNode node;
  final String kind; // 'timer', 'listener', 'subscription'
}

class _UncancelledDisposableVisitor extends SimpleAstVisitor<void> {
  _UncancelledDisposableVisitor(this.rule, this.context);

  final AnalysisRule rule;
  final RuleContext context;

  String get _filePath =>
      context.currentUnit?.file.path ?? context.definingUnit.file.path;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    if (!_shouldCheckFile(_filePath)) return;
    if (!_isRiverpodProviderClass(node)) return;

    // The lifecycle resources are created in build(); scan the class for
    // resources and direct ref.onDispose cleanup arguments. Helper method
    // bodies registered in onDispose are not traversed today.
    final released = <String>{};
    final resources = <_Resource>[];
    final scanner = _BodyScanner(released, resources);
    node.accept(scanner);

    for (final resource in resources) {
      if (released.contains(resource.name)) continue;
      rule.reportAtNode(
        resource.node,
        arguments: [
          _problem(resource),
          'Cancel it inside ref.onDispose (e.g. ref.onDispose(${resource.name}.${_release(resource)})) '
              'so its callbacks stop firing after the provider is disposed.',
        ],
      );
    }
  }

  String _problem(_Resource r) {
    switch (r.kind) {
      case 'listener':
        return 'Lifecycle listener "${r.name}" is not disposed in ref.onDispose.';
      case 'subscription':
        return 'Stream subscription "${r.name}" is not cancelled in ref.onDispose.';
      default:
        return 'Timer/resource "${r.name}" is started but not cancelled in ref.onDispose.';
    }
  }

  String _release(_Resource r) => r.kind == 'listener' ? 'dispose' : 'cancel';

  bool _shouldCheckFile(String filePath) {
    if (CleanArchitectureUtils.shouldExcludeFile(filePath)) return false;
    final normalized = filePath.replaceAll('\\', '/').toLowerCase();
    return normalized.contains('/lib/') &&
        normalized.contains('/presentation/') &&
        normalized.contains('/providers/');
  }

  bool _isRiverpodProviderClass(ClassDeclaration node) {
    for (final metadata in node.metadata) {
      final name = metadata.name.name;
      if (name == 'riverpod' || name == 'Riverpod') return true;
    }
    final extendsClause = node.extendsClause;
    if (extendsClause == null) return false;
    return extendsClause.superclass.name.lexeme.startsWith(r'_$');
  }
}

/// Collects released names (inside ref.onDispose) and disposable resources in
/// one traversal of the class body.
class _BodyScanner extends RecursiveAstVisitor<void> {
  _BodyScanner(this._released, this._resources);

  final Set<String> _released;
  final List<_Resource> _resources;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // ref.onDispose(() { x.cancel(); }) — collect released names.
    if (node.methodName.name == 'onDispose' && _isRefTarget(node.target)) {
      node.argumentList.accept(_ReleaseCollector(_released));
    }

    // recv.start(onComplete: ...) / stream.listen(...) — resource started.
    // Riverpod owns ref.listen callbacks, so they are not user disposables.
    if (_startMethods.contains(node.methodName.name) &&
        !_isRiverpodOwnedListen(node)) {
      final name = _receiverName(node.target);
      if (name != null && _hasCallbackArgument(node)) {
        final kind = node.methodName.name == 'listen'
            ? 'subscription'
            : 'timer';
        _resources.add(_Resource(name, node, kind));
      }
    }

    super.visitMethodInvocation(node);
  }

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    final name = _assignedName(node.leftHandSide);
    if (name != null) _maybeAddCreation(name, node.rightHandSide, node);
    super.visitAssignmentExpression(node);
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    final init = node.initializer;
    if (init != null) _maybeAddCreation(node.name.lexeme, init, node);
    super.visitVariableDeclaration(node);
  }

  void _maybeAddCreation(String name, Expression rhs, AstNode reportNode) {
    if (rhs is InstanceCreationExpression) {
      _addByCtorName(name, rhs.constructorName.type.name.lexeme, reportNode);
      return;
    }
    if (rhs is MethodInvocation) {
      // `X.listen(...)` → the assigned value is a StreamSubscription.
      if (rhs.methodName.name == 'listen') {
        if (!_isRiverpodOwnedListen(rhs)) {
          _resources.add(_Resource(name, reportNode, 'subscription'));
        }
        return;
      }
      // On parsed (unresolved) AST a constructor call `Timer(...)` /
      // `AppLifecycleListener(...)` is a MethodInvocation, not an
      // InstanceCreationExpression. Handle both unnamed and named ctors.
      final target = rhs.target;
      if (target == null) {
        _addByCtorName(name, rhs.methodName.name, reportNode);
      } else if (target is SimpleIdentifier) {
        _addByCtorName(name, target.name, reportNode);
      }
    }
  }

  void _addByCtorName(String name, String typeName, AstNode reportNode) {
    if (!_disposableCtors.contains(typeName)) return;
    final kind = typeName == 'AppLifecycleListener'
        ? 'listener'
        : (typeName == 'StreamSubscription' ? 'subscription' : 'timer');
    _resources.add(_Resource(name, reportNode, kind));
  }

  bool _hasCallbackArgument(MethodInvocation node) {
    for (final arg in node.argumentList.arguments) {
      if (arg is NamedExpression && arg.name.label.name.startsWith('on')) {
        return true;
      }
      if (arg is FunctionExpression) return true;
    }
    return false;
  }

  bool _isRefTarget(Expression? target) {
    if (target is SimpleIdentifier) return target.name == 'ref';
    return target is PropertyAccess &&
        target.target is ThisExpression &&
        target.propertyName.name == 'ref';
  }

  bool _isRiverpodOwnedListen(MethodInvocation node) =>
      node.methodName.name == 'listen' && _isRefTarget(node.target);

  String? _receiverName(Expression? target) => _nameOf(target);

  String? _assignedName(Expression lhs) => _nameOf(lhs);

  String? _nameOf(Expression? expr) {
    if (expr is SimpleIdentifier) return expr.name;
    if (expr is PrefixedIdentifier && expr.prefix.name == 'this') {
      return expr.identifier.name;
    }
    if (expr is PropertyAccess && expr.target is ThisExpression) {
      return expr.propertyName.name;
    }
    return null;
  }
}

/// Collects identifier names that have a release method called on them.
class _ReleaseCollector extends RecursiveAstVisitor<void> {
  _ReleaseCollector(this._released);

  final Set<String> _released;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (_releaseMethods.contains(node.methodName.name)) {
      final name = _nameOf(node.target);
      if (name != null) _released.add(name);
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (_releaseMethods.contains(node.identifier.name)) {
      final name = _nameOf(node.prefix);
      if (name != null) _released.add(name);
    }
    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    if (_releaseMethods.contains(node.propertyName.name)) {
      final name = _nameOf(node.target);
      if (name != null) _released.add(name);
    }
    super.visitPropertyAccess(node);
  }

  String? _nameOf(Expression? expr) {
    if (expr is SimpleIdentifier) return expr.name;
    if (expr is PrefixedIdentifier && expr.prefix.name == 'this') {
      return expr.identifier.name;
    }
    if (expr is PropertyAccess && expr.target is ThisExpression) {
      return expr.propertyName.name;
    }
    return null;
  }
}
