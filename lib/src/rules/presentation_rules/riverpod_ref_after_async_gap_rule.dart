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
  ///
  /// Name-based match would otherwise FP on a local or parameter named `state`
  /// (same caveat as [visitAssignmentExpression]). Locals, lambda/method
  /// parameters, and catch variables named `state` are skipped. `this.state`
  /// is always the notifier getter.
  bool _isStateRead(SimpleIdentifier node) {
    if (node.name != 'state' || node.inDeclarationContext()) return false;

    final parent = node.parent;
    if (parent is Label) return false;
    if (parent is MethodInvocation && parent.methodName == node) return false;
    if (parent is AssignmentExpression && parent.leftHandSide == node) {
      return false;
    }
    if (parent is PrefixedIdentifier && parent.identifier == node) {
      return false;
    }
    if (parent is PropertyAccess && parent.propertyName == node) {
      if (parent.target is! ThisExpression) return false;
      final grandParent = parent.parent;
      if (grandParent is AssignmentExpression &&
          grandParent.leftHandSide == parent) {
        return false;
      }
    }

    if (!_isThisStateAccess(node) && _isShadowedState(node)) return false;

    return true;
  }

  bool _isThisStateAccess(SimpleIdentifier node) {
    final parent = node.parent;
    return parent is PropertyAccess &&
        parent.propertyName == node &&
        parent.target is ThisExpression;
  }

  /// Parsed-AST shadowing: a local, parameter, or catch variable named
  /// `state` is not the notifier getter. Resolution is unavailable because
  /// this rule uses parsed results.
  bool _isShadowedState(SimpleIdentifier node) {
    AstNode? current = node.parent;
    while (current != null &&
        current is! ClassDeclaration &&
        current is! ExtensionDeclaration) {
      if (current is FunctionExpression &&
          _parametersDeclareState(current.parameters)) {
        return true;
      }
      if (current is MethodDeclaration &&
          _parametersDeclareState(current.parameters)) {
        return true;
      }
      if (current is FunctionDeclaration &&
          _parametersDeclareState(current.functionExpression.parameters)) {
        return true;
      }
      if (current is CatchClause) {
        if (current.exceptionParameter?.name.lexeme == 'state') return true;
        if (current.stackTraceParameter?.name.lexeme == 'state') return true;
      }
      if (current is SwitchMember) {
        if (_statementsDeclareStateBefore(current.statements, node)) {
          return true;
        }
      }
      if (current is Block) {
        for (final statement in current.statements) {
          if (statement.offset >= node.offset) break;
          if (statement is VariableDeclarationStatement) {
            for (final variable in statement.variables.variables) {
              if (variable.name.lexeme == 'state') return true;
            }
          }
        }
      }
      if (current is ForStatement) {
        final parts = current.forLoopParts;
        if (parts is ForEachPartsWithDeclaration &&
            parts.loopVariable.name.lexeme == 'state') {
          return true;
        }
        if (parts is ForPartsWithDeclarations) {
          for (final variable in parts.variables.variables) {
            if (variable.name.lexeme == 'state' &&
                variable.offset < node.offset) {
              return true;
            }
          }
        }
      }
      current = current.parent;
    }
    return false;
  }

  /// Unbraced `case` bodies keep their statements on the [SwitchMember],
  /// not in a [Block].
  bool _statementsDeclareStateBefore(
    NodeList<Statement> statements,
    AstNode node,
  ) {
    for (final statement in statements) {
      if (statement.offset >= node.offset) break;
      if (statement is VariableDeclarationStatement) {
        for (final variable in statement.variables.variables) {
          if (variable.name.lexeme == 'state') return true;
        }
      }
    }
    return false;
  }

  bool _parametersDeclareState(FormalParameterList? parameters) {
    if (parameters == null) return false;
    for (final parameter in parameters.parameters) {
      if (formalParameterName(parameter) == 'state') return true;
    }
    return false;
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
  ///
  /// Same-statement awaits (`await foo() ?? state`) are handled separately by
  /// [_hasExpressionPriorAwait] so the default-on ref rule stays unchanged.
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
      } else if (_tracking.stateReads &&
          _bodyFollowsControlAwait(parent, child)) {
        // `if (await check()) { use(state); }`, `while (await more()) {…}`,
        // `for (final x in await list()) {…}` — the body runs after the
        // control expression's await. A `ref.mounted` guard inside the body
        // still applies (checked by _isDisposalGuarded). Opt-in rule only, so
        // the default-on ref rule's output is unchanged.
        return true;
      }

      child = parent;
      parent = child.parent;
    }
    return false;
  }

  /// Whether an `await` evaluates before [node] in the same expression.
  ///
  /// Dart evaluates left-to-right. `await foo() ?? state` and
  /// `use(await foo(), state)` read `state` after the gap; `state.foo(await x)`
  /// and `await foo(state)` evaluate `state` first and must not report.
  /// Nested function bodies are ignored by [_subtreeHasAwait].
  bool _hasExpressionPriorAwait(AstNode node) {
    AstNode child = node;
    AstNode? parent = child.parent;
    while (parent != null) {
      if (identical(child, _scannedBody)) break;
      // Statement boundary: `if (await …) { … }` is a prior-gap question
      // for _hasPriorAsyncGap (which respects a `ref.mounted` guard), not a
      // same-expression one.
      if (parent is FunctionBody || parent is Statement) break;
      if (_priorEvalSiblingsHaveAwait(parent, child)) return true;
      child = parent;
      parent = child.parent;
    }
    return false;
  }

  bool _priorEvalSiblingsHaveAwait(AstNode parent, AstNode child) {
    for (final predecessor in _evalPredecessors(parent, child)) {
      if (_subtreeHasAwait(predecessor)) return true;
    }
    return false;
  }

  List<AstNode> _evalPredecessors(AstNode parent, AstNode child) {
    if (parent is BinaryExpression) {
      if (identical(child, parent.rightOperand)) return [parent.leftOperand];
      return const [];
    }
    if (parent is AssignmentExpression) {
      // Dart evaluates the assignment target (receiver/index) before the
      // right-hand side: `items[state.i] = await f()` reads `state` first,
      // while `(await g()).value = state` reads it after the gap.
      if (identical(child, parent.rightHandSide)) {
        return [parent.leftHandSide];
      }
      return const [];
    }
    if (parent is ConditionalExpression) {
      if (identical(child, parent.thenExpression) ||
          identical(child, parent.elseExpression)) {
        return [parent.condition];
      }
      return const [];
    }
    if (parent is ArgumentList) {
      return _priorNodes(parent.arguments, child);
    }
    if (parent is MethodInvocation) {
      final target = parent.target;
      if (target != null && !identical(child, target)) return [target];
      return const [];
    }
    if (parent is FunctionExpressionInvocation) {
      if (!identical(child, parent.function)) return [parent.function];
      return const [];
    }
    if (parent is PropertyAccess) {
      final target = parent.target;
      if (target != null && identical(child, parent.propertyName)) {
        return [target];
      }
      return const [];
    }
    if (parent is PrefixedIdentifier) {
      if (identical(child, parent.identifier)) return [parent.prefix];
      return const [];
    }
    if (parent is IndexExpression) {
      final target = parent.target;
      if (target != null && identical(child, parent.index)) return [target];
      return const [];
    }
    if (parent is CascadeExpression) {
      if (identical(child, parent.target)) return const [];
      return [parent.target, ..._priorNodes(parent.cascadeSections, child)];
    }
    if (parent is ListLiteral) {
      return _priorNodes(parent.elements, child);
    }
    if (parent is SetOrMapLiteral) {
      return _priorNodes(parent.elements, child);
    }
    if (parent is StringInterpolation) {
      return _priorNodes(parent.elements, child);
    }
    return const [];
  }

  List<AstNode> _priorNodes(NodeList<AstNode> nodes, AstNode child) {
    final prior = <AstNode>[];
    for (final node in nodes) {
      if (identical(node, child)) break;
      prior.add(node);
    }
    return prior;
  }

  /// Whether [node]'s subtree contains an `await`, without descending into
  /// nested function bodies (their awaits do not sequentially precede code in
  /// the enclosing scope).
  /// Whether [child] is a branch/loop body whose control expression(s) in
  /// [parent] contain an `await` that runs before the body.
  bool _bodyFollowsControlAwait(AstNode parent, AstNode child) {
    if (parent is IfStatement) {
      return !identical(child, parent.expression) &&
          _subtreeHasAwait(parent.expression);
    }
    if (parent is WhileStatement) {
      return identical(child, parent.body) &&
          _subtreeHasAwait(parent.condition);
    }
    if (parent is DoStatement) {
      // The body re-runs after the condition from the second iteration on.
      return identical(child, parent.body) &&
          _subtreeHasAwait(parent.condition);
    }
    if (parent is ForStatement) {
      if (!identical(child, parent.body)) return false;
      final parts = parent.forLoopParts;
      if (parts is ForEachParts) return _subtreeHasAwait(parts.iterable);
      if (parts is ForParts) {
        final condition = parts.condition;
        if (condition != null && _subtreeHasAwait(condition)) return true;
        if (parts is ForPartsWithDeclarations &&
            _subtreeHasAwait(parts.variables)) {
          return true;
        }
        if (parts is ForPartsWithExpression) {
          final initialization = parts.initialization;
          if (initialization != null && _subtreeHasAwait(initialization)) {
            return true;
          }
        }
        return parts.updaters.any(_subtreeHasAwait);
      }
    }
    return false;
  }

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
    // Same-statement reads: `await foo() ?? state` is a gap; the default-on
    // ref rule does not use this path, so its diagnostics stay unchanged.
    final hasExpressionPriorAwait =
        _tracking.stateReads &&
        node is SimpleIdentifier &&
        _hasExpressionPriorAwait(node);
    if (!_hasInheritedAsyncGap &&
        !hasRhsAwait &&
        !hasExpressionPriorAwait &&
        !_hasPriorAsyncGap(node)) {
      return false;
    }
    // A preceding `ref.mounted` guard cannot protect a getter that runs
    // after an await in the same expression (`await foo() ?? state`).
    if (!hasRhsAwait && !hasExpressionPriorAwait && _isDisposalGuarded(node)) {
      return false;
    }

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
