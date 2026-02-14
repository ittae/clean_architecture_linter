import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../clean_architecture_linter_base.dart';
import '../../mixins/repository_rule_visitor.dart';

/// Enforces proper repository implementation patterns in data layer.
///
/// This rule ensures that the data layer follows the Repository pattern correctly:
/// - Data layer classes named *RepositoryImpl must implement domain repository interfaces
/// - Must use `implements` keyword to implement repository interface
/// - Repository implementations should be in data layer, not domain layer
/// - Repository interfaces should be in domain layer, not data layer
///
/// Benefits of proper repository implementation:
/// - Clear separation between interface and implementation
/// - Testability through interface-based mocking
/// - Dependency Inversion Principle compliance
/// - Supports multiple data source strategies
class RepositoryImplementationRule extends CleanArchitectureLintRule
    with RepositoryRuleVisitor {
  const RepositoryImplementationRule() : super(code: _code);

  static const _code = LintCode(
    name: 'repository_implementation',
    problemMessage:
        'Data layer repository implementation must properly implement domain repository interface.',
    correctionMessage:
        'Ensure RepositoryImpl classes use implements keyword with domain repository interface.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runRule(
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
    final className = node.name.lexeme;

    // Check for RepositoryImpl in data layer
    if (CleanArchitectureUtils.isDataFile(filePath)) {
      _checkDataLayerRepository(node, reporter, className);
    }

    // Check for Repository interface misplaced in data layer
    if (CleanArchitectureUtils.isDataFile(filePath) &&
        className.endsWith('Repository') &&
        !className.endsWith('RepositoryImpl')) {
      _checkMisplacedInterface(node, reporter, className);
    }

    // Check for RepositoryImpl misplaced in domain layer
    if (CleanArchitectureUtils.isDomainFile(filePath) &&
        className.endsWith('RepositoryImpl')) {
      _checkMisplacedImplementation(node, reporter, className);
    }
  }

  void _checkDataLayerRepository(
    ClassDeclaration node,
    DiagnosticReporter reporter,
    String className,
  ) {
    // Only check classes that look like repository implementations
    if (!className.endsWith('RepositoryImpl')) return;

    // Check if it implements a repository interface
    final implementsClause = node.implementsClause;
    if (implementsClause == null || implementsClause.interfaces.isEmpty) {
      final code = LintCode(
        name: 'repository_implementation',
        problemMessage:
            'Repository implementation must implement a domain repository interface: $className',
        correctionMessage:
            'Add implements clause with domain repository interface. Example: class UserRepositoryImpl implements UserRepository',
        errorSeverity: DiagnosticSeverity.WARNING,
      );
      reporter.atNode(node, code);
      return;
    }

    // Verify that at least one interface is a repository interface
    final hasRepositoryInterface = implementsClause.interfaces.any((interface) {
      final interfaceName = interface.name.lexeme;
      return interfaceName.endsWith('Repository') &&
          !interfaceName.endsWith('RepositoryImpl');
    });

    if (!hasRepositoryInterface) {
      final implementedInterfaces = implementsClause.interfaces
          .map((i) => i.name.lexeme)
          .join(', ');
      final code = LintCode(
        name: 'repository_implementation',
        problemMessage:
            'Repository implementation should implement a domain repository interface: $className implements $implementedInterfaces',
        correctionMessage:
            'Implement the corresponding domain repository interface. Example: class UserRepositoryImpl implements UserRepository',
        errorSeverity: DiagnosticSeverity.WARNING,
      );
      reporter.atNode(node, code);
    }
  }

  void _checkMisplacedInterface(
    ClassDeclaration node,
    DiagnosticReporter reporter,
    String className,
  ) {
    // Abstract classes in data layer that look like repository interfaces
    if (node.abstractKeyword != null) {
      final code = LintCode(
        name: 'repository_implementation',
        problemMessage:
            'Repository interface should be in domain layer, not data layer: $className',
        correctionMessage:
            'Move abstract repository interface to domain layer. Data layer should only contain RepositoryImpl classes.',
        errorSeverity: DiagnosticSeverity.WARNING,
      );
      reporter.atNode(node, code);
    }
  }

  void _checkMisplacedImplementation(
    ClassDeclaration node,
    DiagnosticReporter reporter,
    String className,
  ) {
    final code = LintCode(
      name: 'repository_implementation',
      problemMessage:
          'Repository implementation should be in data layer, not domain layer: $className',
      correctionMessage:
          'Move $className to data layer. Domain layer should only contain abstract repository interfaces.',
      errorSeverity: DiagnosticSeverity.WARNING,
    );
    reporter.atNode(node, code);
  }
}
