import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../../clean_architecture_linter_base.dart';
import '../../compat/analyzer_ast_compat.dart';
import '../../utils/riverpod_provider_detector.dart';

/// Methods that register a long-lived callback / start a resource that
/// out-lives a single async call (and therefore the provider, if not cancelled).
///
/// Stream `.listen` is intentionally **not** here: tracking the stream
/// receiver double-counts with the assignment path
/// (`final sub = stream.listen(...)`) and would suggest `stream.cancel()`.
/// Assigned listens are tracked via `_maybeAddCreation` only.
const _startMethods = {'start'};

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
    if (!isRiverpodNotifierClass(node)) return;

    // The lifecycle resources are created in build(); scan the class for
    // resources and direct ref.onDispose cleanup arguments. Helper method
    // bodies registered in onDispose are not traversed today.
    final released = <String>{};
    final resources = <_Resource>[];
    final scanner = _BodyScanner(released, resources);
    node.accept(scanner);

    for (final resource in resources) {
      // Empty name = anonymous / fire-and-forget; never matches a release.
      if (resource.name.isNotEmpty && released.contains(resource.name)) {
        continue;
      }
      final example = resource.name.isEmpty
          ? 'assign it to a variable and call ref.onDispose(() => variable.${_release(resource)}())'
          : 'ref.onDispose(${resource.name}.${_release(resource)})';
      rule.reportAtNode(
        resource.node,
        arguments: [
          _problem(resource),
          'Cancel it inside ref.onDispose (e.g. $example) '
              'so its callbacks stop firing after the provider is disposed.',
        ],
      );
    }
  }

  String _problem(_Resource r) {
    final label = r.name.isEmpty ? r.kind : '"${r.name}"';
    switch (r.kind) {
      case 'listener':
        return r.name.isEmpty
            ? 'Lifecycle listener is not disposed in ref.onDispose.'
            : 'Lifecycle listener $label is not disposed in ref.onDispose.';
      case 'subscription':
        return r.name.isEmpty
            ? 'Stream subscription is not cancelled in ref.onDispose.'
            : 'Stream subscription $label is not cancelled in ref.onDispose.';
      default:
        return r.name.isEmpty
            ? 'Timer/resource is started but not cancelled in ref.onDispose.'
            : 'Timer/resource $label is started but not cancelled in ref.onDispose.';
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

    // recv.start(onX: ...) only. Stream.listen is tracked via assignment
    // (`final sub = stream.listen(...)`) — tracking the stream receiver here
    // double-counts and suggests `stream.cancel()`, which is wrong.
    // Fire-and-forget `stream.listen(...)` remains a name-based FN by design.
    if (_startMethods.contains(node.methodName.name)) {
      final name = _receiverName(node.target);
      if (name != null && _hasCallbackArgument(node)) {
        _resources.add(_Resource(name, node, 'timer'));
      }
    }

    // Unassigned disposable ctor as a statement, e.g.
    //   Timer.periodic(const Duration(seconds: 1), (_) {});
    // Assigned forms are handled by visitVariableDeclaration / Assignment.
    if (_isFireAndForgetDisposable(node)) {
      final kind = _kindForDisposableCtor(_disposableCtorName(node) ?? '');
      _resources.add(_Resource('', node, kind));
    }

    super.visitMethodInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    // Same as MethodInvocation path for resolved AST fire-and-forget ctors.
    if (_isFireAndForgetDisposable(node)) {
      final typeName = node.constructorName.type.name.lexeme;
      _resources.add(_Resource('', node, _kindForDisposableCtor(typeName)));
    }
    super.visitInstanceCreationExpression(node);
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
    _resources.add(
      _Resource(name, reportNode, _kindForDisposableCtor(typeName)),
    );
  }

  String _kindForDisposableCtor(String typeName) {
    if (typeName == 'AppLifecycleListener') return 'listener';
    if (typeName == 'StreamSubscription') return 'subscription';
    return 'timer';
  }

  /// True when [node] is a disposable constructor used as a bare statement
  /// (no variable / field assignment), so it can never be cancelled by name.
  bool _isFireAndForgetDisposable(AstNode node) {
    if (node.parent is! ExpressionStatement) return false;
    if (node is MethodInvocation) {
      final typeName = _disposableCtorName(node);
      return typeName != null && _disposableCtors.contains(typeName);
    }
    if (node is InstanceCreationExpression) {
      final typeName = node.constructorName.type.name.lexeme;
      return _disposableCtors.contains(typeName);
    }
    return false;
  }

  /// Parsed-AST ctor form: `Timer(...)` or `Timer.periodic(...)`.
  String? _disposableCtorName(MethodInvocation node) {
    final target = node.target;
    if (target == null) {
      // Unnamed ctor call style: `Timer(...)` / `AppLifecycleListener(...)`.
      return _disposableCtors.contains(node.methodName.name)
          ? node.methodName.name
          : null;
    }
    if (target is SimpleIdentifier && _disposableCtors.contains(target.name)) {
      // Named ctor: `Timer.periodic(...)`.
      return target.name;
    }
    return null;
  }

  bool _hasCallbackArgument(MethodInvocation node) {
    for (final arg in node.argumentList.arguments) {
      final name = namedArgumentName(arg);
      if (name != null) {
        // Named argument: only `onX:`-style callbacks count as a start hook.
        if (name.startsWith('on')) return true;
        continue;
      }
      // Positional argument: an inline closure is a start callback.
      if (callbackArgumentExpression(arg) is FunctionExpression) return true;
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
