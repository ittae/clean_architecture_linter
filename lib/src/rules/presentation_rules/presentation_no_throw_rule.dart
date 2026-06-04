import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../../compat/analyzer_ast_compat.dart';

/// Prevents business exception throws from presentation state management code.
///
/// The throw-expression check intentionally mirrors the v1 custom-lint rule:
/// it only runs in `lib` state/provider presentation files, including both
/// `presentation/{states,state,providers}` and feature-level `{states,state,
/// providers}` layouts, and skips programming errors, rethrows, constructors,
/// private helper methods, and `AsyncValue.guard` bodies. Widget
/// catch-branching remains scoped to presentation widgets.
class PresentationNoThrowRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'presentation_no_throw',
    'Presentation layer should not throw exceptions directly.',
    correctionMessage:
        'Return AsyncValue.error or wrap the body with AsyncValue.guard instead.',
    severity: DiagnosticSeverity.WARNING,
    uniqueName: 'LintCode.presentation_no_throw',
  );

  PresentationNoThrowRule()
    : super(
        name: 'presentation_no_throw',
        description: 'Prevents direct throw expressions in presentation code.',
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
    final visitor = _PresentationNoThrowVisitor(this, context);
    registry.addThrowExpression(this, visitor);
    registry.addCatchClause(this, visitor);
  }
}

class _PresentationNoThrowVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;
  final RuleContext context;

  _PresentationNoThrowVisitor(this.rule, this.context);

  @override
  void visitThrowExpression(ThrowExpression node) {
    if (!_isCurrentPresentationStateUnit()) {
      return;
    }

    final classNode = node.thisOrAncestorOfType<ClassDeclaration>();
    if (classNode == null || !_isStateOrNotifierClass(classNode)) {
      return;
    }

    final methodNode = _findParentMethod(node);
    if (methodNode == null || _isPrivateMethod(methodNode)) {
      return;
    }

    if (_isThrowingProgrammingError(node) || _isRethrow(node)) {
      return;
    }

    if (_isInsideAsyncValueGuard(node)) {
      return;
    }

    rule.reportAtNode(node);
  }

  @override
  void visitCatchClause(CatchClause node) {
    if (!_isCurrentPresentationUnit()) {
      return;
    }

    final classNode = node.thisOrAncestorOfType<ClassDeclaration>();
    if (classNode == null || !_isWidgetClass(classNode)) {
      return;
    }

    final exceptionType = node.exceptionType?.toSource();
    if (exceptionType == null || exceptionType.isEmpty) {
      return;
    }

    if (_isProgrammingErrorType(exceptionType)) {
      return;
    }

    if (!_looksLikeBusinessException(exceptionType)) {
      return;
    }

    rule.reportAtNode(node);
  }

  bool _isCurrentPresentationUnit() {
    final path =
        context.currentUnit?.file.path ?? context.definingUnit.file.path;
    return isPresentationLibPath(path);
  }

  bool _isCurrentPresentationStateUnit() {
    final path =
        context.currentUnit?.file.path ?? context.definingUnit.file.path;
    return isPresentationStateManagementPath(path);
  }

  bool _isStateOrNotifierClass(ClassDeclaration classNode) {
    final className = classDeclarationName(classNode) ?? '';

    for (final metadata in classNode.metadata) {
      final name = metadata.name.name;
      if (name == 'riverpod' || name == 'Riverpod') {
        return true;
      }
    }

    final extendsClause = classNode.extendsClause;
    if (extendsClause != null) {
      final superclass = extendsClause.superclass.name.lexeme;
      if (superclass == 'AsyncNotifier' ||
          superclass == 'Notifier' ||
          superclass == 'StateNotifier' ||
          superclass == 'ChangeNotifier' ||
          superclass.startsWith('_\$')) {
        return true;
      }
    }

    return className.contains('Notifier') ||
        className.contains('State') ||
        className.contains('Provider') ||
        className.contains('Bloc') ||
        className.contains('Cubit') ||
        className.contains('Controller') ||
        className.contains('ViewModel');
  }

  MethodDeclaration? _findParentMethod(ThrowExpression node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is MethodDeclaration) {
        return current;
      }
      if (current is ConstructorDeclaration) {
        return null;
      }
      current = current.parent;
    }
    return null;
  }

  bool _isPrivateMethod(MethodDeclaration method) {
    return method.name.lexeme.startsWith('_');
  }

  bool _isThrowingProgrammingError(ThrowExpression node) {
    final expression = node.expression;
    if (expression is! InstanceCreationExpression) {
      return false;
    }

    final typeName = expression.constructorName.type.name.lexeme;
    return _isProgrammingErrorType(typeName);
  }

  bool _isRethrow(ThrowExpression node) {
    return node.expression is RethrowExpression ||
        node.expression.toSource() == 'rethrow';
  }

  bool _isInsideAsyncValueGuard(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is MethodInvocation &&
          current.methodName.name == 'guard' &&
          _isAsyncValueTarget(current.target)) {
        return true;
      }
      current = current.parent;
    }
    return false;
  }

  bool _isAsyncValueTarget(Expression? target) {
    if (target is SimpleIdentifier) {
      return target.name == 'AsyncValue';
    }

    if (target is PrefixedIdentifier) {
      return target.identifier.name == 'AsyncValue';
    }

    return target?.toSource().split('.').contains('AsyncValue') ?? false;
  }

  bool _isWidgetClass(ClassDeclaration classNode) {
    final className = classDeclarationName(classNode) ?? '';
    if (className.endsWith('Page') ||
        className.endsWith('Screen') ||
        className.endsWith('View') ||
        className.endsWith('Widget')) {
      return true;
    }

    final extendsClause = classNode.extendsClause;
    if (extendsClause == null) {
      return false;
    }

    final superName = extendsClause.superclass.name.lexeme;
    return superName == 'StatelessWidget' ||
        superName == 'StatefulWidget' ||
        superName == 'ConsumerWidget' ||
        superName == 'HookConsumerWidget' ||
        superName == 'ConsumerState';
  }

  bool _isProgrammingErrorType(String typeName) {
    const programmingErrors = {
      'ArgumentError',
      'AssertionError',
      'StateError',
      'UnimplementedError',
      'UnsupportedError',
      'TypeError',
      'RangeError',
    };
    return programmingErrors.contains(typeName);
  }

  bool _looksLikeBusinessException(String typeName) {
    return typeName.endsWith('Exception') ||
        typeName.endsWith('Failure') ||
        typeName == 'AppException';
  }
}

bool isPresentationLibPath(String path) {
  final segments = path
      .replaceAll('\\', '/')
      .split('/')
      .where((segment) => segment.isNotEmpty)
      .toList(growable: false);

  final libIndex = segments.lastIndexOf('lib');
  if (libIndex == -1 || libIndex == segments.length - 1) {
    return false;
  }

  return segments.skip(libIndex + 1).contains('presentation');
}

bool isPresentationStateManagementPath(String path) {
  final segments = path
      .replaceAll('\\', '/')
      .split('/')
      .where((segment) => segment.isNotEmpty)
      .toList(growable: false);

  final libIndex = segments.lastIndexOf('lib');
  if (libIndex == -1 || libIndex == segments.length - 1) {
    return false;
  }

  final libSegments = segments.skip(libIndex + 1).toList(growable: false);
  if (libSegments.contains('domain') || libSegments.contains('data')) {
    return false;
  }

  return libSegments.contains('states') ||
      libSegments.contains('state') ||
      libSegments.contains('providers');
}
