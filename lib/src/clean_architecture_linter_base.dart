/// Base configuration and utilities for Clean Architecture Linter.
///
/// This file contains shared utilities and configuration that can be used
/// across different lint rules.
library;

import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Utility functions for Clean Architecture layer detection and file filtering.
class CleanArchitectureUtils {
  /// Checks if a file path should be excluded from analysis.
  ///
  /// Excludes:
  /// - Test folders (/test/ or \test\)
  /// - Generated files (*.g.dart, *.freezed.dart, *.mocks.dart)
  static bool shouldExcludeFile(String filePath) {
    // Exclude test folders
    if (filePath.contains('/test/') || filePath.contains('\\test\\')) {
      return true;
    }

    // Exclude generated files
    if (filePath.endsWith('.g.dart') ||
        filePath.endsWith('.freezed.dart') ||
        filePath.endsWith('.mocks.dart')) {
      return true;
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
}

/// Base class for Clean Architecture lint rules that automatically excludes test files.
abstract class CleanArchitectureLintRule extends DartLintRule {
  const CleanArchitectureLintRule({required LintCode code}) : super(code: code);

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
