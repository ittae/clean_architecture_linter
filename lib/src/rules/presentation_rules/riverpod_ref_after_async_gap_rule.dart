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
  _AsyncRefAfterGapScanner(this.rule);

  final AnalysisRule rule;
  final List<int> _awaitEnds = [];
  final List<MethodInvocation> _refCalls = [];

  void scan(FunctionBody body) {
    body.accept(this);

    for (final refCall in _refCalls) {
      if (_hasPriorAsyncGap(refCall)) {
        _report(refCall);
      }
    }
  }

  @override
  void visitAwaitExpression(AwaitExpression node) {
    _awaitEnds.add(node.end);
    super.visitAwaitExpression(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    // Local functions have their own lifecycle boundary.
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

    super.visitMethodInvocation(node);
  }

  bool _isRefTarget(Expression? target) {
    if (target is SimpleIdentifier) return target.name == 'ref';

    return target is PropertyAccess &&
        target.target is ThisExpression &&
        target.propertyName.name == 'ref';
  }

  bool _hasPriorAsyncGap(MethodInvocation refCall) {
    return _awaitEnds.any((awaitEnd) => awaitEnd <= refCall.offset);
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
