import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';

import 'src/rules/cross_layer/allowed_instance_variables_rule.dart';
import 'src/rules/cross_layer/boundary_crossing_rule.dart';
import 'src/rules/cross_layer/circular_dependency_rule.dart';
import 'src/rules/cross_layer/layer_dependency_rule.dart';
import 'src/rules/data_rules/datasource_abstraction_rule.dart';
import 'src/rules/data_rules/datasource_exception_types_rule.dart';
import 'src/rules/data_rules/datasource_no_result_return_rule.dart';
import 'src/rules/data_rules/model_conversion_methods_rule.dart';
import 'src/rules/data_rules/model_entity_direct_access_rule.dart';
import 'src/rules/data_rules/model_field_duplication_rule.dart';
import 'src/rules/data_rules/model_naming_convention_rule.dart';
import 'src/rules/data_rules/model_structure_rule.dart';
import 'src/rules/data_rules/repository_implementation_rule.dart';
import 'src/rules/data_rules/repository_no_throw_rule.dart';
import 'src/rules/data_rules/repository_pass_through_rule.dart';
import 'src/rules/domain_rules/dependency_inversion_rule.dart';
import 'src/rules/domain_rules/domain_purity_rule.dart';
import 'src/rules/domain_rules/exception_naming_convention_rule.dart';
import 'src/rules/domain_rules/repository_interface_rule.dart';
import 'src/rules/domain_rules/usecase_no_result_return_rule.dart';
import 'src/rules/presentation_rules/extension_location_rule.dart';
import 'src/rules/presentation_rules/freezed_usage_rule.dart';
import 'src/rules/presentation_rules/no_presentation_models_rule.dart';
import 'src/rules/presentation_rules/presentation_no_data_exceptions_rule.dart';
import 'src/rules/presentation_rules/presentation_no_throw_rule.dart';
import 'src/rules/presentation_rules/presentation_use_async_value_rule.dart';
import 'src/rules/presentation_rules/ref_mounted_usage_rule.dart';
import 'src/rules/presentation_rules/riverpod_generator_rule.dart';
import 'src/rules/presentation_rules/riverpod_keep_alive_rule.dart';
import 'src/rules/presentation_rules/riverpod_provider_naming_rule.dart';
import 'src/rules/presentation_rules/riverpod_ref_after_async_gap_rule.dart';
import 'src/rules/presentation_rules/riverpod_ref_usage_rule.dart';
import 'src/rules/presentation_rules/widget_no_usecase_call_rule.dart';
import 'src/rules/presentation_rules/widget_ref_read_then_when_rule.dart';

final plugin = CleanArchitectureLinterPlugin();

class CleanArchitectureLinterPlugin extends Plugin {
  @override
  String get name => 'Clean Architecture Linter';

  @override
  void register(PluginRegistry registry) {
    // Cross-layer rules
    registry.registerWarningRule(LayerDependencyRule());
    registry.registerWarningRule(CircularDependencyRule());
    registry.registerWarningRule(BoundaryCrossingRule());
    registry.registerWarningRule(AllowedInstanceVariablesRule());

    // Data layer rules
    registry.registerWarningRule(DataSourceAbstractionRule());
    registry.registerWarningRule(DataSourceExceptionTypesRule());
    registry.registerWarningRule(DataSourceNoResultReturnRule());
    registry.registerWarningRule(ModelConversionMethodsRule());
    registry.registerWarningRule(ModelEntityDirectAccessRule());
    registry.registerWarningRule(ModelFieldDuplicationRule());
    registry.registerWarningRule(ModelNamingConventionRule());
    registry.registerWarningRule(ModelStructureRule());
    registry.registerWarningRule(RepositoryImplementationRule());
    registry.registerWarningRule(RepositoryNoThrowRule());
    registry.registerWarningRule(RepositoryPassThroughRule());

    // Domain layer rules
    registry.registerWarningRule(DomainPurityRule());
    registry.registerWarningRule(DependencyInversionRule());
    registry.registerWarningRule(RepositoryInterfaceRule());
    registry.registerWarningRule(UseCaseNoResultReturnRule());
    registry.registerWarningRule(ExceptionNamingConventionRule());

    // Presentation layer rules
    registry.registerWarningRule(ExtensionLocationRule());
    registry.registerWarningRule(FreezedUsageRule());
    registry.registerWarningRule(NoPresentationModelsRule());
    registry.registerWarningRule(PresentationNoDataExceptionsRule());
    registry.registerWarningRule(PresentationNoThrowRule());
    registry.registerWarningRule(PresentationUseAsyncValueRule());
    registry.registerWarningRule(RefMountedUsageRule());
    registry.registerWarningRule(RiverpodGeneratorRule());
    registry.registerWarningRule(RiverpodKeepAliveRule());
    registry.registerWarningRule(RiverpodProviderNamingRule());
    registry.registerWarningRule(RiverpodRefAfterAsyncGapRule());
    registry.registerWarningRule(RiverpodRefUsageRule());
    registry.registerWarningRule(WidgetNoUseCaseCallRule());
    registry.registerWarningRule(WidgetRefReadThenWhenRule());
  }
}
