/// A comprehensive custom lint package that enforces Clean Architecture principles STRICTLY.
///
/// This version enforces ALL rules as ERRORS, blocking builds on violations.
/// Use this when your team wants maximum architectural compliance.
library;

import 'package:custom_lint_builder/custom_lint_builder.dart';

import 'src/rules/domain_rules/domain_purity_rule.dart';
import 'src/rules/domain_rules/repository_interface_rule.dart';
import 'src/rules/domain_rules/domain_model_validation_rule.dart';
import 'src/rules/domain_rules/dependency_inversion_rule.dart';
import 'src/rules/domain_rules/consolidated_entity_rule.dart';
import 'src/rules/domain_rules/consolidated_usecase_rule.dart';
import 'src/rules/data_rules/datasource_naming_rule.dart';
import 'src/rules/data_rules/repository_implementation_rule.dart';
import 'src/rules/data_rules/model_structure_rule.dart';
import 'src/rules/presentation_rules/ui_dependency_injection_rule.dart';
import 'src/rules/presentation_rules/state_management_rule.dart';
import 'src/rules/presentation_rules/presentation_logic_separation_rule.dart';
import 'src/rules/presentation_rules/business_logic_isolation_rule.dart';
import 'src/rules/layer_dependency_rule.dart';
import 'src/rules/circular_dependency_rule.dart';

/// Plugin entry point for Clean Architecture Linter - STRICT MODE.
PluginBase createStrictPlugin() => _CleanArchitectureLinterStrictPlugin();

class _CleanArchitectureLinterStrictPlugin extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => [
    // Core Domain Rules - ALL ENFORCED
    DomainPurityRule(),
    ConsolidatedEntityRule(),
    ConsolidatedUseCaseRule(),
    RepositoryInterfaceRule(),
    DomainModelValidationRule(),
    DependencyInversionRule(),

    // Data Layer Rules - ALL ENFORCED
    DataSourceNamingRule(),
    RepositoryImplementationRule(),
    ModelStructureRule(),

    // Presentation Layer Rules - ALL ENFORCED
    UiDependencyInjectionRule(),
    StateManagementRule(),
    PresentationLogicSeparationRule(),
    BusinessLogicIsolationRule(),

    // Cross-Layer Rules - CRITICAL
    LayerDependencyRule(),
    CircularDependencyRule(),
  ];
}