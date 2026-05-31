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
import 'src/rules/presentation_rules/presentation_no_throw_rule.dart';

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
    registry.registerWarningRule(PresentationNoThrowRule());
  }
}
