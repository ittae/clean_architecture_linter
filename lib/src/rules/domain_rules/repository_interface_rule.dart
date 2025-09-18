import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

class RepositoryInterfaceRule extends DartLintRule {
  const RepositoryInterfaceRule() : super(code: _code);

  static const _code = LintCode(
    name: 'repository_interface',
    problemMessage: 'Domain layer should only depend on repository interfaces, not implementations.',
    correctionMessage: 'Use abstract repository interfaces in domain layer instead of concrete implementations.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addImportDirective((node) {
      _checkRepositoryImports(node, reporter, resolver);
    });
  }

  void _checkRepositoryImports(
    ImportDirective node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;

    // Only check files in domain layer
    if (!_isDomainLayerFile(filePath)) return;

    final importUri = node.uri.stringValue;
    if (importUri == null) return;

    // Check if importing from data layer repository implementations
    if (_isDataLayerRepositoryImport(importUri)) {
      reporter.atNode(node, _code);
    }
  }

  bool _isDomainLayerFile(String filePath) {
    return filePath.contains('/domain/') ||
           filePath.contains('\\domain\\');
  }

  bool _isDataLayerRepositoryImport(String importUri) {
    // Detect imports from data layer repository implementations
    return (importUri.contains('/data/') || importUri.contains('\\data\\')) &&
           (importUri.contains('repository') || importUri.contains('Repository'));
  }
}