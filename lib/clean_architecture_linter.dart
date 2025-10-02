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

// Core Clean Architecture Rules
import 'src/rules/layer_dependency_rule.dart';
import 'src/rules/domain_rules/domain_purity_rule.dart';
import 'src/rules/domain_rules/dependency_inversion_rule.dart';
import 'src/rules/domain_rules/repository_interface_rule.dart';
import 'src/rules/circular_dependency_rule.dart';
import 'src/rules/boundary_crossing_rule.dart';

// Data Layer Rules
import 'src/rules/data_rules/model_structure_rule.dart';
import 'src/rules/data_rules/datasource_abstraction_rule.dart';

// Presentation Layer Rules
import 'src/rules/presentation_rules/no_presentation_models_rule.dart';
import 'src/rules/presentation_rules/extension_location_rule.dart';
import 'src/rules/presentation_rules/freezed_usage_rule.dart';
import 'src/rules/presentation_rules/riverpod_generator_rule.dart';

/// Plugin entry point for Clean Architecture Linter.
PluginBase createPlugin() => _CleanArchitectureLinterPlugin();

class _CleanArchitectureLinterPlugin extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => [
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

        // Data Layer Rules (2 rules)

        // 7. Model Structure - Freezed Model with Entity
        ModelStructureRule(),

        // 8. DataSource Abstraction - Abstract DataSource with Implementation
        DataSourceAbstractionRule(),

        // Presentation Layer Rules (4 rules)

        // 9. No Presentation Models - Use Freezed State instead
        NoPresentationModelsRule(),

        // 10. Extension Location - Extensions in same file
        ExtensionLocationRule(),

        // 11. Freezed Usage - Use Freezed instead of Equatable
        FreezedUsageRule(),

        // 12. Riverpod Generator - Use @riverpod annotation
        RiverpodGeneratorRule(),
      ];
}
