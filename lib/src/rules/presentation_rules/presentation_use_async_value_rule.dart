import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../../compat/analyzer_ast_compat.dart';
import '../../clean_architecture_linter_base.dart';

class PresentationUseAsyncValueRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'presentation_use_async_value',
    '{0}',
    correctionMessage: '{1}',
    severity: DiagnosticSeverity.WARNING,
    uniqueName: 'LintCode.presentation_use_async_value',
  );

  PresentationUseAsyncValueRule()
    : super(
        name: 'presentation_use_async_value',
        description:
            'Requires presentation state errors/loading to use AsyncValue.',
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
  bool get canUseParsedResult => true;

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final visitor = _PresentationUseAsyncValueVisitor(this, context);
    registry.addClassDeclaration(this, visitor);
    registry.addCatchClause(this, visitor);
  }
}

class _PresentationUseAsyncValueVisitor extends SimpleAstVisitor<void> {
  _PresentationUseAsyncValueVisitor(this.rule, this.context);

  final AnalysisRule rule;
  final RuleContext context;

  String get _filePath =>
      context.currentUnit?.file.path ?? context.definingUnit.file.path;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    if (_shouldSkipFile) return;
    if (!_isFreezedState(node)) return;

    _checkForErrorFields(node);
  }

  @override
  void visitCatchClause(CatchClause node) {
    if (_shouldSkipFile) return;

    final classNode = node.thisOrAncestorOfType<ClassDeclaration>();
    if (classNode == null || !_isNotifierOrProviderClass(classNode)) return;

    if (node.body.toSource().contains('rethrow')) return;

    if (!_containsAsyncValueErrorHandling(node.body)) {
      rule.reportAtNode(
        node,
        arguments: const [
          'Notifier/Provider catch did not map exception to UI state.',
          'Use AsyncValue.guard(), state = AsyncValue.error(...), or UI handling via when(error: ...).',
        ],
      );
    }
  }

  bool get _shouldSkipFile {
    return CleanArchitectureUtils.shouldExcludeFile(_filePath) ||
        !CleanArchitectureUtils.isPresentationFile(_filePath);
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
    final className = node.namePart.typeName.lexeme;
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

  void _checkForErrorFields(ClassDeclaration node) {
    for (final member in node.body.members) {
      if (member is FieldDeclaration) {
        for (final variable in member.fields.variables) {
          final fieldName = variable.name.lexeme;
          final fieldNameLower = fieldName.toLowerCase();

          if (_isErrorField(fieldNameLower)) {
            rule.reportAtNode(
              variable,
              arguments: [
                'State should NOT have error field "$fieldName". Use AsyncValue instead.',
                'Remove error field. Use AsyncNotifier with AsyncValue.when() pattern. AsyncValue automatically manages error states.',
              ],
            );
          }

          if (_isLoadingField(fieldNameLower)) {
            rule.reportAtNode(
              variable,
              arguments: [
                'State should NOT have loading field "$fieldName". Use AsyncValue instead.',
                'Remove loading field. Use AsyncNotifier with AsyncValue.when() pattern. AsyncValue automatically manages loading states.',
              ],
            );
          }
        }
      }

      if (member is ConstructorDeclaration) {
        _checkConstructorParameters(member);
      }
    }
  }

  void _checkConstructorParameters(ConstructorDeclaration constructor) {
    for (final param in constructor.parameters.parameters) {
      String? paramName;
      AstNode? nameNode;

      paramName = formalParameterName(param);
      nameNode = param;

      if (paramName == null) continue;

      final paramNameLower = paramName.toLowerCase();

      if (_isErrorField(paramNameLower)) {
        rule.reportAtNode(
          nameNode,
          arguments: [
            'State should NOT have error parameter "$paramName". Use AsyncValue instead.',
            'Remove error parameter. Use AsyncNotifier with AsyncValue.when() pattern. AsyncValue automatically manages error states.',
          ],
        );
      }

      if (_isLoadingField(paramNameLower)) {
        rule.reportAtNode(
          nameNode,
          arguments: [
            'State should NOT have loading parameter "$paramName". Use AsyncValue instead.',
            'Remove loading parameter. Use AsyncNotifier with AsyncValue.when() pattern. AsyncValue automatically manages loading states.',
          ],
        );
      }
    }
  }

  bool _isErrorField(String fieldName) {
    if (PresentationUseAsyncValueRule.errorFieldNames.contains(fieldName)) {
      return true;
    }

    for (final keyword in PresentationUseAsyncValueRule.errorFieldNames) {
      if (fieldName.contains(keyword)) {
        return true;
      }
    }

    return false;
  }

  bool _isLoadingField(String fieldName) {
    if (PresentationUseAsyncValueRule.loadingFieldNames.contains(fieldName)) {
      return true;
    }

    for (final keyword in PresentationUseAsyncValueRule.loadingFieldNames) {
      if (fieldName.contains(keyword)) {
        return true;
      }
    }

    return false;
  }
}
