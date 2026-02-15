import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../clean_architecture_linter_base.dart';

class PresentationNoThrowRule extends CleanArchitectureLintRule {
  const PresentationNoThrowRule() : super(code: _code);

  static const _code = LintCode(
    name: 'presentation_no_throw',
    problemMessage:
        'Presentation States/Notifiers should NOT throw exceptions. Use state management instead.',
    correctionMessage:
        'Use AsyncValue.guard()/when(error) or AsyncValue.error instead of throwing.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runRule(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addThrowExpression((node) {
      _checkThrowInPresentation(node, reporter, resolver);
    });

    context.registry.addCatchClause((node) {
      _checkBusinessExceptionBranchingInWidget(node, reporter, resolver);
    });
  }

  void _checkThrowInPresentation(
    ThrowExpression node,
    DiagnosticReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;

    if (!CleanArchitectureUtils.isPresentationFile(filePath)) return;

    if (!filePath.contains('/states/') &&
        !filePath.contains('/state/') &&
        !filePath.contains('/providers/')) {
      return;
    }

    final classNode = CleanArchitectureUtils.findParentClass(node);
    if (classNode == null) return;

    final className = classNode.name.lexeme;
    if (!_isStateOrNotifierClass(className, classNode)) return;

    final methodNode = _findParentMethod(node);
    if (methodNode == null) return;

    if (CleanArchitectureUtils.isPrivateMethod(methodNode)) return;
    if (methodNode.parent is ConstructorDeclaration) return;
    if (_isThrowingProgrammingError(node)) return;
    if (_isRethrow(node)) return;
    if (_isInsideAsyncValueGuard(node)) return;

    final exceptionType = _getExceptionType(node);

    final code = LintCode(
      name: 'presentation_no_throw',
      problemMessage:
          '"$className.${methodNode.name.lexeme}" should not throw $exceptionType.',
      correctionMessage:
          'AsyncValue.guard()/when(error) 패턴으로 에러를 UI 상태로 표현하세요.',
      errorSeverity: DiagnosticSeverity.WARNING,
    );

    reporter.atNode(node, code);
  }

  void _checkBusinessExceptionBranchingInWidget(
    CatchClause catchClause,
    DiagnosticReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    if (!CleanArchitectureUtils.isPresentationFile(filePath)) return;

    final classNode = catchClause.thisOrAncestorOfType<ClassDeclaration>();
    if (classNode == null || !_isWidgetClass(classNode)) return;

    final exceptionType = catchClause.exceptionType?.toSource();
    if (exceptionType == null || exceptionType.isEmpty) return;

    if (_isProgrammingErrorType(exceptionType)) return;

    if (!_looksLikeBusinessException(exceptionType)) return;

    final code = LintCode(
      name: 'presentation_no_throw',
      problemMessage:
          'Widget/Presentation에서 비즈니스 예외($exceptionType)를 try-catch로 직접 분기하지 마세요.',
      correctionMessage:
          'Provider에서 AsyncValue.guard()로 처리하고 UI에서는 when(error)로 렌더링하세요.',
      errorSeverity: DiagnosticSeverity.WARNING,
    );

    reporter.atNode(catchClause, code);
  }

  bool _isStateOrNotifierClass(String className, ClassDeclaration classNode) {
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
    var current = node.parent;
    while (current != null) {
      if (current is MethodDeclaration) return current;
      if (current is ConstructorDeclaration) return null;
      current = current.parent;
    }
    return null;
  }

  bool _isThrowingProgrammingError(ThrowExpression node) {
    final expression = node.expression;

    if (expression is InstanceCreationExpression) {
      final typeName = expression.constructorName.type.name.lexeme;
      const programmingErrors = [
        'ArgumentError',
        'AssertionError',
        'StateError',
        'UnimplementedError',
        'UnsupportedError',
        'TypeError',
        'RangeError',
      ];

      return programmingErrors.contains(typeName);
    }

    return false;
  }

  bool _isRethrow(ThrowExpression node) {
    return node.expression is RethrowExpression ||
        node.expression.toSource() == 'rethrow';
  }

  bool _isInsideAsyncValueGuard(ThrowExpression node) {
    AstNode? current = node;
    while (current != null) {
      if (current is MethodInvocation) {
        final methodName = current.methodName.name;
        final targetSource = current.target?.toSource() ?? '';
        if (methodName == 'guard' && targetSource.contains('AsyncValue')) {
          return true;
        }
      }
      current = current.parent;
    }
    return false;
  }

  String _getExceptionType(ThrowExpression node) {
    final expression = node.expression;

    if (expression is InstanceCreationExpression) {
      return expression.constructorName.type.name.lexeme;
    }

    if (expression is SimpleIdentifier) {
      return 'exception (variable)';
    }

    if (expression is RethrowExpression || expression.toString() == 'rethrow') {
      return 'rethrow';
    }

    return 'exception';
  }

  bool _isWidgetClass(ClassDeclaration classNode) {
    final className = classNode.name.lexeme;
    if (className.endsWith('Page') ||
        className.endsWith('Screen') ||
        className.endsWith('View') ||
        className.endsWith('Widget')) {
      return true;
    }

    final extendsClause = classNode.extendsClause;
    if (extendsClause == null) return false;

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
