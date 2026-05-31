import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../../clean_architecture_linter_base.dart';

/// Enforces that Widgets/Pages should NOT directly call or import UseCases.
class WidgetNoUseCaseCallRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'widget_no_usecase_call',
    '{0}',
    correctionMessage: '{1}',
    severity: DiagnosticSeverity.WARNING,
    uniqueName: 'LintCode.widget_no_usecase_call',
  );

  WidgetNoUseCaseCallRule()
    : super(
        name: 'widget_no_usecase_call',
        description: 'Prevents widgets from importing/calling UseCases.',
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
    final visitor = _WidgetNoUseCaseCallVisitor(this, context);
    registry.addImportDirective(this, visitor);
    registry.addMethodInvocation(this, visitor);
  }
}

class _WidgetNoUseCaseCallVisitor extends SimpleAstVisitor<void> {
  _WidgetNoUseCaseCallVisitor(this.rule, this.context);

  final AnalysisRule rule;
  final RuleContext context;

  String get _filePath =>
      context.currentUnit?.file.path ?? context.definingUnit.file.path;

  @override
  void visitImportDirective(ImportDirective node) {
    if (!_isWidgetOrPageFile(_filePath)) return;

    final importUri = node.uri.stringValue;
    if (importUri == null) return;
    if (_isUseCaseImport(importUri)) {
      rule.reportAtNode(
        node,
        arguments: [
          'Widget/Page should NOT import UseCase: $importUri',
          'Remove UseCase import. Create a Provider that calls the UseCase instead.',
        ],
      );
    }
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (!_isWidgetOrPageFile(_filePath)) return;
    if (!_isRefCall(node)) return;

    final providerName = _getProviderName(node);
    if (providerName == null) return;
    if (_isUseCaseProvider(providerName)) {
      final methodName = node.methodName.name;
      rule.reportAtNode(
        node,
        arguments: [
          'Widget/Page should NOT call UseCase provider "$providerName" directly via $methodName()',
          'Create an Entity Provider that calls the UseCase, then ref.watch() that provider.',
        ],
      );
    }
  }

  bool _isWidgetOrPageFile(String filePath) {
    if (CleanArchitectureUtils.shouldExcludeFile(filePath)) return false;

    final normalizedPath = filePath.replaceAll('\\', '/').toLowerCase();
    if (!normalizedPath.contains('/presentation/')) return false;

    return normalizedPath.contains('/widgets/') ||
        normalizedPath.contains('/pages/') ||
        normalizedPath.contains('/screens/') ||
        normalizedPath.contains('/views/') ||
        normalizedPath.endsWith('_page.dart') ||
        normalizedPath.endsWith('_screen.dart') ||
        normalizedPath.endsWith('_view.dart') ||
        normalizedPath.endsWith('_widget.dart');
  }

  bool _isUseCaseImport(String importUri) {
    final normalizedUri = importUri.replaceAll('\\', '/').toLowerCase();
    return normalizedUri.contains('/usecases/') ||
        normalizedUri.contains('/use_cases/') ||
        normalizedUri.endsWith('_usecase.dart') ||
        normalizedUri.endsWith('_use_case.dart') ||
        normalizedUri.contains('usecase.dart');
  }

  bool _isRefCall(MethodInvocation node) {
    final methodName = node.methodName.name;
    if (methodName != 'read' && methodName != 'watch') return false;

    final target = node.target;
    return target is SimpleIdentifier && target.name == 'ref';
  }

  String? _getProviderName(MethodInvocation node) {
    final arguments = node.argumentList.arguments;
    if (arguments.isEmpty) return null;

    final firstArg = arguments.first;
    if (firstArg is SimpleIdentifier) return firstArg.name;
    if (firstArg is MethodInvocation) return firstArg.methodName.name;
    if (firstArg is PropertyAccess) {
      final target = firstArg.target;
      if (target is SimpleIdentifier) return target.name;
    }
    return null;
  }

  bool _isUseCaseProvider(String providerName) {
    final lowerName = providerName.toLowerCase();
    return lowerName.endsWith('usecaseprovider') ||
        lowerName.endsWith('usecase') ||
        lowerName.contains('usecase') ||
        lowerName.endsWith('use_case_provider') ||
        lowerName.contains('use_case');
  }
}
