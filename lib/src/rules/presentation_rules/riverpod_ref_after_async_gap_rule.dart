import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../../clean_architecture_linter_base.dart';
import '../../compat/analyzer_ast_compat.dart';

const _trackedRefMethods = {'read', 'watch', 'listen', 'invalidate', 'refresh'};

/// Reports Riverpod `ref` usage after an async gap in provider classes.
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
            'Advises against using Riverpod ref after await in provider classes.',
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
      _RiverpodRefAfterAsyncGapVisitor(this, context),
    );
  }
}

class _RiverpodRefAfterAsyncGapVisitor extends SimpleAstVisitor<void> {
  _RiverpodRefAfterAsyncGapVisitor(this.rule, this.context);

  final AnalysisRule rule;
  final RuleContext context;

  String get _filePath =>
      context.currentUnit?.file.path ?? context.definingUnit.file.path;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    if (!_shouldCheckFile(_filePath)) return;
    if (!_isRiverpodProviderClass(node)) return;

    for (final member in classMembers(node)) {
      if (member is! MethodDeclaration) continue;
      if (_isPrivate(member.name.lexeme)) continue;

      if (member.body.isAsynchronous) {
        _AsyncRefAfterGapScanner(rule).scan(member.body);
      }

      member.body.accept(_AsyncCallbackScanner(rule));
    }
  }

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

    final superclassName = extendsClause.superclass.name.lexeme;
    return superclassName.startsWith('_\$');
  }

  bool _isPrivate(String name) => name.startsWith('_');
}

class _AsyncCallbackScanner extends RecursiveAstVisitor<void> {
  _AsyncCallbackScanner(this.rule);

  final AnalysisRule rule;

  @override
  void visitFunctionExpression(FunctionExpression node) {
    if (node.body.isAsynchronous) {
      _AsyncRefAfterGapScanner(rule).scan(node.body);
    }

    super.visitFunctionExpression(node);
  }
}

class _AsyncRefAfterGapScanner extends RecursiveAstVisitor<void> {
  _AsyncRefAfterGapScanner(
    this.rule, {
    bool hasInheritedAsyncGap = false,
    Map<String, FunctionDeclaration>? localFunctions,
    Set<String>? activeLocalFunctionNames,
    Set<int>? reportedRefCallOffsets,
  }) : _hasInheritedAsyncGap = hasInheritedAsyncGap,
       _localFunctions = localFunctions ?? {},
       _activeLocalFunctionNames = activeLocalFunctionNames ?? {},
       _reportedRefCallOffsets = reportedRefCallOffsets ?? {};

  final AnalysisRule rule;
  final bool _hasInheritedAsyncGap;
  final Map<String, FunctionDeclaration> _localFunctions;
  final Set<String> _activeLocalFunctionNames;
  final Set<int> _reportedRefCallOffsets;
  final List<MethodInvocation> _refCalls = [];
  FunctionBody? _scannedBody;

  void scan(FunctionBody body) {
    _scannedBody = body;
    body.accept(this);

    for (final refCall in _refCalls) {
      if (_shouldReport(refCall)) {
        _report(refCall);
      }
    }
  }

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

  bool _isRefTarget(Expression? target) {
    if (target is SimpleIdentifier) return target.name == 'ref';

    return target is PropertyAccess &&
        target.target is ThisExpression &&
        target.propertyName.name == 'ref';
  }

  /// Whether an `await` actually precedes [refCall] on its own execution path.
  ///
  /// Walks the ancestor chain from [refCall] up to the scanned function body and
  /// only counts `await`s that sequentially execute before the ref call:
  /// earlier statements within an enclosing block/switch member, earlier
  /// arguments in the same invocation, or control-flow header expressions that
  /// execute before the selected body. Awaits in mutually exclusive sibling
  /// branches (`if`/`else`, separate `switch` cases) are NOT counted, which
  /// removes the false positives the flat-offset scan produced.
  bool _hasPriorAsyncGap(AstNode refCall) {
    AstNode child = refCall;
    AstNode? parent = child.parent;
    while (parent != null) {
      if (identical(child, _scannedBody)) break;

      if (_hasAwaitBeforeChild(parent, child)) return true;

      child = parent;
      parent = child.parent;
    }
    return false;
  }

  bool _hasAwaitBeforeChild(AstNode parent, AstNode child) {
    if (parent is Block) {
      return _earlierNodesHaveAwait(parent.statements, child);
    }

    if (parent is SwitchMember) {
      return _earlierNodesHaveAwait(parent.statements, child);
    }

    if (parent is ArgumentList) {
      return _earlierNodesHaveAwait(parent.arguments, child);
    }

    if (parent is TryStatement) {
      return _tryHasAwaitBeforeChild(parent, child);
    }

    if (parent is IfStatement &&
        (identical(child, parent.thenStatement) ||
            identical(child, parent.elseStatement))) {
      return _subtreeHasAwait(parent.expression) ||
          _subtreeHasAwaitInNullable(parent.caseClause);
    }

    if (parent is WhileStatement && identical(child, parent.body)) {
      return _subtreeHasAwait(parent.condition);
    }

    if (parent is SwitchStatement && parent.members.contains(child)) {
      return _subtreeHasAwait(parent.expression);
    }

    if (parent is ConditionalExpression &&
        (identical(child, parent.thenExpression) ||
            identical(child, parent.elseExpression))) {
      return _subtreeHasAwait(parent.condition);
    }

    return false;
  }

  bool _tryHasAwaitBeforeChild(TryStatement parent, AstNode child) {
    if (identical(child, parent.body)) return false;

    // Catch clauses and finally run after the try body, including after an
    // awaited expression that throws.
    if (_subtreeHasAwait(parent.body)) return true;

    if (identical(child, parent.finallyBlock)) {
      for (final catchClause in parent.catchClauses) {
        if (_subtreeHasAwait(catchClause)) return true;
      }
    }

    return false;
  }

  bool _earlierNodesHaveAwait(Iterable<AstNode> nodes, AstNode child) {
    for (final node in nodes) {
      if (identical(node, child)) return false;
      if (_subtreeHasAwait(node)) return true;
    }

    return false;
  }

  bool _subtreeHasAwaitInNullable(AstNode? node) {
    if (node == null) return false;
    return _subtreeHasAwait(node);
  }

  /// Whether [node]'s subtree contains an `await`, without descending into
  /// nested function bodies (their awaits do not sequentially precede code in
  /// the enclosing scope).
  bool _subtreeHasAwait(AstNode node) {
    final finder = _AwaitFinder();
    node.accept(finder);
    return finder.found;
  }

  bool _shouldReport(MethodInvocation refCall) {
    if (!_hasInheritedAsyncGap && !_hasPriorAsyncGap(refCall)) return false;

    return _reportedRefCallOffsets.add(refCall.offset);
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
        hasInheritedAsyncGap: true,
        localFunctions: _localFunctions,
        activeLocalFunctionNames: _activeLocalFunctionNames,
        reportedRefCallOffsets: _reportedRefCallOffsets,
      ).scan(body);
    } finally {
      _activeLocalFunctionNames.remove(functionName);
    }
  }

  void _report(MethodInvocation refCall) {
    final methodName = refCall.methodName.name;
    rule.reportAtNode(
      refCall,
      arguments: [
        'Avoid ref.$methodName() after an async gap in Riverpod providers.',
        'Capture provider/usecase dependencies before await, or restructure the async flow so ref is not used after await.',
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
