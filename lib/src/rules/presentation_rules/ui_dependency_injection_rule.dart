import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

class UiDependencyInjectionRule extends DartLintRule {
  const UiDependencyInjectionRule() : super(code: _code);

  static const _code = LintCode(
    name: 'ui_dependency_injection',
    problemMessage: 'UI components should receive dependencies through dependency injection.',
    correctionMessage: 'Use dependency injection patterns instead of direct instantiation in UI components.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((node) {
      _checkUIConstructorUsage(node, reporter, resolver);
    });
  }

  void _checkUIConstructorUsage(
    InstanceCreationExpression node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;

    // Only check files in presentation layer
    if (!_isPresentationLayerFile(filePath)) return;

    final constructorName = node.constructorName.type.name2.lexeme;

    // Check if creating instances of domain or data layer classes directly
    if (_isDomainOrDataLayerClass(constructorName)) {
      reporter.atNode(node, _code);
    }
  }

  bool _isPresentationLayerFile(String filePath) {
    return filePath.contains('/presentation/') ||
           filePath.contains('\\presentation\\') ||
           filePath.contains('/ui/') ||
           filePath.contains('\\ui\\') ||
           filePath.contains('/widgets/') ||
           filePath.contains('\\widgets\\') ||
           filePath.contains('/pages/') ||
           filePath.contains('\\pages\\') ||
           filePath.contains('/screens/') ||
           filePath.contains('\\screens\\');
  }

  bool _isDomainOrDataLayerClass(String className) {
    // Common patterns for domain/data layer classes that shouldn't be instantiated in UI
    final domainDataPatterns = [
      'UseCase',
      'Repository',
      'DataSource',
      'Service',
      'Provider', // Business logic providers, not UI providers
    ];

    return domainDataPatterns.any((pattern) => className.contains(pattern)) ||
           _isHttpClientClass(className);
  }

  bool _isHttpClientClass(String className) {
    final httpClientPatterns = [
      'HttpClient',
      'Dio',
      'Client',
      'ApiClient',
    ];

    return httpClientPatterns.contains(className);
  }
}