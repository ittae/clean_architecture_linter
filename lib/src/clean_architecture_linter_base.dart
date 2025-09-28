/// Base configuration and utilities for Clean Architecture Linter.
///
/// This file contains shared utilities and configuration that can be used
/// across different lint rules.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Utility functions for Clean Architecture layer detection and file filtering.
class CleanArchitectureUtils {
  /// Checks if a file path should be excluded from analysis.
  ///
  /// Excludes:
  /// - Test folders (/test/ or \test\)
  /// - Generated files (*.g.dart, *.freezed.dart, *.mocks.dart, *.config.dart)
  /// - Build folders (build/, .dart_tool/)
  /// - Documentation files with no code (*.md, *.txt, *.yaml when not pubspec)
  /// - Example folders when they contain test code
  static bool shouldExcludeFile(String filePath) {
    // Exclude test folders
    if (_isTestFile(filePath)) {
      return true;
    }

    // Exclude generated files
    if (_isGeneratedFile(filePath)) {
      return true;
    }

    // Exclude build artifacts
    if (_isBuildArtifact(filePath)) {
      return true;
    }

    // Exclude documentation files (but keep pubspec.yaml and analysis_options.yaml)
    if (_isDocumentationFile(filePath)) {
      return true;
    }

    return false;
  }

  /// Checks if a file is a test file.
  static bool _isTestFile(String filePath) {
    return filePath.contains('/test/') ||
           filePath.contains('\\test\\') ||
           filePath.endsWith('_test.dart') ||
           filePath.contains('/integration_test/') ||
           filePath.contains('\\integration_test\\');
  }

  /// Checks if a file is generated code.
  static bool _isGeneratedFile(String filePath) {
    return filePath.endsWith('.g.dart') ||
           filePath.endsWith('.freezed.dart') ||
           filePath.endsWith('.mocks.dart') ||
           filePath.endsWith('.config.dart') ||
           filePath.endsWith('.gr.dart') ||
           filePath.endsWith('.localizely.dart') ||
           filePath.contains('.pb.dart');
  }

  /// Checks if a file is a build artifact.
  static bool _isBuildArtifact(String filePath) {
    return filePath.contains('/build/') ||
           filePath.contains('\\build\\') ||
           filePath.contains('/.dart_tool/') ||
           filePath.contains('\\.dart_tool\\') ||
           filePath.contains('/.packages') ||
           filePath.contains('\\.packages');
  }

  /// Checks if a file is documentation without code.
  static bool _isDocumentationFile(String filePath) {
    if (filePath.endsWith('.md') ||
        filePath.endsWith('.txt') ||
        filePath.endsWith('.rst')) {
      return true;
    }

    // Keep important YAML files but exclude others
    if (filePath.endsWith('.yaml') || filePath.endsWith('.yml')) {
      final fileName = filePath.split('/').last.split('\\').last;
      final importantYamlFiles = [
        'pubspec.yaml',
        'analysis_options.yaml',
        'build.yaml',
        'dependency_validator.yaml'
      ];
      return !importantYamlFiles.contains(fileName);
    }

    return false;
  }

  /// Checks if a file belongs to the domain layer (excluding test files).
  static bool isDomainLayerFile(String filePath) {
    if (shouldExcludeFile(filePath)) return false;
    return filePath.contains('/domain/') || filePath.contains('\\domain\\');
  }

  /// Checks if a file belongs to the data layer (excluding test files).
  static bool isDataLayerFile(String filePath) {
    if (shouldExcludeFile(filePath)) return false;
    return filePath.contains('/data/') || filePath.contains('\\data\\');
  }

  /// Checks if a file belongs to the presentation layer (excluding test files).
  static bool isPresentationLayerFile(String filePath) {
    if (shouldExcludeFile(filePath)) return false;
    return filePath.contains('/presentation/') || filePath.contains('\\presentation\\');
  }

  /// Checks if a method belongs to a repository interface.
  ///
  /// Repository interfaces are domain layer abstractions that define
  /// data access contracts without implementation details.
  static bool isRepositoryInterfaceMethod(MethodDeclaration method) {
    // Get the parent class declaration
    final parent = method.parent;
    if (parent is! ClassDeclaration) return false;

    return isRepositoryInterface(parent);
  }

  /// Checks if a class is a repository interface.
  ///
  /// Repository interfaces are domain layer abstractions that define
  /// data access contracts without implementation details.
  static bool isRepositoryInterface(ClassDeclaration classDeclaration) {
    final className = classDeclaration.name.lexeme;

    // Check if class name suggests it's a repository interface
    final repositoryPatterns = [
      'Repository',
      'DataSource',
      'Gateway',
      'Port',
    ];

    final isRepositoryClass = repositoryPatterns.any((pattern) =>
        className.contains(pattern));

    if (!isRepositoryClass) return false;

    // Check if the class is abstract (interface) or has only abstract methods
    final isAbstractClass = classDeclaration.abstractKeyword != null;

    // Check if all methods in the class are abstract (interface pattern)
    final hasOnlyAbstractMethods = classDeclaration.members
        .whereType<MethodDeclaration>()
        .every((method) => method.isAbstract || method.isGetter || method.isSetter);

    return isRepositoryClass && (isAbstractClass || hasOnlyAbstractMethods);
  }
}

/// Base class for Clean Architecture lint rules that automatically excludes test files.
abstract class CleanArchitectureLintRule extends DartLintRule {
  const CleanArchitectureLintRule({required super.code});

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    final filePath = resolver.path;

    // Skip analysis for test files and generated files
    if (CleanArchitectureUtils.shouldExcludeFile(filePath)) {
      return;
    }

    // Call the rule-specific implementation
    runRule(resolver, reporter, context);
  }

  /// Override this method instead of run() to implement rule-specific logic.
  /// Test files are automatically excluded.
  void runRule(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  );
}

/// Configuration options for Clean Architecture Linter rules.
class CleanArchitectureConfig {
  /// Whether to enforce strict naming conventions.
  final bool strictNaming;

  /// Whether to allow certain external dependencies in domain layer.
  final bool allowExternalDependencies;

  /// Custom patterns for file and class naming.
  final Map<String, List<String>> namingPatterns;

  const CleanArchitectureConfig({
    this.strictNaming = true,
    this.allowExternalDependencies = false,
    this.namingPatterns = const {},
  });
}
