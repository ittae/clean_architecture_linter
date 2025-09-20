/// A minimal custom lint package with only CORE Clean Architecture principles.
///
/// This version includes only the most essential rules that should NEVER be violated.
/// Perfect for teams starting with Clean Architecture or legacy projects.
library;

import 'package:custom_lint_builder/custom_lint_builder.dart';

import 'src/rules/domain_rules/domain_purity_rule.dart';
import 'src/rules/domain_rules/dependency_inversion_rule.dart';
import 'src/rules/domain_rules/repository_interface_rule.dart';
import 'src/rules/layer_dependency_rule.dart';
import 'src/rules/circular_dependency_rule.dart';

/// Plugin entry point for Clean Architecture Linter - CORE ONLY.
PluginBase createCorePlugin() => _CleanArchitectureLinterCorePlugin();

class _CleanArchitectureLinterCorePlugin extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => [
    // ONLY the absolute essentials
    DomainPurityRule(),           // Domain must be pure
    DependencyInversionRule(),    // High-level depends on abstractions
    RepositoryInterfaceRule(),    // Repository pattern enforcement
    LayerDependencyRule(),        // Layer dependency direction
    CircularDependencyRule(),     // No circular dependencies
  ];
}