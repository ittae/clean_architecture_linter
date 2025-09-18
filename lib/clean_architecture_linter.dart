/// A comprehensive custom lint package that enforces Clean Architecture principles in Flutter projects.
///
/// This package provides lint rules to ensure proper separation of concerns,
/// dependency inversion, and architectural boundaries in Flutter applications
/// following Clean Architecture patterns.
library;

import 'package:custom_lint_builder/custom_lint_builder.dart';

import 'src/rules/domain_rules/domain_purity_rule.dart';
import 'src/rules/domain_rules/entity_immutability_rule.dart';
import 'src/rules/domain_rules/repository_interface_rule.dart';
import 'src/rules/domain_rules/usecase_single_responsibility_rule.dart';
import 'src/rules/domain_rules/business_logic_isolation_rule.dart';
import 'src/rules/domain_rules/domain_model_validation_rule.dart';
import 'src/rules/domain_rules/dependency_inversion_rule.dart';
import 'src/rules/data_rules/datasource_naming_rule.dart';
import 'src/rules/data_rules/repository_implementation_rule.dart';
import 'src/rules/data_rules/model_structure_rule.dart';
import 'src/rules/presentation_rules/ui_dependency_injection_rule.dart';
import 'src/rules/presentation_rules/state_management_rule.dart';
import 'src/rules/presentation_rules/presentation_logic_separation_rule.dart';

/// Plugin entry point for Clean Architecture Linter.
PluginBase createPlugin() => _CleanArchitectureLinterPlugin();

class _CleanArchitectureLinterPlugin extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => [
    // Domain Layer Rules
    DomainPurityRule(),
    EntityImmutabilityRule(),
    RepositoryInterfaceRule(),
    UseCaseSingleResponsibilityRule(),
    BusinessLogicIsolationRule(),
    DomainModelValidationRule(),
    DependencyInversionRule(),

    // Data Layer Rules
    DataSourceNamingRule(),
    RepositoryImplementationRule(),
    ModelStructureRule(),

    // Presentation Layer Rules
    UiDependencyInjectionRule(),
    StateManagementRule(),
    PresentationLogicSeparationRule(),
  ];
}
