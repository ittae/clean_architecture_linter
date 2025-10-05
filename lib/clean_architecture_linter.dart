/// A focused custom lint package that enforces Clean Architecture principles in Flutter projects.
///
/// Following CLEAN_ARCHITECTURE_GUIDE.md:
/// - Freezed for Models, Entities, and States
/// - Riverpod Generator for state management
/// - Extensions in same file as the class
/// - No Presentation Models or ViewModels
/// - Models contain Entities (no duplicate data)
library;

import 'package:custom_lint_builder/custom_lint_builder.dart';

// Cross-Layer Rules (rules that validate across multiple architectural layers)
import 'src/rules/cross_layer/layer_dependency_rule.dart';
import 'src/rules/cross_layer/circular_dependency_rule.dart';
import 'src/rules/cross_layer/boundary_crossing_rule.dart';
import 'src/rules/cross_layer/test_coverage_rule.dart';

// Domain Layer Rules
import 'src/rules/domain_rules/domain_purity_rule.dart';
import 'src/rules/domain_rules/dependency_inversion_rule.dart';
import 'src/rules/domain_rules/repository_interface_rule.dart';
import 'src/rules/domain_rules/usecase_no_result_return_rule.dart';
import 'src/rules/domain_rules/usecase_must_convert_failure_rule.dart';
import 'src/rules/domain_rules/exception_naming_convention_rule.dart';
import 'src/rules/domain_rules/exception_message_localization_rule.dart';

// Data Layer Rules
import 'src/rules/data_rules/model_structure_rule.dart';
import 'src/rules/data_rules/datasource_abstraction_rule.dart';
import 'src/rules/data_rules/datasource_no_result_return_rule.dart';
import 'src/rules/data_rules/repository_must_return_result_rule.dart';
import 'src/rules/data_rules/repository_no_throw_rule.dart';
import 'src/rules/data_rules/datasource_exception_types_rule.dart';
import 'src/rules/data_rules/failure_naming_convention_rule.dart';

// Presentation Layer Rules
import 'src/rules/presentation_rules/no_presentation_models_rule.dart';
import 'src/rules/presentation_rules/extension_location_rule.dart';
import 'src/rules/presentation_rules/freezed_usage_rule.dart';
import 'src/rules/presentation_rules/riverpod_generator_rule.dart';
import 'src/rules/presentation_rules/presentation_no_data_exceptions_rule.dart';
import 'src/rules/presentation_rules/presentation_use_async_value_rule.dart';

/// Plugin entry point for Clean Architecture Linter.
PluginBase createPlugin() => _CleanArchitectureLinterPlugin();

class _CleanArchitectureLinterPlugin extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) {
    // Read test coverage configuration
    // custom_lint:
    //   rules:
    //     - clean_architecture_linter_require_test: true
    //       check_usecases: true
    //       check_repositories: true
    //       check_datasources: true
    //       check_notifiers: true

    final testConfig = configs.rules['clean_architecture_linter_require_test'];
    final testEnabled = testConfig?.enabled ?? false;
    final checkUsecases = testConfig?.json['check_usecases'] as bool? ?? true;
    final checkRepositories =
        testConfig?.json['check_repositories'] as bool? ?? true;
    final checkDatasources =
        testConfig?.json['check_datasources'] as bool? ?? true;
    final checkNotifiers = testConfig?.json['check_notifiers'] as bool? ?? true;

    final rules = <LintRule>[
      // Core Clean Architecture Principles (6 rules)

      // 1. Dependency Direction Rule - 의존성 방향 검증
      LayerDependencyRule(),

      // 2. Domain Purity Rule - Domain 레이어 순수성
      DomainPurityRule(),

      // 3. Dependency Inversion Principle - 추상화에 의존
      DependencyInversionRule(),

      // 4. Repository Pattern - Repository 인터페이스 정의
      RepositoryInterfaceRule(),

      // 5. Circular Dependency Prevention - 순환 의존성 방지
      CircularDependencyRule(),

      // 6. Boundary Crossing Validation - 레이어 경계 검증
      BoundaryCrossingRule(),

      // Domain Layer Rules (4 rules)

      // 7. UseCase No Result Return - UseCase should unwrap Result
      UseCaseNoResultReturnRule(),

      // 8. UseCase Must Convert Failure - UseCase should use .toException()
      UseCaseMustConvertFailureRule(),

      // 9. Exception Naming Convention - Feature prefix for Domain exceptions
      ExceptionNamingConventionRule(),

      // 10. Exception Message Localization - Use Korean messages
      ExceptionMessageLocalizationRule(),

      // Data Layer Rules (7 rules)

      // 11. Model Structure - Freezed Model with Entity
      ModelStructureRule(),

      // 12. DataSource Abstraction - Abstract DataSource with Implementation
      DataSourceAbstractionRule(),

      // 13. DataSource No Result Return - DataSource should throw exceptions
      DataSourceNoResultReturnRule(),

      // 14. Repository Must Return Result - Repository must wrap in Result type
      RepositoryMustReturnResultRule(),

      // 15. Repository No Throw - Repository should not throw exceptions directly
      RepositoryNoThrowRule(),

      // 16. DataSource Exception Types - Use defined Data exceptions only
      DataSourceExceptionTypesRule(),

      // 17. Failure Naming Convention - Feature prefix for Failure classes
      FailureNamingConventionRule(),

      // Presentation Layer Rules (6 rules)

      // 18. No Presentation Models - Use Freezed State instead
      NoPresentationModelsRule(),

      // 19. Extension Location - Extensions in same file
      ExtensionLocationRule(),

      // 20. Freezed Usage - Use Freezed instead of Equatable
      FreezedUsageRule(),

      // 21. Riverpod Generator - Use @riverpod annotation
      RiverpodGeneratorRule(),

      // 22. Presentation No Data Exceptions - Use Domain exceptions only
      PresentationNoDataExceptionsRule(),

      // 23. Presentation Use AsyncValue - Use AsyncValue for error handling
      PresentationUseAsyncValueRule(),
    ];

    // Conditionally add test coverage rule if enabled
    if (testEnabled) {
      rules.add(
        TestCoverageRule(
          checkUsecases: checkUsecases,
          checkRepositories: checkRepositories,
          checkDatasources: checkDatasources,
          checkNotifiers: checkNotifiers,
        ),
      );
    }

    return rules;
  }
}
