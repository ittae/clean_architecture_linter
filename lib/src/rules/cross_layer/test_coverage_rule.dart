import 'dart:io';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:path/path.dart' as path;

import '../../clean_architecture_linter_base.dart';

/// Enforces test coverage for critical Clean Architecture components.
///
/// This rule ensures that important business logic and integration points have tests:
/// - **UseCase**: Core business logic must be tested
/// - **Repository Implementation**: Data layer integration must be tested
/// - **DataSource Implementation**: Either has tests OR abstract interface (for mocking)
/// - **Riverpod Notifier**: State management logic must be tested
///
/// Enable with configuration:
/// ```yaml
/// custom_lint:
///   rules:
///     - clean_architecture_linter_require_test: true
///       check_usecases: true
///       check_repositories: true
///       check_datasources: true
///       check_notifiers: true
/// ```
///
/// Test file naming convention:
/// - `lib/features/X/domain/usecases/get_user_usecase.dart`
/// - → `test/features/X/domain/usecases/get_user_usecase_test.dart`
///
/// Benefits:
/// - Ensures business logic is verified
/// - Catches integration issues early
/// - Documents expected behavior through tests
/// - Enables safe refactoring
class TestCoverageRule extends CleanArchitectureLintRule {
  const TestCoverageRule({
    this.checkUsecases = true,
    this.checkRepositories = true,
    this.checkDatasources = true,
    this.checkNotifiers = true,
  }) : super(code: _code);

  final bool checkUsecases;
  final bool checkRepositories;
  final bool checkDatasources;
  final bool checkNotifiers;

  static const _code = LintCode(
    name: 'clean_architecture_linter_require_test',
    problemMessage: 'Critical components should have corresponding test files',
    correctionMessage:
        'Create a test file for this component or disable this rule in analysis_options.yaml',
  );

  @override
  void runRule(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    // Check class declarations for testable components
    context.registry.addClassDeclaration((node) {
      _checkTestCoverage(node, reporter, resolver);
    });
  }

  void _checkTestCoverage(
    ClassDeclaration node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    final className = node.name.lexeme;

    // Determine component type
    final componentType = _identifyComponentType(filePath, className, node);
    if (componentType == null) {
      // Not a testable component
      return;
    }

    // Check if this component type should be checked
    final shouldCheck = switch (componentType) {
      ComponentType.useCase => checkUsecases,
      ComponentType.repositoryImpl => checkRepositories,
      ComponentType.dataSource => checkDatasources,
      ComponentType.notifier => checkNotifiers,
    };

    if (!shouldCheck) {
      // This component type is disabled
      return;
    }

    // Check if test file exists
    final testFilePath = _getExpectedTestFilePath(filePath);
    final testFileExists = File(testFilePath).existsSync();

    if (testFileExists) {
      // Test file exists - OK
      return;
    }

    // Special case for DataSource: abstract interface is acceptable
    if (componentType == ComponentType.dataSource) {
      if (_hasAbstractInterface(node, filePath)) {
        // Has abstract interface for mocking - OK
        return;
      }
    }

    // No test file found - report violation
    _reportMissingTest(componentType, className, node, reporter, testFilePath);
  }

  ComponentType? _identifyComponentType(
    String filePath,
    String className,
    ClassDeclaration node,
  ) {
    final normalized = filePath.replaceAll('\\', '/').toLowerCase();

    // Skip test files themselves
    if (normalized.contains('/test/')) {
      return null;
    }

    // Check for UseCase
    // Must end with "UseCase" in class name OR file must end with "_usecase.dart"
    if (className.endsWith('UseCase')) {
      return ComponentType.useCase;
    }
    if (filePath.endsWith('_usecase.dart') &&
        normalized.contains('/usecases/')) {
      // File is in usecases directory and ends with _usecase.dart
      // But we still require class name to end with UseCase
      // So this won't catch non-UseCase classes in the file
      return null; // Already checked className above
    }

    // Check for Repository Implementation
    if (className.endsWith('RepositoryImpl') ||
        className.endsWith('RepositoryImplementation')) {
      return ComponentType.repositoryImpl;
    }

    // Check for DataSource Implementation
    if (_isDataSourceImplementation(className, node)) {
      return ComponentType.dataSource;
    }

    // Check for Riverpod Notifier
    if (_isRiverpodNotifier(node, filePath)) {
      return ComponentType.notifier;
    }

    return null;
  }

  bool _isDataSourceImplementation(String className, ClassDeclaration node) {
    // Check if it's a DataSource class
    if (!className.contains('DataSource') &&
        !className.contains('Datasource')) {
      return false;
    }

    // It's a concrete DataSource if it's NOT abstract
    return node.abstractKeyword == null;
  }

  bool _isRiverpodNotifier(ClassDeclaration node, String filePath) {
    // Check for @riverpod annotation
    final hasRiverpodAnnotation = node.metadata.any((annotation) {
      final name = annotation.name.toString();
      return name == 'riverpod' || name == 'Riverpod';
    });

    if (hasRiverpodAnnotation) return true;

    // Check if in providers directory and extends notifier pattern
    final normalized = filePath.replaceAll('\\', '/').toLowerCase();
    if (normalized.contains('/providers/')) {
      final className = node.name.lexeme;
      if (className.endsWith('Notifier')) {
        return true;
      }
    }

    return false;
  }

  bool _hasAbstractInterface(ClassDeclaration node, String filePath) {
    // If the class itself is abstract, it's the interface
    if (node.abstractKeyword != null) {
      return true;
    }

    // Check if there's a corresponding abstract class in the same file or project
    final className = node.name.lexeme;

    // Common patterns:
    // UserRemoteDataSource (concrete) → has abstract UserRemoteDataSource
    // UserRemoteDataSourceImpl → has abstract UserRemoteDataSource

    // If class ends with Impl, there should be abstract version without Impl
    if (className.endsWith('Impl')) {
      // Abstract interface likely exists (named without Impl)
      return true;
    }

    // For concrete classes without Impl suffix, we'd need to check the file
    // or project for abstract version - for now, assume no interface
    return false;
  }

  String _getExpectedTestFilePath(String libFilePath) {
    // Convert: lib/features/user/domain/usecases/get_user_usecase.dart
    // To:      test/features/user/domain/usecases/get_user_usecase_test.dart

    final normalized = libFilePath.replaceAll('\\', '/');

    // Find the lib/ part
    final libIndex = normalized.indexOf('/lib/');
    if (libIndex == -1) {
      // Fallback: just replace lib with test
      return normalized.replaceFirst('/lib/', '/test/').replaceFirst(
            '.dart',
            '_test.dart',
          );
    }

    final projectRoot = normalized.substring(0, libIndex);
    final relativePath = normalized.substring(libIndex + 5); // Skip '/lib/'

    // Remove .dart extension and add _test.dart
    final testRelativePath = relativePath.replaceFirst('.dart', '_test.dart');

    return path.join(projectRoot, 'test', testRelativePath);
  }

  void _reportMissingTest(
    ComponentType type,
    String className,
    ClassDeclaration node,
    ErrorReporter reporter,
    String expectedTestPath,
  ) {
    final componentName = _getComponentDisplayName(type);

    final code = LintCode(
      name: 'clean_architecture_linter_require_test',
      problemMessage: '$componentName "$className" is missing a test file',
      correctionMessage:
          'Create test file at: ${path.relative(expectedTestPath)}',
    );

    reporter.atNode(node, code);
  }

  String _getComponentDisplayName(ComponentType type) {
    switch (type) {
      case ComponentType.useCase:
        return 'UseCase';
      case ComponentType.repositoryImpl:
        return 'Repository Implementation';
      case ComponentType.dataSource:
        return 'DataSource';
      case ComponentType.notifier:
        return 'Notifier';
    }
  }
}

/// Types of components that should have test coverage
enum ComponentType {
  useCase,
  repositoryImpl,
  dataSource,
  notifier,
}
