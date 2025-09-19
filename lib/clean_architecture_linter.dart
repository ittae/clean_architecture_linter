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
import 'src/rules/domain_rules/entity_business_rules_rule.dart';
import 'src/rules/domain_rules/entity_stability_rule.dart';
import 'src/rules/domain_rules/usecase_orchestration_rule.dart';
import 'src/rules/domain_rules/usecase_application_rules_rule.dart';
import 'src/rules/domain_rules/usecase_independence_rule.dart';
import 'src/rules/data_rules/datasource_naming_rule.dart';
import 'src/rules/data_rules/repository_implementation_rule.dart';
import 'src/rules/data_rules/model_structure_rule.dart';
import 'src/rules/presentation_rules/ui_dependency_injection_rule.dart';
import 'src/rules/presentation_rules/state_management_rule.dart';
import 'src/rules/presentation_rules/presentation_logic_separation_rule.dart';
import 'src/rules/layer_dependency_rule.dart';
import 'src/rules/circular_dependency_rule.dart';
import 'src/rules/adapter_rules/data_conversion_adapter_rule.dart';
import 'src/rules/adapter_rules/mvc_architecture_rule.dart';
import 'src/rules/adapter_rules/external_service_adapter_rule.dart';
import 'src/rules/framework_rules/framework_isolation_rule.dart';
import 'src/rules/framework_rules/database_detail_rule.dart';
import 'src/rules/framework_rules/web_framework_detail_rule.dart';
import 'src/rules/framework_rules/glue_code_rule.dart';
import 'src/rules/abstraction_level_rule.dart';
import 'src/rules/flexible_layer_detection_rule.dart';
import 'src/rules/core_dependency_rule.dart';
import 'src/rules/abstraction_progression_rule.dart';
import 'src/rules/boundary_crossing_rule.dart';
import 'src/rules/dependency_inversion_boundary_rule.dart';
import 'src/rules/interface_boundary_rule.dart';
import 'src/rules/polymorphic_flow_control_rule.dart';
import 'src/rules/data_boundary_crossing_rule.dart';
import 'src/rules/entity_boundary_isolation_rule.dart';
import 'src/rules/dto_boundary_pattern_rule.dart';
import 'src/rules/database_row_boundary_rule.dart';

/// Plugin entry point for Clean Architecture Linter.
PluginBase createPlugin() => _CleanArchitectureLinterPlugin();

class _CleanArchitectureLinterPlugin extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => [
    // Domain Layer Rules
    DomainPurityRule(),
    EntityImmutabilityRule(),
    EntityBusinessRulesRule(),
    EntityStabilityRule(),
    RepositoryInterfaceRule(),
    UseCaseSingleResponsibilityRule(),
    UseCaseOrchestrationRule(),
    UseCaseApplicationRulesRule(),
    UseCaseIndependenceRule(),
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

    // Cross-Layer Rules
    LayerDependencyRule(),
    CircularDependencyRule(),

    // Interface Adapter Rules
    DataConversionAdapterRule(),
    MVCArchitectureRule(),
    ExternalServiceAdapterRule(),

    // Framework & Driver Rules
    FrameworkIsolationRule(),
    DatabaseDetailRule(),
    WebFrameworkDetailRule(),
    GlueCodeRule(),

    // Advanced Clean Architecture Rules
    AbstractionLevelRule(),
    FlexibleLayerDetectionRule(),
    CoreDependencyRule(),
    AbstractionProgressionRule(),

    // Boundary Crossing Rules
    BoundaryCrossingRule(),
    DependencyInversionBoundaryRule(),
    InterfaceBoundaryRule(),
    PolymorphicFlowControlRule(),

    // Data Boundary Rules
    DataBoundaryCrossingRule(),
    EntityBoundaryIsolationRule(),
    DTOBoundaryPatternRule(),
    DatabaseRowBoundaryRule(),
  ];
}
