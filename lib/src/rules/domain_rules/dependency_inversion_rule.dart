import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

class DependencyInversionRule extends DartLintRule {
  const DependencyInversionRule() : super(code: _code);

  static const _code = LintCode(
    name: 'dependency_inversion',
    problemMessage: 'Domain layer should depend on abstractions, not concretions.',
    correctionMessage: 'Use interfaces or abstract classes instead of concrete implementations.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addConstructorDeclaration((node) {
      _checkDependencyInversion(node, reporter, resolver);
    });
  }

  void _checkDependencyInversion(
    ConstructorDeclaration node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;

    // Only check files in domain layer
    if (!_isDomainLayerFile(filePath)) return;

    // Check constructor parameters for concrete dependencies
    final parameters = node.parameters.parameters;
    for (final param in parameters) {
      if (param is SimpleFormalParameter) {
        final type = param.type;
        if (type is NamedType) {
          final typeName = type.name2.lexeme;
          if (_isConcreteType(typeName)) {
            reporter.atNode(param, _code);
          }
        }
      }
    }
  }

  bool _isDomainLayerFile(String filePath) {
    return filePath.contains('/domain/') ||
           filePath.contains('\\domain\\');
  }

  bool _isConcreteType(String typeName) {
    // Check for common concrete type patterns that should be abstracted
    final concretePatterns = [
      'Impl',
      'Implementation',
      'Concrete',
      'Service', // Services should typically be interfaces in domain
    ];

    return concretePatterns.any((pattern) => typeName.contains(pattern)) ||
           _isExternalFrameworkType(typeName);
  }

  bool _isExternalFrameworkType(String typeName) {
    // Common external framework types that shouldn't be in domain
    final externalTypes = [
      'HttpClient',
      'Client',
      'Database',
      'SharedPreferences',
      'FirebaseFirestore',
    ];

    return externalTypes.contains(typeName);
  }
}