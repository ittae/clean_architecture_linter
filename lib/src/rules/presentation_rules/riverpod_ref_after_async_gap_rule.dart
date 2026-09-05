import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../../clean_architecture_linter_base.dart';
import '../../compat/analyzer_ast_compat.dart';
import '../../utils/riverpod_provider_detector.dart';

const _trackedRefMethods = {'read', 'watch', 'listen', 'invalidate', 'refresh'};
const _futureContinuationMethods = {'then', 'catchError', 'whenComplete'};

/// Selects which post-async-gap sites a [RiverpodRefAfterAsyncGapVisitor]
/// reports.
///
/// [RiverpodRefAfterAsyncGapRule] tracks `ref.*` calls only. Unguarded
/// `state = …` writes and `state` reads after a gap are tracked by the opt-in
/// `riverpod_state_after_async_gap` rule, which reuses the same visitor with
/// [stateAssignments] and [stateReads] enabled instead.
class RefGapTracking {
  const RefGapTracking({
    required this.refCalls,
    required this.stateAssignments,
    required this.stateReads,
  });

  /// Report `ref.read/watch/listen/invalidate/refresh` after an async gap.
  final bool refCalls;

  /// Report simple `state = …` / `this.state = …` after an async gap.
  final bool stateAssignments;

  /// Report `state` / `this.state` reads (the getter also throws once the
  /// provider is disposed) after an async gap.
  final bool stateReads;
}

/// Reports Riverpod `ref` usage after an async gap in provider classes.
///
/// Unguarded `state` writes after a gap are intentionally *not* reported here;
/// see the opt-in `riverpod_state_after_async_gap` rule.
class RiverpodRefAfterAsyncGapRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'riverpod_ref_after_async_gap',
    '{0}',
    correctionMessage: '{1}',
    severity: DiagnosticSeverity.INFO,
    uniqueName: 'LintCode.riverpod_ref_after_async_gap',
  );

  RiverpodRefAfterAsyncGapRule()
    : super(
        name: 'riverpod_ref_after_async_gap',
        description:
            'Advises against using Riverpod ref after an async gap (await or Future continuations) in provider classes.',
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
    final visitor = RiverpodRefAfterAsyncGapVisitor(
      this,
      context,
      tracking: const RefGapTracking(
        refCalls: true,
        stateAssignments: false,
        stateReads: false,
      ),
    );
    registry.addClassDeclaration(this, visitor);
    // Notifier helpers are routinely `extension on FooNotifier` (often in a
    // part file). Class-only registration skipped those members entirely.
    registry.addExtensionDeclaration(this, visitor);
  }
}

/// Scans Riverpod notifier classes/extensions under
/// `lib/**/presentation/**/providers/**` for post-async-gap sites selected by
/// [tracking]. Shared by `riverpod_ref_after_async_gap` and
/// `riverpod_state_after_async_gap`.
class RiverpodRefAfterAsyncGapVisitor extends SimpleAstVisitor<void> {
  RiverpodRefAfterAsyncGapVisitor(
    this.rule,
    this.context, {
    required this.tracking,
  });

  final AnalysisRule rule;
  final RuleContext context;
  final RefGapTracking tracking;

  String get _filePath =>
      context.currentUnit?.file.path ?? context.definingUnit.file.path;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    if (!_shouldCheckFile(_filePath)) return;
    if (!isRiverpodNotifierClass(node)) return;

    _scanMembers(classMembers(node));
  }

  @override
  void visitExtensionDeclaration(ExtensionDeclaration node) {
    if (!_shouldCheckFile(_filePath)) return;
    if (!isRiverpodNotifierExtension(node)) return;

    _scanMembers(extensionMembers(node));
  }

  void _scanMembers(Iterable<AstNode> members) {
    for (final member in members) {
      if (member is! MethodDeclaration) continue;
      if (_isPrivate(member.name.lexeme)) continue;

      final reportedRefCallOffsets = <int>{};
      if (member.body.isAsynchronous) {
        _AsyncRefAfterGapScanner(
          rule,
          tracking: tracking,
          reportedRefCallOffsets: reportedRefCallOffsets,
        ).scan(member.body);
      }

      member.body.accept(
        _AsyncCallbackScanner(
          rule,
          tracking: tracking,
          reportedRefCallOffsets: reportedRefCallOffsets,
        ),
      );
    }
  }

  bool _shouldCheckFile(String filePath) {
    if (CleanArchitectureUtils.shouldExcludeFile(filePath)) return false;

    final normalized = filePath.replaceAll('\\', '/').toLowerCase();
    return normalized.contains('/lib/') &&
        normalized.contains('/presentation/') &&
        normalized.contains('/providers/');
  }

  bool _isPrivate(String name) => name.startsWith('_');
}

class _AsyncCallbackScanner extends RecursiveAstVisitor<void> {
  _AsyncCallbackScanner(
    this.rule, {
    required RefGapTracking tracking,
    Set<int>? reportedRefCallOffsets,
  }) : _tracking = tracking,
       _reportedRefCallOffsets = reportedRefCallOffsets ?? {};

  final AnalysisRule rule;
  final RefGapTracking _tracking;
  final Set<int> _reportedRefCallOffsets;
  final Map<String, FunctionDeclaration> _localFunctions = {};

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    if (!node.functionExpression.body.isAsynchronous) {
      _localFunctions[node.name.lexeme] = node;
    }

    super.visitFunctionDeclaration(node);
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    if (node.body.isAsynchronous) {
      _AsyncRefAfterGapScanner(
        rule,
        tracking: _tracking,
        reportedRefCallOffsets: _reportedRefCallOffsets,
      ).scan(node.body);
    }

    super.visitFunctionExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (_futureContinuationMethods.contains(node.methodName.name)) {
      for (final argument in node.argumentList.arguments) {
        final body = _resolveCallbackBody(argument);
        if (body == null) continue;

        _AsyncRefAfterGapScanner(
          rule,
          tracking: _tracking,
          hasInheritedAsyncGap: true,
          reportedRefCallOffsets: _reportedRefCallOffsets,
        ).scan(body);
      }
    }

    super.visitMethodInvocation(node);
  }

  /// Resolves a `then`/`catchError`/`whenComplete` argument to the
  /// [FunctionBody] it will run, covering both inline closures and
  /// tear-offs of a local function declared earlier in the same method
  /// (e.g. `fetchTodo().then(onDone)`).
  FunctionBody? _resolveCallbackBody(AstNode argument) {
    final expression = callbackArgumentExpression(argument);
    if (expression is FunctionExpression) return expression.body;
    if (expression is SimpleIdentifier) {
      return _localFunctions[expression.name]?.functionExpression.body;
    }

    return null;
  }
}

class _AsyncRefAfterGapScanner extends RecursiveAstVisitor<void> {
  _AsyncRefAfterGapScanner(
    this.rule, {
    required RefGapTracking tracking,
    bool hasInheritedAsyncGap = false,
    Map<String, FunctionDeclaration>? localFunctions,
    Set<String>? activeLocalFunctionNames,
    Set<int>? reportedRefCallOffsets,
  }) : _tracking = tracking,
       _hasInheritedAsyncGap = hasInheritedAsyncGap,
       _localFunctions = localFunctions ?? {},
       _activeLocalFunctionNames = activeLocalFunctionNames ?? {},
       _reportedRefCallOffsets = reportedRefCallOffsets ?? {};

  final AnalysisRule rule;
  final RefGapTracking _tracking;
  final bool _hasInheritedAsyncGap;
  final Map<String, FunctionDeclaration> _localFunctions;
  final Set<String> _activeLocalFunctionNames;
  final Set<int> _reportedRefCallOffsets;
  final List<MethodInvocation> _refCalls = [];
  final List<AssignmentExpression> _stateAssignments = [];
  final List<SimpleIdentifier> _stateReads = [];
  final List<AssignmentExpression> _reportedAssignments = [];
  final Set<int> _reportedReadStatementOffsets = {};
  FunctionBody? _scannedBody;

  void scan(FunctionBody body) {
    _scannedBody = body;
    body.accept(this);

    if (_tracking.refCalls) {
      for (final refCall in _refCalls) {
        if (_shouldReport(refCall)) {
          _reportRefCall(refCall);
        }
      }
    }

    if (_tracking.stateAssignments) {
      for (final assignment in _stateAssignments) {
        if (_shouldReport(assignment)) {
          _reportedAssignments.add(assignment);
          _reportStateAssignment(assignment);
        }
      }
    }

    if (_tracking.stateReads) {
      for (final read in _stateReads) {
        // `state = state.copyWith(…)` is one finding, not two.
        if (_isInsideReportedAssignment(read)) continue;
        if (!_shouldReport(read)) continue;
        // One finding per statement; `state.a + state.b` is a single site.
        final statement = read.thisOrAncestorOfType<Statement>();
        if (!_reportedReadStatementOffsets.add(
          statement?.offset ?? read.offset,
        )) {
          continue;
        }
        _reportStateRead(read);
      }
    }
  }

  bool _isInsideReportedAssignment(AstNode node) => _reportedAssignments.any(
    (assignment) =>
        node.offset >= assignment.offset && node.end <= assignment.end,
  );

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    if (node.functionExpression.body.isAsynchronous) {
      // Async local functions are scanned separately by _AsyncCallbackScanner.
      return;
    }

    _localFunctions[node.name.lexeme] = node;
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    if (node.body.isAsynchronous) {
      // Async callbacks are scanned separately by _AsyncCallbackScanner.
      return;
    }

    super.visitFunctionExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final target = node.target;
    final methodName = node.methodName.name;

    if (_isRefTarget(target) && _trackedRefMethods.contains(methodName)) {
      _refCalls.add(node);
    }

    _scanLocalFunctionInvocation(node);

    super.visitMethodInvocation(node);
  }

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    // Simple `state = …` / `this.state = …` only.
    // Out of scope: compound ops (`??=`, `+=`, …); name-based match may FP on
    // a local `state` variable (file path is limited to presentation/providers).
    if (_tracking.stateAssignments &&
        node.operator.lexeme == '=' &&
        _isStateTarget(node.leftHandSide)) {
      _stateAssignments.add(node);
    }

    super.visitAssignmentExpression(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (_tracking.stateReads && _isStateRead(node)) {
      _stateReads.add(node);
    }

    super.visitSimpleIdentifier(node);
  }

  /// `state` / `this.state` used as a value. Excludes assignment targets
  /// (tracked separately), declarations, named-argument labels, method names,
  /// and `other.state` properties of some other object.
  bool _isStateRead(SimpleIdentifier node) {
    if (node.name != 'state' || node.inDeclarationContext()) return false;

    final parent = node.parent;
    if (parent is Label) return false;
    if (parent is MethodInvocation && parent.methodName == node) return false;
    if (parent is AssignmentExpression && parent.leftHandSide == node) {
      return false;
    }
    if (parent is PrefixedIdentifier && parent.identifier == node) return false;
    if (parent is PropertyAccess && parent.propertyName == node) {
      if (parent.target is! ThisExpression) return false;
      final grandParent = parent.parent;
      if (grandParent is AssignmentExpression &&
          grandParent.leftHandSide == parent) {
        return false;
      }
    }

    return true;
  }

  bool _isRefTarget(Expression? target) {
    if (target is SimpleIdentifier) return target.name == 'ref';

    return target is PropertyAccess &&
        target.target is ThisExpression &&
        target.propertyName.name == 'ref';
  }

  bool _isStateTarget(Expression target) {
    if (target is SimpleIdentifier) return target.name == 'state';

    return target is PropertyAccess &&
        target.target is ThisExpression &&
        target.propertyName.name == 'state';
  }

  /// Whether an `await` actually precedes [node] on its own execution path.
  ///
  /// Walks the ancestor chain from [node] up to the scanned function body and
  /// only counts `await`s that sequentially execute before the suspect node:
  /// earlier statements within an enclosing block, or — when the node sits
  /// inside a `catch`/`finally` — the `try` body. Awaits in mutually exclusive
  /// sibling branches (`if`/`else`, separate `switch` cases) are NOT counted,
  /// which removes the false positives the flat-offset scan produced.
  bool _hasPriorAsyncGap(AstNode node) {
    AstNode child = node;
    AstNode? parent = child.parent;
    while (parent != null) {
      if (identical(child, _scannedBody)) break;

      if (parent is Block) {
        for (final statement in parent.statements) {
          if (identical(statement, child)) break;
          if (_subtreeHasAwait(statement)) return true;
        }
      } else if (parent is TryStatement && !identical(child, parent.body)) {
        // The node lives in a catch clause or finally block, both of which
        // execute after the try body (including after an await that threw).
        if (_subtreeHasAwait(parent.body)) return true;
      }

      child = parent;
      parent = child.parent;
    }
    return false;
  }

  /// Whether [node]'s subtree contains an `await`, without descending into
  /// nested function bodies (their awaits do not sequentially precede code in
  /// the enclosing scope).
  bool _subtreeHasAwait(AstNode node) {
    final finder = _AwaitFinder();
    node.accept(finder);
    return finder.found;
  }

  bool _shouldReport(AstNode node) {
    // `state = await expr` — the store runs after the await. A preceding
    // `ref.mounted` guard cannot protect the write mid-expression, so RHS
    // await is always an unguardable gap for state assignments.
    final hasRhsAwait =
        node is AssignmentExpression && _subtreeHasAwait(node.rightHandSide);
    if (!_hasInheritedAsyncGap && !hasRhsAwait && !_hasPriorAsyncGap(node)) {
      return false;
    }
    if (!hasRhsAwait && _isDisposalGuarded(node)) return false;

    return _reportedRefCallOffsets.add(node.offset);
  }

  /// Whether [node] is dominated by a `ref.mounted` disposal guard that no
  /// later `await` has invalidated.
  ///
  /// Recognises both the early-return form and the positive wrapper:
  ///
  /// ```dart
  /// await save();
  /// if (!ref.mounted) return;   // early return
  /// ref.invalidate(p);          // guarded
  /// state = next;               // also guarded
  ///
  /// await save();
  /// if (ref.mounted) {          // positive wrapper
  ///   ref.invalidate(p);        // guarded
  ///   state = next;             // guarded
  /// }
  /// ```
  ///
  /// A guard only protects the code that runs before the next async gap, so an
  /// `await` between the guard and [node] makes the guard stale:
  ///
  /// ```dart
  /// if (!ref.mounted) return;
  /// await save();
  /// ref.invalidate(p);          // still reported
  /// state = next;               // still reported
  /// ```
  bool _isDisposalGuarded(AstNode node) {
    AstNode child = node;
    AstNode? parent = child.parent;
    while (parent != null) {
      if (identical(child, _scannedBody)) break;

      if (parent is Block) {
        var guarded = false;
        var awaitAfterGuard = false;
        for (final statement in parent.statements) {
          if (identical(statement, child)) break;
          if (_isRefMountedEarlyReturnGuard(statement)) {
            guarded = true;
            awaitAfterGuard = false;
          } else if (_subtreeHasAwait(statement)) {
            guarded = false;
            awaitAfterGuard = true;
          }
        }
        if (guarded) return true;
        // An await at this level runs after any guard in an enclosing scope,
        // so no outer guard can still be protecting the suspect node.
        if (awaitAfterGuard) return false;
      } else if (parent is IfStatement) {
        // `if (ref.mounted) { <node> }`
        if (identical(child, parent.thenStatement) &&
            _isRefMountedCheck(parent.expression, negated: false)) {
          return true;
        }
        // `if (!ref.mounted) return; else { <node> }` — the else branch is
        // only reachable while mounted.
        if (identical(child, parent.elseStatement) &&
            _isRefMountedEarlyReturnGuard(parent)) {
          return true;
        }
      } else if (parent is TryStatement && !identical(child, parent.body)) {
        // The node is in a catch clause or finally block, which run after
        // the try body — including after an await in it that threw. Any guard
        // outside the try is therefore stale.
        if (_subtreeHasAwait(parent.body)) return false;
      } else if (_awaitingLoopBody(parent, child)) {
        // On the second and later iterations the loop body's own await has
        // already run, so a guard outside the loop no longer holds.
        return false;
      }

      child = parent;
      parent = child.parent;
    }

    return false;
  }

  /// Whether [child] is the body of a loop whose body contains an `await`.
  ///
  /// A guard placed outside such a loop only covers the first iteration: every
  /// later iteration re-enters the body after the previous iteration's await.
  bool _awaitingLoopBody(AstNode parent, AstNode child) {
    final Statement? body = switch (parent) {
      WhileStatement() => parent.body,
      DoStatement() => parent.body,
      ForStatement() => parent.body,
      _ => null,
    };
    if (body == null || !identical(child, body)) return false;

    return _subtreeHasAwait(body);
  }

  /// Whether [statement] is `if (!ref.mounted) <exit>;` — a guard whose then
  /// branch always leaves the current execution path.
  bool _isRefMountedEarlyReturnGuard(Statement statement) {
    if (statement is! IfStatement) return false;
    if (!_isRefMountedCheck(statement.expression, negated: true)) return false;

    return _alwaysExits(statement.thenStatement);
  }

  bool _alwaysExits(Statement statement) {
    if (statement is ReturnStatement) return true;
    if (statement is ExpressionStatement) {
      return statement.expression is ThrowExpression;
    }
    if (statement is Block) {
      final statements = statement.statements;
      if (statements.isEmpty) return false;
      return _alwaysExits(statements.last);
    }

    return false;
  }

  /// Whether [expression] is `ref.mounted` (when [negated] is false) or
  /// `!ref.mounted` (when [negated] is true).
  bool _isRefMountedCheck(Expression expression, {required bool negated}) {
    if (negated) {
      return expression is PrefixExpression &&
          expression.operator.lexeme == '!' &&
          _isRefMountedAccess(expression.operand);
    }

    return _isRefMountedAccess(expression);
  }

  bool _isRefMountedAccess(Expression expression) {
    if (expression is PrefixedIdentifier) {
      return expression.prefix.name == 'ref' &&
          expression.identifier.name == 'mounted';
    }
    if (expression is PropertyAccess) {
      return expression.propertyName.name == 'mounted' &&
          _isRefTarget(expression.target);
    }

    return false;
  }

  void _scanLocalFunctionInvocation(MethodInvocation invocation) {
    if (invocation.target != null) return;
    if (!_hasInheritedAsyncGap && !_hasPriorAsyncGap(invocation)) return;

    final functionName = invocation.methodName.name;
    final declaration = _localFunctions[functionName];
    if (declaration == null) return;

    final body = declaration.functionExpression.body;
    if (body.isAsynchronous) return;
    if (!_activeLocalFunctionNames.add(functionName)) return;

    try {
      _AsyncRefAfterGapScanner(
        rule,
        tracking: _tracking,
        hasInheritedAsyncGap: true,
        localFunctions: _localFunctions,
        activeLocalFunctionNames: _activeLocalFunctionNames,
        reportedRefCallOffsets: _reportedRefCallOffsets,
      ).scan(body);
    } finally {
      _activeLocalFunctionNames.remove(functionName);
    }
  }

  void _reportRefCall(MethodInvocation refCall) {
    final methodName = refCall.methodName.name;
    rule.reportAtNode(
      refCall,
      arguments: [
        'Avoid ref.$methodName() after an async gap in Riverpod providers.',
        'Capture provider/usecase dependencies before the async gap, or guard the post-gap access with "if (!ref.mounted) return;".',
      ],
    );
  }

  void _reportStateAssignment(AssignmentExpression assignment) {
    rule.reportAtNode(
      assignment,
      arguments: [
        'Avoid assigning to state after an async gap in Riverpod providers (Riverpod 3 throws UnmountedRefException once the provider is disposed).',
        'Guard right after the await ("await …; if (!ref.mounted) return;"), or await into a local first: "final next = await …; if (!ref.mounted) return; state = next;".',
      ],
    );
  }

  void _reportStateRead(SimpleIdentifier read) {
    rule.reportAtNode(
      read,
      arguments: [
        'Avoid reading state after an async gap in Riverpod providers (the state getter throws UnmountedRefException once the provider is disposed).',
        'Guard right after the await ("await …; if (!ref.mounted) return;"), or capture the needed state values before the await.',
      ],
    );
  }
}

/// Detects an `await` within a subtree, stopping at nested function boundaries.
class _AwaitFinder extends RecursiveAstVisitor<void> {
  bool found = false;

  @override
  void visitAwaitExpression(AwaitExpression node) {
    found = true;
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    // Nested closures are a separate execution scope; their awaits do not
    // sequentially precede code in the enclosing scope.
  }

  @override
  void visitFunctionDeclarationStatement(FunctionDeclarationStatement node) {
    // Local function declarations are likewise a separate scope.
  }
}
