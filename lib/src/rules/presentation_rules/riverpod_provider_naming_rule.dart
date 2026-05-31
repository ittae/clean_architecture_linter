import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../../clean_architecture_linter_base.dart';

/// Enforces proper naming convention for Riverpod provider functions.
class RiverpodProviderNamingRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'riverpod_provider_naming',
    '{0}',
    correctionMessage: '{1}',
    severity: DiagnosticSeverity.WARNING,
    uniqueName: 'LintCode.riverpod_provider_naming',
  );

  RiverpodProviderNamingRule()
    : super(
        name: 'riverpod_provider_naming',
        description:
            'Requires provider function names to include returned type suffix.',
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
    registry.addFunctionDeclaration(
      this,
      _RiverpodProviderNamingVisitor(this, context),
    );
  }
}

class _RiverpodProviderNamingVisitor extends SimpleAstVisitor<void> {
  _RiverpodProviderNamingVisitor(this.rule, this.context);

  final AnalysisRule rule;
  final RuleContext context;

  String get _filePath =>
      context.currentUnit?.file.path ?? context.definingUnit.file.path;

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    if (!_isProviderFile(_filePath)) return;
    if (!_hasRiverpodAnnotation(node)) return;

    final functionName = node.name.lexeme;
    final returnType = node.returnType;
    if (returnType == null) return;

    final returnTypeName = _getReturnTypeName(returnType);
    if (returnTypeName == null) return;

    final requiredSuffix = _getRequiredSuffix(returnTypeName);
    if (requiredSuffix == null) return;

    final lowerFunctionName = functionName.toLowerCase();
    if (!lowerFunctionName.endsWith(requiredSuffix.toLowerCase())) {
      final suggestedName = _suggestFunctionName(functionName, requiredSuffix);
      rule.reportAtNode(
        node,
        arguments: [
          'Provider function "$functionName" returning $returnTypeName must end with "$requiredSuffix".',
          'Rename to "$suggestedName" to generate "${suggestedName}Provider".',
        ],
      );
    }
  }

  bool _isProviderFile(String filePath) {
    if (CleanArchitectureUtils.shouldExcludeFile(filePath)) return false;

    final normalizedPath = filePath.replaceAll('\\', '/').toLowerCase();
    if (!normalizedPath.contains('/presentation/')) return false;

    return normalizedPath.contains('/providers/') ||
        normalizedPath.endsWith('_provider.dart') ||
        normalizedPath.endsWith('_providers.dart');
  }

  bool _hasRiverpodAnnotation(FunctionDeclaration node) {
    for (final metadata in node.metadata) {
      final name = metadata.name.name;
      if (name == 'riverpod' || name == 'Riverpod') return true;
    }
    return false;
  }

  String? _getReturnTypeName(TypeAnnotation returnType) {
    if (returnType is NamedType) return returnType.name.lexeme;
    return null;
  }

  String? _getRequiredSuffix(String returnTypeName) {
    final repositoryMatch = _extractSuffix(returnTypeName, 'repository');
    if (repositoryMatch != null) return repositoryMatch;

    final usecaseMatch = _extractSuffix(returnTypeName, 'usecase');
    if (usecaseMatch != null) return usecaseMatch;

    final datasourceMatch = _extractSuffix(returnTypeName, 'datasource');
    if (datasourceMatch != null) return datasourceMatch;

    return null;
  }

  String? _extractSuffix(String returnTypeName, String suffix) {
    final lowerTypeName = returnTypeName.toLowerCase();
    final lowerSuffix = suffix.toLowerCase();
    if (!lowerTypeName.contains(lowerSuffix)) return null;

    final index = lowerTypeName.lastIndexOf(lowerSuffix);
    if (index == -1) return null;
    return returnTypeName.substring(index, index + suffix.length);
  }

  String _suggestFunctionName(String currentName, String requiredSuffix) {
    if (requiredSuffix.isEmpty) return currentName;

    final firstChar = requiredSuffix[0];
    final isAlreadyCapitalized = firstChar == firstChar.toUpperCase();
    final capitalizedSuffix = isAlreadyCapitalized
        ? requiredSuffix
        : firstChar.toUpperCase() + requiredSuffix.substring(1);

    return '$currentName$capitalizedSuffix';
  }
}
