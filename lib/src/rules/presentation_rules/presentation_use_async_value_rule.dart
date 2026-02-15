import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../clean_architecture_linter_base.dart';

class PresentationUseAsyncValueRule extends CleanArchitectureLintRule {
  const PresentationUseAsyncValueRule() : super(code: _code);

  static const _code = LintCode(
    name: 'presentation_use_async_value',
    problemMessage:
        'State should NOT store error/loading fields. Use AsyncValue instead.',
    correctionMessage:
        'Remove this field. Use AsyncNotifier with AsyncValue.when() pattern. AsyncValue automatically manages loading/error/data states.',
  );

  static const errorFieldNames = {
    'error',
    'errorMessage',
    'errorMsg',
    'errorText',
    'errorDescription',
    'failure',
    'failureMessage',
    'exception',
    'exceptionMessage',
  };

  static const loadingFieldNames = {
    'isLoading',
    'loading',
    'isSubmitting',
    'submitting',
    'isFetching',
    'fetching',
    'isProcessing',
    'processing',
  };

  @override
  void runRule(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((node) {
      _checkStateClass(node, reporter, resolver);
    });

    context.registry.addCatchClause((node) {
      _checkSwallowedExceptionInNotifier(node, reporter, resolver);
    });
  }

  void _checkStateClass(
    ClassDeclaration node,
    DiagnosticReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    if (!CleanArchitectureUtils.isPresentationFile(filePath)) return;
    if (!_isFreezedState(node)) return;

    _checkForErrorFields(node, reporter);
  }

  void _checkSwallowedExceptionInNotifier(
    CatchClause catchClause,
    DiagnosticReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    if (!CleanArchitectureUtils.isPresentationFile(filePath)) return;

    final classNode = catchClause.thisOrAncestorOfType<ClassDeclaration>();
    if (classNode == null || !_isNotifierOrProviderClass(classNode)) return;

    // Allowed: catch + rethrow (pass-through)
    if (catchClause.body.toSource().contains('rethrow')) return;

    // If catch doesn't map to AsyncValue state, consider it swallowed.
    if (!_containsAsyncValueErrorHandling(catchClause.body)) {
      final code = LintCode(
        name: 'presentation_use_async_value',
        problemMessage: 'Notifier/Provider catch did not map exception to UI state.',
        correctionMessage:
            'Use AsyncValue.guard(), state = AsyncValue.error(...), or UI handling via when(error: ...).',
        errorSeverity: DiagnosticSeverity.WARNING,
      );
      reporter.atNode(catchClause, code);
    }
  }

  bool _isFreezedState(ClassDeclaration node) {
    for (final metadata in node.metadata) {
      final name = metadata.name.name;
      if (name == 'freezed' || name == 'Freezed') {
        return true;
      }
    }
    return false;
  }

  bool _isNotifierOrProviderClass(ClassDeclaration node) {
    final className = node.name.lexeme;
    if (className.contains('Notifier') || className.contains('Provider')) {
      return true;
    }

    for (final metadata in node.metadata) {
      final name = metadata.name.name;
      if (name == 'riverpod' || name == 'Riverpod') {
        return true;
      }
    }

    final extendsClause = node.extendsClause;
    if (extendsClause != null) {
      final superName = extendsClause.superclass.name.lexeme;
      if (superName.contains('Notifier') ||
          superName.contains('Provider') ||
          superName.startsWith('_\$')) {
        return true;
      }
    }

    return false;
  }

  bool _containsAsyncValueErrorHandling(Block block) {
    final source = block.toSource();

    return source.contains('AsyncValue.guard(') ||
        source.contains('AsyncValue.error(') ||
        source.contains('AsyncError(') ||
        source.contains('when(error:') ||
        source.contains('state = AsyncValue');
  }

  void _checkForErrorFields(
    ClassDeclaration node,
    DiagnosticReporter reporter,
  ) {
    for (final member in node.members) {
      if (member is FieldDeclaration) {
        for (final variable in member.fields.variables) {
          final fieldName = variable.name.lexeme;
          final fieldNameLower = fieldName.toLowerCase();

          if (_isErrorField(fieldNameLower)) {
            final code = LintCode(
              name: 'presentation_use_async_value',
              problemMessage:
                  'State should NOT have error field "$fieldName". Use AsyncValue instead.',
              correctionMessage:
                  'Remove error field. Use AsyncNotifier with AsyncValue.when() pattern. AsyncValue automatically manages error states.',
            );
            reporter.atNode(variable, code);
          }

          if (_isLoadingField(fieldNameLower)) {
            final code = LintCode(
              name: 'presentation_use_async_value',
              problemMessage:
                  'State should NOT have loading field "$fieldName". Use AsyncValue instead.',
              correctionMessage:
                  'Remove loading field. Use AsyncNotifier with AsyncValue.when() pattern. AsyncValue automatically manages loading states.',
            );
            reporter.atNode(variable, code);
          }
        }
      }

      if (member is ConstructorDeclaration) {
        _checkConstructorParameters(member, reporter);
      }
    }
  }

  void _checkConstructorParameters(
    ConstructorDeclaration constructor,
    DiagnosticReporter reporter,
  ) {
    for (final param in constructor.parameters.parameters) {
      String? paramName;
      AstNode? nameNode;

      if (param is DefaultFormalParameter) {
        paramName = param.parameter.name?.lexeme;
        nameNode = param.parameter;
      } else if (param is SimpleFormalParameter) {
        paramName = param.name?.lexeme;
        nameNode = param;
      } else if (param is FieldFormalParameter) {
        paramName = param.name.lexeme;
        nameNode = param;
      }

      if (paramName == null || nameNode == null) continue;

      final paramNameLower = paramName.toLowerCase();

      if (_isErrorField(paramNameLower)) {
        final code = LintCode(
          name: 'presentation_use_async_value',
          problemMessage:
              'State should NOT have error parameter "$paramName". Use AsyncValue instead.',
          correctionMessage:
              'Remove error parameter. Use AsyncNotifier with AsyncValue.when() pattern. AsyncValue automatically manages error states.',
        );
        reporter.atNode(nameNode, code);
      }

      if (_isLoadingField(paramNameLower)) {
        final code = LintCode(
          name: 'presentation_use_async_value',
          problemMessage:
              'State should NOT have loading parameter "$paramName". Use AsyncValue instead.',
          correctionMessage:
              'Remove loading parameter. Use AsyncNotifier with AsyncValue.when() pattern. AsyncValue automatically manages loading states.',
        );
        reporter.atNode(nameNode, code);
      }
    }
  }

  bool _isErrorField(String fieldName) {
    if (errorFieldNames.contains(fieldName)) {
      return true;
    }

    for (final keyword in errorFieldNames) {
      if (fieldName.contains(keyword)) {
        return true;
      }
    }

    return false;
  }

  bool _isLoadingField(String fieldName) {
    if (loadingFieldNames.contains(fieldName)) {
      return true;
    }

    for (final keyword in loadingFieldNames) {
      if (fieldName.contains(keyword)) {
        return true;
      }
    }

    return false;
  }
}
