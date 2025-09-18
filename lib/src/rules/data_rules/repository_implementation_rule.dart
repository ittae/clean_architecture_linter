import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

class RepositoryImplementationRule extends DartLintRule {
  const RepositoryImplementationRule() : super(code: _code);

  static const _code = LintCode(
    name: 'repository_implementation',
    problemMessage:
        'Repository implementations should properly implement domain interfaces.',
    correctionMessage:
        'Ensure repository classes implement domain repository interfaces and delegate to data sources.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((node) {
      _checkRepositoryImplementation(node, reporter, resolver);
    });
  }

  void _checkRepositoryImplementation(
    ClassDeclaration node,
    DiagnosticReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;

    // Only check files in data layer repositories
    if (!_isDataLayerRepositoryFile(filePath)) return;

    final className = node.name.lexeme;

    // Check if this is a repository implementation
    if (!_isRepositoryImplementation(className)) return;

    // Check if it implements an interface
    final implementsClause = node.implementsClause;
    final extendsClause = node.extendsClause;

    if (implementsClause == null && extendsClause == null) {
      reporter.atNode(node, _code);
    } else {
      // Check if it has proper data source dependencies
      final hasDataSourceDependency = _hasDataSourceDependency(node);
      if (!hasDataSourceDependency) {
        reporter.atNode(node, _code);
      }
    }
  }

  bool _isDataLayerRepositoryFile(String filePath) {
    return (filePath.contains('/data/') || filePath.contains('\\data\\')) &&
        (filePath.contains('/repositories/') ||
            filePath.contains('\\repositories\\') ||
            filePath.contains('repository'));
  }

  bool _isRepositoryImplementation(String className) {
    return className.endsWith('Repository') ||
        className.endsWith('RepositoryImpl') ||
        className.contains('Repository');
  }

  bool _hasDataSourceDependency(ClassDeclaration node) {
    // Check constructor parameters for DataSource dependencies
    for (final member in node.members) {
      if (member is ConstructorDeclaration) {
        final parameters = member.parameters.parameters;
        for (final param in parameters) {
          if (param is SimpleFormalParameter) {
            final type = param.type;
            if (type is NamedType) {
              final typeName = type.name.lexeme;
              if (typeName.contains('DataSource')) {
                return true;
              }
            }
          }
        }
      }
    }

    // Check field declarations for DataSource fields
    for (final member in node.members) {
      if (member is FieldDeclaration) {
        final type = member.fields.type;
        if (type is NamedType) {
          final typeName = type.name.lexeme;
          if (typeName.contains('DataSource')) {
            return true;
          }
        }
      }
    }

    return false;
  }
}
