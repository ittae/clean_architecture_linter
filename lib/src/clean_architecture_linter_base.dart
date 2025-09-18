/// Base configuration and utilities for Clean Architecture Linter.
///
/// This file contains shared utilities and configuration that can be used
/// across different lint rules.
library;

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
