import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

class DataSourceNamingRule extends DartLintRule {
  const DataSourceNamingRule() : super(code: _code);

  static const _code = LintCode(
    name: 'datasource_naming',
    problemMessage: 'DataSource classes should follow proper naming conventions.',
    correctionMessage: 'Use suffix "DataSource", "RemoteDataSource", or "LocalDataSource".',
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((node) {
      _checkDataSourceNaming(node, reporter, resolver);
    });
  }

  void _checkDataSourceNaming(
    ClassDeclaration node,
    DiagnosticReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;

    // Only check files in data layer datasource directory
    if (!_isDataSourceFile(filePath)) return;

    final className = node.name.lexeme;

    // Check if the class follows datasource naming conventions
    if (!_hasValidDataSourceSuffix(className)) {
      reporter.atNode(node, _code);
    }
  }

  bool _isDataSourceFile(String filePath) {
    return (filePath.contains('/data/') || filePath.contains('\\data\\')) &&
           (filePath.contains('/datasources/') ||
            filePath.contains('\\datasources\\') ||
            filePath.contains('datasource'));
  }

  bool _hasValidDataSourceSuffix(String className) {
    final validSuffixes = [
      'DataSource',
      'RemoteDataSource',
      'LocalDataSource',
      'ApiDataSource',
      'CacheDataSource',
      'DatabaseDataSource',
    ];

    return validSuffixes.any((suffix) => className.endsWith(suffix));
  }
}